require 'spec_helper'

describe ServiceInstancePermissionsRevokedQuery do
  describe 'getting permissions revoked status' do
    let(:instance_id) { SecureRandom.uuid }
    let(:instance) { ServiceInstance.new(id: instance_id) }
    let(:binding_id) { SecureRandom.uuid }
    let(:binding) { ServiceBinding.new(id: binding_id, service_instance: instance) }

    before do
      instance.save
      binding.save
    end

    after do
      binding.destroy
      instance.destroy
    end

    context 'when insert permission has been revoked' do
      before do
        revoke_insert_permission(instance)
      end

      it 'returns true' do
        query = ServiceInstancePermissionsRevokedQuery.new(instance)

        result = query.execute

        expect(result).to be_true
      end
    end

    context 'when update permission has been revoked' do
      before do
        revoke_update_permission(instance)
      end

      it 'returns true' do
        query = ServiceInstancePermissionsRevokedQuery.new(instance)

        result = query.execute

        expect(result).to be_true
      end
    end

    context 'when create permission has been revoked' do
      before do
        revoke_create_permission(instance)
      end

      it 'returns true' do
        query = ServiceInstancePermissionsRevokedQuery.new(instance)

        result = query.execute

        expect(result).to be_true
      end
    end

    context 'when permissions have not been revoked' do
      before do
        instate_permissions(instance)
      end

      it 'returns false' do
        query = ServiceInstancePermissionsRevokedQuery.new(instance)

        result = query.execute

        expect(result).to be_false
      end
    end

    def revoke_insert_permission(instance)
      ActiveRecord::Base.connection.update(<<-SQL)
        UPDATE mysql.db
        SET    Insert_priv = 'N'
        WHERE  Db = '#{instance.database}'
      SQL
    end

    def revoke_update_permission(instance)
      ActiveRecord::Base.connection.update(<<-SQL)
        UPDATE mysql.db
        SET    Update_priv = 'N'
        WHERE  Db = '#{instance.database}'
      SQL
    end

    def revoke_create_permission(instance)
      ActiveRecord::Base.connection.update(<<-SQL)
        UPDATE mysql.db
        SET    Create_priv = 'N'
        WHERE  Db = '#{instance.database}'
      SQL
    end

    def instate_permissions(instance)
      ActiveRecord::Base.connection.update(<<-SQL)
        UPDATE mysql.db
        SET    Insert_priv = 'Y', Update_priv = 'Y', Create_priv = 'Y'
        WHERE  Db = '#{instance.database}'
      SQL
    end
  end
end
