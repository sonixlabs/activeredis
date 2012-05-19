# to be aware of rails & stuff
require 'rubygems'
require 'redis'
require 'time'

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
      fields = Hash[[@@fields, Array.new(@@fields.size)].transpose]
      fields.stringify_keys!   # NEEDS to be strings for railsisms
      attributes.stringify_keys!   # NEEDS to be strings for railsisms
      attributes.each_pair { |key, value| attributes[key] = value.to_s }
      fields.merge!(attributes)
      @attributes.merge!(fields)
      @attributes.each_pair do |key, value|
        self.class.define_field key
      end
    end

    def save
      creation = new_record?
      @id = self.class.fetch_new_identifier if creation
      connection.multi
      if @attributes.size > 0  
        @attributes.each_pair { |key, value|
          if key.to_sym == :updated_at
            value = Time.now.to_s
          end
          connection.hset("#{key_namespace}:attributes", key, value)
        }
      end
      connection.zadd("#{class_namespace}:all", @id, @id) 
      connection.exec
      return true
    end

    def update_attributes(attributes)
      attributes.stringify_keys!   # NEEDS to be strings for railsisms
      attributes.each_pair { |key, value| attributes[key] = value.to_s }
      @attributes.merge!(attributes)
      attributes.each_pair do |key, value|
        self.class.define_field key
      end
      save
    end

    def reload
      @attributes = connection.hgetall "#{key_namespace}:attributes"
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
    
    def self.define_field(field)
      define_method field.to_sym do
        if field.to_sym == :updated_at
          Time.parse(@attributes["#{field}"])
        else
          @attributes["#{field}"]  
        end
      end

      define_method "#{field}=".to_sym do |new_value|
        @attributes["#{field}"] = new_value.to_s
      end
    end

    # Run this method to declare the fields of your model.
    def self.fields(*fields)
      @@fields = fields
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
      attributes = connection.hgetall "#{key_namespace}:#{id}:attributes"
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
