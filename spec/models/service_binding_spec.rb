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
    SecureRandom.stub(:base64).and_return(password, 'notthepassword')
    Database.stub(:exists?).with(database).and_return(true)
    Catalog.stub(:connection_quota_for_plan_guid).with(plan_guid).and_return(connection_quota)
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
      before { connection.execute("GRANT ALL PRIVILEGES ON `#{database}`.* TO '#{username}'@'%' IDENTIFIED BY '#{password}'") }

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
      expect(connection).to receive(:execute).with("FLUSH PRIVILEGES")

      ServiceBinding.update_all_max_user_connections
    end
  end

  describe '.exists?' do
    context 'when the user exists and has all privileges' do
      before { connection.execute("GRANT ALL PRIVILEGES ON `#{database}`.* TO '#{username}'@'%' IDENTIFIED BY '#{password}'") }

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
        connection.select(password_sql).count
      }.from(0).to(1)
    end

    it 'grants the user all privileges for the database' do
      expect {
        connection.select_values("SHOW GRANTS FOR #{username}")
      }.to raise_error(ActiveRecord::StatementInvalid, /no such grant/)

      binding.save

      grant_sql = "GRANT ALL PRIVILEGES ON `#{database}`.* TO '#{username}'@'%'"
      expect(connection.select_values("SHOW GRANTS FOR #{username}")).to include(grant_sql)
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
      }.to raise_error

      password_sql = "SELECT * FROM mysql.user WHERE user = '#{username}' AND password = PASSWORD('#{password}')"
      expect(connection.select(password_sql).count).to eq(1)
    end

    context 'when the database does not exist' do
      before { Database.stub(:exists?).with(database).and_return(false) }

      it 'raises an error' do
        expect{binding.save}.to raise_error
      end
    end
  end

  describe '#destroy' do
    context 'when the user exists' do
      before { binding.save }

      it 'deletes the user' do
        grant_sql = "GRANT ALL PRIVILEGES ON `#{database}`.* TO '#{username}'@'%'"
        expect(connection.select_values("SHOW GRANTS FOR #{username}")).to include(grant_sql)

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

    before { binding.save }

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
    end
  end
end
