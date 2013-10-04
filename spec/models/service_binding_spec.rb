require 'spec_helper'

describe ServiceBinding do
  let(:id) { 'fa790aea-ab7f-41e8-b6f9-a2a1d60403f5' }
  let(:username) { Digest::MD5.base64digest(id)[0...16] }
  let(:password) { 'random-password' }
  let(:binding) { ServiceBinding.new(id: id, service_instance: instance) }

  let(:instance_id) { '88f6fa22-c8b7-4cdc-be3a-dc09ea7734db' }
  let(:instance) { ServiceInstance.new(id: instance_id) }
  let(:database) { instance.database }

  before do
    SecureRandom.stub(:hex).with(8).and_return(password, 'not-the-password')
  end

  after do
    begin
      connection.execute("DROP USER #{username}")
    rescue ActiveRecord::StatementInvalid => e
      raise unless e.message =~ /DROP USER failed/
    end
  end

  describe '.find_by_id' do
    context 'when the user exists' do
      before { ServiceBinding.new(id: id, service_instance: instance).save }

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
    let(:jdbc_url) { "jdbc:mysql://#{username}:#{password}@#{host}:#{port}/#{database}" }

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
