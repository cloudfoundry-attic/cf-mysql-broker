require 'spec_helper'
require 'securerandom'

describe 'Provisioning a service' do
  let(:service_instance_guid) { SecureRandom.uuid }
  let(:settings) { YAML.load_file(Rails.root + "config/settings.yml")[Rails.env] }
  let(:plan_id) { settings['services'].first['plans'].first['id'] }
  let(:service_id) {settings['services'].first['id']}
  let(:instance_capacity) { settings['services'].first['max_db_per_node'] }

  context 'when the service broker is at maximum instance capacity' do
    before do
      @provisioned_instance_guids = instance_capacity.times.map { provision_service_instance }
    end

    after do
      @provisioned_instance_guids.each do |guid|
        cleanup_mysql_database(guid)
      end
      cleanup_mysql_database(service_instance_guid)
    end

    it 'returns a meaningful error message when attempting to provision' do
      put "/v2/service_instances/#{service_instance_guid}", {
        'plan_id' => plan_id,
        'service_id' => service_id,
        'organization_guid' => 'organization_guid',
        'space_guid' => 'space_guid'
      }

      expect(response.status).to eq(507)
      error = JSON.parse(response.body)
      expect(error['description']).to eq('Service plan capacity has been reached')
    end
  end

  def provision_service_instance
    guid = SecureRandom.uuid
    put "/v2/service_instances/#{guid}",
        'plan_id' => plan_id,
        'service_id' => service_id,
        'organization_guid' => 'organization_guid',
        'space_guid' => 'space_guid'
    guid
  end

  def cleanup_mysql_database(guid)
    dbname = ServiceInstance.new(id: guid).database
    ActiveRecord::Base.connection.execute("DROP DATABASE #{dbname}") rescue nil
  end
end
