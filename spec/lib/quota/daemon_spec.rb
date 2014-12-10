require 'spec_helper'

module Quota
  describe Daemon do
    describe '.start' do
      before do
        allow(ActiveRecord::Base).to receive(:establish_connection)
        allow(Kernel).to receive(:loop)
        allow(Kernel).to receive(:sleep)

        allow(Enforcer).to receive(:update_quotas)
        allow(Enforcer).to receive(:enforce!)

        allow(Database).to receive(:with_reconnect).and_yield
      end

      it 'establishes the initial database connection' do
        test_db_config = {
          'adapter' => 'mysql2',
          'encoding' => 'utf8',
          'database' => 'test',
          'pool' =>5,
          'username' => 'root',
          'password' =>nil,
          'host' => 'localhost',
          'port' =>3306
        }

        Daemon.start
        expect(ActiveRecord::Base).to have_received(:establish_connection).with(test_db_config)
      end

      it 'reconnects if the connection is lost' do
        allow(Kernel).to receive(:loop).and_yield
        allow(Database).to receive(:with_reconnect)
        Daemon.start
        expect(Enforcer).not_to have_received(:enforce!)
      end

      it 'updates quotas' do
        Daemon.start
        expect(Enforcer).to have_received(:update_quotas)
      end

      it 'enforces quotas once every second' do
        allow(Kernel).to receive(:loop).and_yield.and_yield

        Daemon.start

        expect(Enforcer).to have_received(:enforce!).twice
        expect(Kernel).to have_received(:sleep).with(1).twice
      end
    end
  end
end
