require 'spec_helper'


describe TableLockManager do
  let(:instance_guid) {'88f6fa22-c8b7-4cdc-be3a-dc09ea7734db'}
  let(:username) {binding.username}
  let(:database) {ServiceInstanceManager.database_name_from_service_instance_guid(instance_guid)}
  let(:connection) {ServiceInstance.connection}

  let(:instance) {ServiceInstance.new(
    guid: instance_guid,
    plan_guid: 'plan_guid',
    db_name: database)
  }

  let(:binding) {ServiceBinding.new(id: 'fa790aea-ab7f-41e8-b6f9-a2a1d60403f5', service_instance: instance)}

  before do
    allow(Database).to receive(:exists?).with(database).and_return(true)
  end

  after do
    begin
      connection.execute("DROP USER #{username}")
    rescue ActiveRecord::StatementInvalid => e
      raise unless e.message =~ /DROP USER failed/
    end
  end

  def fetch_grants
    grants = connection.select_values("SHOW GRANTS FOR #{username}")

    matching_grants = grants.select {|grant| grant.match(/GRANT .* ON `#{database}`\.\* TO '#{username}'@'%'/)}
  end

  describe 'update_table_lock_permissions' do
    context 'when table locks are disabled' do
      before do
        allow(Settings).to receive(:allow_table_locks).and_return(true)
        binding.save
        grants = fetch_grants
        expect(grants.length).to eq(1)
        expect(grants[0]).to include("ALL PRIVILEGES")

        allow(Settings).to receive(:allow_table_locks).and_return(false)
      end

      it 'revokes lock table permissions on all users' do
        TableLockManager.update_table_lock_permissions

        grants = fetch_grants

        expect(grants.length).to eq(1)
        expect(grants[0]).not_to include("ALL PRIVILEGES")
        expect(grants[0]).not_to include("LOCK TABLES")
      end
    end

    context 'when table locks are enabled' do
      before do
        allow(Settings).to receive(:allow_table_locks).and_return(false)
        binding.save
        grants = fetch_grants
        expect(grants.length).to eq(1)
        expect(grants[0]).not_to include("ALL PRIVILEGES")

        allow(Settings).to receive(:allow_table_locks).and_return(true)
      end

      it 'grants lock table permissions on all users' do
        TableLockManager.update_table_lock_permissions

        grants = fetch_grants

        expect(grants.length).to eq(1)
        expect(grants[0]).to include("ALL PRIVILEGES")
      end
    end
  end
end
