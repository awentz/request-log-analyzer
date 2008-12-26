require File.dirname(__FILE__) + '/spec_helper'
require 'request_log_analyzer/aggregator/database'


describe RequestLogAnalyzer::Aggregator::Database, "schema creation" do

  TEST_DATABASE_FILE = File.dirname(__FILE__) + "/fixtures/requests.db"
  include RequestLogAnalyzerSpecHelper
  
  before(:each) do
    @database_inserter = RequestLogAnalyzer::Aggregator::Database.new(TestFileFormat, :database => TEST_DATABASE_FILE)
    @test_request      = RequestLogAnalyzer::Request.new(TestFileFormat)
    @test_request << {:line_type => :first}
  end
  
  after(:each) do
    File.unlink(TEST_DATABASE_FILE) if File.exist?(TEST_DATABASE_FILE)
  end
  
  it "should create the correct tables" do
    ActiveRecord::Migration.should_receive(:create_table).with("first_lines")
    ActiveRecord::Migration.should_receive(:create_table).with("test_lines")        
    ActiveRecord::Migration.should_receive(:create_table).with("last_lines")    
    @database_inserter.prepare
  end
  
  it "should create the default table names" do
    @database_inserter.prepare
    @database_inserter.file_format.line_definitions.each do |name, definition|
      klass = TestFileFormat.const_get("#{name}_line".camelize)
      klass.column_names.should include('id')
      klass.column_names.should include('lineno')      
      klass.column_names.should include('request_id')      
    end
  end
  
  it "should create the correct fields in the table" do
    @database_inserter.prepare
    
    TestFileFormat::FirstLine.column_names.should include('request_no')
    TestFileFormat::LastLine.column_names.should include('request_no')
    TestFileFormat::TestLine.column_names.should include('test_capture')    
  end
  
end

describe RequestLogAnalyzer::Aggregator::Database, "record insertion" do

  before(:each) do
    @database_inserter = RequestLogAnalyzer::Aggregator::Database.new(TestFileFormat, :database => TEST_DATABASE_FILE)
    @database_inserter.prepare
        
    @single = RequestLogAnalyzer::Request.create(TestFileFormat, {:line_type => :first, :request_no => 564})
    @combined = RequestLogAnalyzer::Request.create(TestFileFormat, 
                          {:line_type => :first, :request_no  => 564},
                          {:line_type => :test, :test_capture => "awesome"},
                          {:line_type => :test, :test_capture => "indeed"},                                                    
                          {:line_type => :last, :request_no   => 564})    
  end
  
  after(:each) do
    File.unlink(TEST_DATABASE_FILE) if File.exist?(TEST_DATABASE_FILE)
  end 
  
  it "should insert a record in the relevant table" do
    TestFileFormat::FirstLine.should_receive(:create!).with(hash_including(:request_no => 564))
    @database_inserter.aggregate(@single)
  end
  
  it "should insert records in all relevant tables" do
    TestFileFormat::FirstLine.should_receive(:create!).with(hash_including(:request_no => 564)).once
    TestFileFormat::TestLine.should_receive(:create!).twice
    TestFileFormat::LastLine.should_receive(:create!).with(hash_including(:request_no => 564)).once
    @database_inserter.aggregate(@combined)
  end
  
  it "should insert a record in the table" do
    @database_inserter.aggregate(@single)
    TestFileFormat::FirstLine.count(:conditions => {:request_no => 564}).should == 1
  end
  
end