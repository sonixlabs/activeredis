# to be aware of rails & stuff
require 'rubygems'
require 'redis'
require 'json'

# Rails 3.0.0-beta needs to be installed
require 'active_model'

module ActiveRedis
  
  class ActiveRedisError < StandardError
  end
  
  # Raised when Active Redis cannot find record by given id or set of ids.
  class RecordNotFound < ActiveRedisError
  end
  
  class Base
    include ActiveModel::Validations
    include ActiveModel::Dirty
    include ActiveModel::Serialization
    include ActiveModel::Serializers::JSON
    include ActiveModel::Naming
    
    # RAILSISM
    # Returns a hash of all the attributes with their names as keys and the values of the attributes as values
    #  --> means: Strings as keys!
    #  --> initialize stringifies
    #
    #  called by to_json for_example
    attr_reader :attributes
    attr_reader :id
    attr :frozen
    
    # INSTANCE METHODS
    
    def initialize(attributes = {}, id = nil)
      @id = id if id
      @attributes = {}
      initialize_attributes(attributes)
      frozen = false
    end
    
    # Object's attributes' keys are converted to strings because of railsisms.
    # Because of activeredisism, also values are converted to strings for consistency.
    def initialize_attributes(attributes)
      attributes.stringify_keys!   # NEEDS to be strings for railsisms
      attributes.each_pair { |key, value| attributes[key] = value.to_s }
      @attributes.merge!(attributes)

      (class << self; self; end).class_eval do
        attributes.each_pair do |key, value|
          define_method key.to_sym do
            value
          end
          define_method "#{key}=".to_sym do |new_value|
            @attributes["#{key}"] = new_value.to_s
          end
        end
      end
    end

    def save
      attributes_array = attributes.to_a.flatten
      creation = new_record?
      
      @id = self.class.fetch_new_identifier if creation

      connection.multi
      if attributes_array.size > 0  
        connection.set("#{key_namespace}:attributes", attributes.to_json)
      end
      connection.zadd("#{class_namespace}:all", @id, @id) 
      connection.exec
            
      return true
    end

    def update_attributes(attributes)
      initialize_attributes(attributes)
      save
    end

    def reload
      self.class.find(@id)
    end
    
    def new_record?
      @id == nil
    end
    
    def key_namespace
      "#{self.class.key_namespace}:#{self.id}"
    end
    
    def class_namespace
      "#{self.class.key_namespace}"
    end
    
    def connection
      self.class.connection
    end

    def destroy
      connection.multi do
        connection.del "#{key_namespace}:attributes"
        connection.zrem "#{class_namespace}:all", @id
        @frozen = true
      end
      return true     
    end

    def frozen?
      @frozen
    end
    
    def add_attribute(name, value=nil)
      initialize_attributes({name => value})
    end
    
    # CLASS METHODS
    
    # Run this method to declare the fields of your model.
    def self.fields(*fields)
      fields.each do |field|
        define_method field.to_sym do
          @attributes["#{field}"]  
        end

        define_method "#{field}=".to_sym do |new_value|
          @attributes["#{field}"] = new_value.to_s
        end
      end
    end
    
    def self.key_namespace
      "#{self}"
    end
    
    def self.fetch_new_identifier
      self.connection.incr self.identifier_sequencer
    end
    
    def self.identifier_sequencer
      "#{key_namespace}:sequence"
    end
    
    def self.inherited(child)
      @@redis = Redis.new
      @@class = child
    end
    
    def self.redis_information
      connection.info # call_command [:info]
    end
    
    def self.connection
      @@redis
    end

    def self.count
      begin
        return connection.zcard "#{key_namespace}:all"
      rescue RuntimeError => e
        return 0
      end
    end

    def self.find_all
      record = []
      ids = connection.zrange "#{key_namespace}:all", 0, count
      ids.each do |id|
        record << find(id)
      end
      record
    end

    def self.all
      find_all
    end

    def self.delete_all
      records = find_all
      records.each do |record|
        record.destroy
      end
    end

    def self.find(id)
      return find_all if id == :all
      exists = connection.zscore "#{key_namespace}:all", id
      raise RecordNotFound.new("Couldn't find #{self.name} with ID=#{id}") unless exists
      get_attributes = connection.get("#{key_namespace}:#{id}:attributes")
      if get_attributes
        attributes = JSON.parse(connection.get "#{key_namespace}:#{id}:attributes")
      else
        attributes = {}
      end
      obj = self.new attributes, id
      return obj
    end

    def self.find_all_by_param(field, value)
      finded = []
      records = find_all
      records.each do |record|
        if record.attributes[field.to_s] == value.to_s
          finded << record
        end
      end
      return finded
    end

    def self.find_by_param(field, value)
      records = find_all_by_param(field, value)
      if records.size > 0
        return records[0]
      else
        nil
      end
    end

    def self.method_missing(name, *args)
      return find_by_param($1.to_sym, args[0]) if name.to_s =~ /^find_by_(.*)/
      return find_all_by_param($1.to_sym, args[0]) if name.to_s =~ /^find_all_by_(.*)/
      super
    end

  end
end

