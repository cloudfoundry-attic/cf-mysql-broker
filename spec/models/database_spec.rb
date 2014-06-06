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
end
