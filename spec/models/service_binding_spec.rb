require 'spec_helper'

describe ServiceBinding do
  let(:id) { 'fa790aea-ab7f-41e8-b6f9-a2a1d60403f5' }
  let(:username) { Digest::MD5.base64digest(id)[0...16] }
  let(:password) { 'randompassword' }
  let(:binding) { ServiceBinding.new(id: id, service_instance: instance) }

  let(:instance_guid) { '88f6fa22-c8b7-4cdc-be3a-dc09ea7734db' }
  let(:plan_guid) { 'plan-guid' }
  let(:instance) { ServiceInstance.new(
      guid: instance_guid,
      plan_guid: plan_guid,
      db_name: database)
  }
  let(:database) { ServiceInstanceManager.database_name_from_service_instance_guid(instance_guid) }
  let(:connection_quota) { 12 }

  before do
    allow(SecureRandom).to receive(:base64).and_return(password, 'notthepassword')
    allow(Database).to receive(:exists?).with(database).and_return(true)
    allow(Catalog).to receive(:connection_quota_for_plan_guid).with(plan_guid).and_return(connection_quota)
    allow(Settings).to receive(:allow_table_locks).and_return(true)
  end

  after do
    begin
      allow(connection).to receive(:execute).and_call_original
      connection.execute("DROP USER #{username}")
    rescue ActiveRecord::StatementInvalid => e
      raise unless e.message =~ /DROP USER failed/
    end
  end

  describe '.find_by_id' do
    context 'when the user exists' do
      before { connection.execute("CREATE USER '#{username}' IDENTIFIED BY '#{password}'") }

      it 'returns the binding' do
        binding = ServiceBinding.find_by_id(id)
        expect(binding).to be_a(ServiceBinding)
        expect(binding.id).to eq(id)
      end
    end

    context 'when the user does not exist' do
      it 'returns nil' do
        binding = ServiceBinding.find_by_id(id)
        expect(binding).to be_nil
      end
    end
  end

  describe '.find_by_id_and_service_instance_guid' do
    context 'when the user exists and has all privileges' do
      before { binding.save }

      it 'returns the binding' do
        binding = ServiceBinding.find_by_id_and_service_instance_guid(id, instance_guid)
        expect(binding).to be_a(ServiceBinding)
        expect(binding.id).to eq(id)
      end
    end

    context 'when the user exists but does not have all privileges' do
      before { connection.execute("CREATE USER '#{username}' IDENTIFIED BY '#{password}'") }

      it 'returns nil' do
        binding = ServiceBinding.find_by_id_and_service_instance_guid(id, instance_guid)
        expect(binding).to be_nil
      end
    end

    context 'when the user does not exist' do
      it 'returns nil' do
        binding = ServiceBinding.find_by_id_and_service_instance_guid(id, instance_guid)
        expect(binding).to be_nil
      end
    end
  end

  describe '.update_all_max_user_connections' do
    let(:users) { ["fake-user"] }
    let(:plan) do
      Plan.new(
        {
          'id' => plan_guid,
          'max_user_connections' => 45,
          'name' => 'fake-plan-name',
          'description' => 'some-silly-description',
        }
      )
    end

    before do
      allow(Catalog).to receive(:plans).and_return([plan])
    end

    it 'updates max user connections for all plans' do
      expect(Catalog).to receive(:plans)
      expect(connection).to receive(:select_values).
        with(
<<-SQL
SELECT mysql.user.user
FROM service_instances
JOIN mysql.db ON service_instances.db_name=mysql.db.Db
JOIN mysql.user ON mysql.user.User=mysql.db.User
WHERE plan_guid='#{plan.id}' AND mysql.user.user NOT LIKE 'root'
SQL
      ).and_return(users)

      expect(connection).to receive(:execute).
          with(
<<-SQL
GRANT USAGE ON *.* TO '#{users[0]}'@'%'
WITH MAX_USER_CONNECTIONS #{plan.max_user_connections}
SQL
      )
      ServiceBinding.update_all_max_user_connections
    end
  end

  describe '.exists?' do
    context 'when the user exists and has all privileges' do
      before { binding.save }

      it 'returns true' do
        expect(ServiceBinding.exists?(id: id, service_instance_guid: instance_guid)).to eq(true)
      end
    end

    context 'when the user exists but does not have all privileges' do
      before { connection.execute("CREATE USER '#{username}' IDENTIFIED BY '#{password}'") }

      it 'returns false' do
        expect(ServiceBinding.exists?(id: id, service_instance_guid: instance_guid)).to eq(false)
      end
    end

    context 'when the user does not exist' do
      it 'returns false' do
        expect(ServiceBinding.exists?(id: id, service_instance_guid: instance_guid)).to eq(false)
      end
    end
  end

  describe '#username' do
    it 'returns the same username for a given id' do
      binding1 = ServiceBinding.new(id: 'some_id')
      binding2 = ServiceBinding.new(id: 'some_id')
      expect(binding1.username).to eq (binding2.username)
    end

    it 'returns different usernames for different ids' do
      binding1 = ServiceBinding.new(id: 'some_id')
      binding2 = ServiceBinding.new(id: 'some_other_id')
      expect(binding2.username).to_not eq (binding1.username)
    end

    it 'returns only alphanumeric characters' do
      # MySQL doesn't explicitly require this, but we're doing it to be safe
      binding = ServiceBinding.new(id: '~!@#$%^&*()_+{}|:"<>?')
      expect(binding.username).to match /^[a-zA-Z0-9]+$/
    end

    it 'returns no more than 16 characters' do
      # MySQL usernames cannot be greater than 16 characters
      binding = ServiceBinding.new(id: 'fa790aea-ab7f-41e8-b6f9-a2a1d60403f5')
      expect(binding.username.length).to be <= 16
    end
  end

  describe '#save' do
    it 'creates a user with a random password' do
      expect {
        binding.save
      }.to change {
        password_sql = "SELECT * FROM mysql.user WHERE user = '#{username}' AND password = PASSWORD('#{password}')"
        connection.select_values(password_sql).count
      }.from(0).to(1)
    end

    context 'when table locks are enabled' do
      it 'grants the user all privileges including for LOCK TABLES' do
        expect {
          connection.select_values("SHOW GRANTS FOR #{username}")
        }.to raise_error(ActiveRecord::StatementInvalid, /no such grant/)

        binding.save

        grants = connection.select_values("SHOW GRANTS FOR #{username}")

        matching_grants = grants.select { |grant| grant.match(/GRANT .* ON `#{database}`\.\* TO '#{username}'@'%'/) }

        expect(matching_grants.length).to eq(1)
        expect(matching_grants[0]).to include("ALL PRIVILEGES")
      end
    end

    context 'when table locks are disabled' do
      before do
        allow(Settings).to receive(:allow_table_locks).and_return(false)
      end

      it 'grants the user all privileges except for LOCK TABLES' do
        expect {
          connection.select_values("SHOW GRANTS FOR #{username}")
        }.to raise_error(ActiveRecord::StatementInvalid, /no such grant/)

        binding.save

        grants = connection.select_values("SHOW GRANTS FOR #{username}")

        matching_grants = grants.select { |grant| grant.match(/GRANT .* ON `#{database}`\.\* TO '#{username}'@'%'/) }

        expect(matching_grants.length).to eq(1)
        expect(matching_grants[0]).not_to include("ALL PRIVILEGES")
        expect(matching_grants[0]).not_to include("LOCK TABLES")
      end
    end

    it 'sets the max connections to the value specified by the plan' do
      binding.save

      max_user_connection_sql = "WITH MAX_USER_CONNECTIONS #{connection_quota}"
      expect(connection.select_values("SHOW GRANTS FOR #{username}")[0]).to include(max_user_connection_sql)
    end

    it 'raises an error when creating the same user twice' do
      binding.save

      expect {
        ServiceBinding.new(id: id, service_instance: instance).save
      }.to raise_error(ActiveRecord::StatementInvalid)

      password_sql = "SELECT * FROM mysql.user WHERE user = '#{username}' AND password = PASSWORD('#{password}')"
      expect(connection.select_values(password_sql).count).to eq(1)
    end

    context 'when the database does not exist' do
      before { allow(Database).to receive(:exists?).with(database).and_return(false) }

      it 'raises an error' do
        expect{binding.save}.to raise_error(DatabaseNotFoundError)
      end
    end

    context 'when an error occurs creating the user' do

      let(:db_error) do
        ActiveRecord::StatementInvalid.new(
          "Lost connection to MySQL server during query: CREATE USER '#{username}' IDENTIFIED BY '#{password}'")
      end

      before do
        expect(connection).to receive(:execute).with(/CREATE USER/).and_raise(db_error)
      end

      it 'redacts the password before re-raising the error' do
        expect{binding.save}.to raise_error { |error|
          expect(error.message).to_not include password
        }
      end

      it 'retains the original error message' do
        expect{binding.save}.to raise_error { |error|
          expect(error.message).to eq "Lost connection to MySQL server during query: CREATE USER '#{username}' IDENTIFIED BY 'redacted'"
        }
      end

      it 'retains the original error backtrace' do
        expect{binding.save}.to raise_error { |error|
          expect(error.backtrace).to eq db_error.backtrace
        }
      end
    end
  end

  describe '#destroy' do
    context 'when the user exists' do
      before { binding.save }

      it 'deletes the user' do
        grant_sql_regex = /GRANT .* ON `#{database}`\.\* TO '#{username}'@'%'/
        grants = connection.select_values("SHOW GRANTS FOR #{username}")
        expect(grants.any? { |grant| grant.match(grant_sql_regex) }).to be_truthy

        binding.destroy

        expect {
          connection.select_values("SHOW GRANTS FOR #{username}")
        }.to raise_error(ActiveRecord::StatementInvalid, /no such grant/)
      end
    end

    context 'when the user does not exist' do
      it 'does not raise an error' do
        expect {
          connection.select_values("SHOW GRANTS FOR #{username}")
        }.to raise_error(ActiveRecord::StatementInvalid, /no such grant/)

        expect {
          binding.destroy
        }.to_not raise_error

        expect {
          connection.select_values("SHOW GRANTS FOR #{username}")
        }.to raise_error(ActiveRecord::StatementInvalid, /no such grant/)
      end
    end
  end

  describe '#to_json' do
    let(:connection_config) { Rails.configuration.database_configuration[Rails.env] }
    let(:host) { connection_config.fetch('host') }
    let(:port) { connection_config.fetch('port') }
    let(:uri) { "mysql://#{username}:#{password}@#{host}:#{port}/#{database}?reconnect=true" }
    let(:jdbc_url) { "jdbc:mysql://#{host}:#{port}/#{database}?user=#{username}&password=#{password}" }
    let(:tls_ca_certificate) { nil }

    before do
      allow(Settings).to receive(:[]).with('tls_ca_certificate').and_return(tls_ca_certificate)
      binding.save
    end

    it 'includes the credentials' do
      hash = JSON.parse(binding.to_json)
      credentials = hash.fetch('credentials')
      expect(credentials.fetch('hostname')).to eq(host)
      expect(credentials.fetch('port')).to eq(port)
      expect(credentials.fetch('name')).to eq(database)
      expect(credentials.fetch('username')).to eq(username)
      expect(credentials.fetch('password')).to eq(password)
      expect(credentials.fetch('uri')).to eq(uri)
      expect(credentials.fetch('jdbcUrl')).to eq(jdbc_url)
      expect(credentials).to_not have_key('ca_certificate')
    end

    context 'when the broker starts with a ca cert' do
      let(:tls_ca_certificate) { 'this-is-a-ca-certificate' }

      it 'includes the ca_certificate' do
        hash = JSON.parse(binding.to_json)
        credentials = hash.fetch('credentials')
        expect(credentials.fetch('ca_certificate')).to eq(tls_ca_certificate)
      end

      it 'adds useSSL to the jdbc url' do
        hash = JSON.parse(binding.to_json)
        credentials = hash.fetch('credentials')
        expect(credentials.fetch('jdbcUrl')).to eq("#{jdbc_url}&useSSL=true")
      end
    end
  end
end
