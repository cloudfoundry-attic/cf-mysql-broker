require 'spec_helper'

describe ServiceInstanceUsageQuery do
  describe 'getting MB used' do
    let(:instance_guid) { SecureRandom.uuid }
    let(:instance) { ServiceInstance.find_by_guid(instance_guid) }
    let(:binding_id) { SecureRandom.uuid }
    let(:binding) { ServiceBinding.new(id: binding_id, service_instance: instance) }
    let(:mbs_used) { 10 }
    let(:client) { create_mysql_client }
    let(:max_storage_mb) { 15 }
    let(:plan_guid) {'plan_guid'}

    before do
      Catalog.stub(:has_plan?).with(plan_guid).and_return(true)
      Catalog.stub(:storage_quota_for_plan_guid).with(plan_guid).and_return(max_storage_mb)
      ServiceInstanceManager.create(guid: instance_guid, plan_guid: plan_guid)
      binding.save
      fill_db
    end

    after do
      binding.destroy
      ServiceInstanceManager.destroy(guid: instance_guid)
    end

    it 'returns the correct MB used' do
      query = ServiceInstanceUsageQuery.new(instance)

      result = query.execute

      expect(result).to be_within(1).of(mbs_used)
    end
  end

  def fill_db
    data = '1' * (1024 * 1024) # 1 MB
    data = client.escape(data)

    client.query('CREATE TABLE stuff (id INT PRIMARY KEY, data LONGTEXT) ENGINE=InnoDB')
    mbs_used.times do |n|
      client.query("INSERT INTO stuff (id, data) VALUES (#{n}, '#{data}')")
    end
  end

  def create_mysql_client
    Mysql2::Client.new(
      :host     => binding.host,
      :port     => binding.port,
      :database => binding.database_name,
      :username => binding.username,
      :password => binding.password
    )
  end
end
