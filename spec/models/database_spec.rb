require 'spec_helper'

describe Database do
  let(:db_name) { 'database_name' }

  describe '.create' do
    after { connection.execute("DROP DATABASE `#{db_name}`") }

    it 'creates a new database' do
      Database.create(db_name)
      expect(connection.select("SELECT COUNT(*) FROM information_schema.SCHEMATA WHERE schema_name='#{db_name}'").rows.first.first).to eq(1)
    end

    context 'when the database already exists' do
      before do
        Database.create(db_name)
      end

      it 'avoids collisions with existing databases' do
        expect {
          Database.create(db_name)
        }.to_not change {
          connection.select("SHOW DATABASES LIKE '#{db_name}'").count
        }.from(1)
      end
    end
  end

  describe '.drop' do
    context 'when the database exists' do
      before { connection.execute("CREATE DATABASE `#{db_name}`") }

      it 'drops the database' do
        expect {
          Database.drop(db_name)
        }.to change {
          connection.select("SHOW DATABASES LIKE '#{db_name}'").count
        }.from(1).to(0)
      end
    end

    context 'when the database does not exist' do
      it 'does not raise an error' do
        expect {
          Database.drop('unknown_database')
        }.to_not raise_error
      end
    end
  end

  describe '.exists?' do
    context 'when the database exists' do
      before { connection.execute("CREATE DATABASE `#{db_name}`") }
      after { connection.execute("DROP DATABASE `#{db_name}`") }

      it 'returns true' do
        expect(Database.exists?(db_name)).to eq(true)
      end
    end

    context 'when the database does not exist' do
      it 'returns false' do
        expect(Database.exists?(db_name)).to eq(false)
      end
    end
  end

  describe '.usage' do
    let(:mb_string) { 'a' * 1024 * 1024 }
    before { Database.create(db_name) }
    after { Database.drop(db_name) }

    it 'returns the data usage of the db in megabytes' do
      connection.execute("CREATE TABLE #{db_name}.mytable (id MEDIUMINT, data LONGTEXT)")
      connection.execute("INSERT INTO #{db_name}.mytable (id, data) VALUES (1, '#{mb_string}')")
      connection.execute("INSERT INTO #{db_name}.mytable (id, data) VALUES (2, '#{mb_string}')")
      connection.execute("INSERT INTO #{db_name}.mytable (id, data) VALUES (3, '#{mb_string}')")
      connection.execute("INSERT INTO #{db_name}.mytable (id, data) VALUES (4, '#{mb_string}')")

      expect(Database.usage(db_name)).to eq 4
    end
  end

  describe '.with_reconnect' do
    before do
      allow(Kernel).to receive(:sleep)

      reconnect_count = 0
      allow(ActiveRecord::Base.connection).to receive(:reconnect!) do
        reconnect_count += 1
        if reconnect_count == 1
          raise Mysql2::Error.new("fake")
        else
          allow(ActiveRecord::Base.connection).to receive(:active?).and_return(true)
        end
      end

      @foo = double('bob')
      allow(@foo).to receive(:bar).and_raise(ActiveRecord::ActiveRecordError)
    end

    it 'attempts to reconnect every 3 seconds if the connection becomes inactive' do
      allow(ActiveRecord::Base.connection).to receive(:active?).and_return(false)

      Database.with_reconnect do
        @foo.bar
      end

      expect(@foo).to have_received(:bar)
      expect(ActiveRecord::Base.connection).to have_received(:reconnect!).twice
      expect(Kernel).to have_received(:sleep).with(3.seconds)
    end

    it 'stops trying to reconnect eventually, in case there is an unrecoverable error' do
      allow(ActiveRecord::Base.connection).to receive(:active?).and_return(false)
      allow(ActiveRecord::Base.connection).to receive(:reconnect!).and_raise(Mysql2::Error.new("fake"))

      expect {
        Database.with_reconnect do
          @foo.bar
        end
      }.to raise_error(Mysql2::Error)
    end

    it 'does not reconnect if there was an error but the connection is active' do
      allow(ActiveRecord::Base.connection).to receive(:active?).and_return(true)

      expect {
        Database.with_reconnect do
          @foo.bar
        end
      }.to raise_error(ActiveRecord::ActiveRecordError)

      expect(@foo).to have_received(:bar)
    end
  end
end
