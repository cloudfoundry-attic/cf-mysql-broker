require 'spec_helper'

describe 'DatabaseName' do

  it "translates '-' to '_'" do
    dbname = DatabaseName.new('123-456')
    expect(dbname.name).to eq('123_456')
  end

end