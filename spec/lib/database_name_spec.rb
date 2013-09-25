require 'spec_helper'

describe 'DatabaseName' do

  it "translates '-' to '_'" do
    dbname = DatabaseName.new('123-456')
    expect(dbname.name).to eq('123_456')
  end

  # Technically we should allow any kind of character in an id;
  # we don't absolutely know that ids are guids. That would require
  # writing some escaping code.
  context 'when there are strange characters in the id' do
    it 'raises an exception' do
      expect {
        DatabaseName.new("!@\#$%^&*()' ;")
      }.to raise_error(RuntimeError, 'Only ids matching [0-9,a-z,A-Z$-]+ are allowed')
    end

  end

end