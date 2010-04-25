require 'lib/active_redis'

class Cat < ActiveRedis::Base
  
end

describe Cat do

  before(:each) do
    @cat = Cat.new(:name => "lol")
  end

  it "should be a rektive model" do
    Cat.ancestors.should include(ActiveRedis::Base)
  end
  
  it "should give out info on the redis server" do
    Cat.redis_information.should be_an_instance_of(Hash)
    Cat.redis_information[:uptime_in_days].should == "0"
  end
  
  it "should have a connection to a redis server" do
    Cat.connection.should be_an_instance_of(Redis::Client)
  end

  describe "counting" do
    it "should know count of its objects when empty" do
      Cat.count.should == 0
    end

    # Waiting for object persisting
    it "should know count of its objects" 
    # do
    #   @cat.save
    #   Cat.count.should == 1
    # end
    
  end
  
  describe "attributes" do
    
    it "should have attributes" do
      @cat.attributes.should include("name")
    end
  
    it "should have accessors for all attributes" do
      @cat.name.should == "lol"
    end
        
  end
  
  describe "persisting simple objects" do
    before(:each) do
      @cat = Cat.new(:name => "lol")
    end
    
    it "should persist a simple object successfully" do
      @cat.save.should be_true
    end
    
    it "should have a key to fetch the next free identifier from" do
      Cat.identifier_sequencer.should == "Cat:sequence"
    end
    
    it "should reserve a unique identifier for the object" do
      Cat.connection.should_receive(:incr).with(Cat.identifier_sequencer).and_return(1)
      
      Cat.fetch_new_identifier
    end
    
    it "should save the identifier to the object" do
      @cat.save
      
      @cat.id.should_not be_nil
    end
    
    it "should persist the attributes of the object" do
      Cat.stub!(:fetch_new_identifier).and_return(1)
      Cat.connection.should_receive(:hset).with("#{Cat.key_namespace}:1:attributes", "name", "lol").and_return(true)
      
      @cat.save
    end
  end

  describe "find" do
    it "should return nil if record was not found" do
      no_such_cat = Cat.find(1)
      no_such_cat.should be_nil    
    end
  end
end
