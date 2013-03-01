require 'redis'
require 'time'
require 'active_model'

require 'active_model/version'

class Module
  def module_attr_reader(*syms)
    syms.each do |sym|
      class_eval(<<-EOS, __FILE__, __LINE__ + 1)
        @@#{sym} = nil unless defined?(@@#{sym})
        def self.#{sym}()
          return @@#{sym}
        end
      EOS
    end
  end
  def module_attr_writer(*syms)
    syms.each do |sym|
      class_eval(<<-EOS, __FILE__, __LINE__ + 1)
        def self.#{sym}=(obj)
          @@#{sym} = obj
        end
      EOS
    end
  end
  def module_attr_accessor(*syms)
    module_attr_reader(*syms)
    module_attr_writer(*syms)
  end
end

module ActiveRedis
  module_attr_accessor :host, :port, :fast_find_field
  @@host = "localhost"
  @@port = "6379"

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

    QUEUED = "QUEUED"

    # RAILSISM
    # Returns a hash of all the attributes with their names as keys and the values of the attributes as values
    #  --> means: Strings as keys!
    #  --> initialize stringifies
    #
    #  called by to_json for_example
    attr_reader :attributes
    attr_reader :id
    attr :frozen

    class << self; attr_accessor :_fields; end

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
      fields = Hash[[self.class._fields, Array.new(self.class._fields.size)].transpose]
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
      connection.multi do
        if @attributes.size > 0
          @attributes.each_pair { |key, value|
            if key.to_sym == :updated_at
              value = Time.now.to_s
            end
            connection.hset("#{key_namespace}:attributes", key, value)
          }
        end
        if ActiveRedis.fast_find_field != nil
          connection.hset("#{class_namespace}:fast_find_field", @attributes[ActiveRedis.fast_find_field.to_s].to_s, @id)
          if self.class._fields.include?(:no)
            connection.hset("#{class_namespace}:no", @attributes[:no.to_s].to_s, @id)
          end
        end
        connection.zadd("#{class_namespace}:all", @id, @id)
      end
      true
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
        if ActiveRedis.fast_find_field != nil
          connection.hdel "#{class_namespace}:fast_find_field", @attributes[ActiveRedis.fast_find_field.to_s].to_s
          if self.class._fields.include?(:no)
            connection.hdel "#{class_namespace}:no", @attributes[:no.to_s].to_s
          end
        end
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

    def [](field)
      send(field)
    end

    def []=(field, value)
      send(field+"=", value)
    end

    #
    # CLASS METHODS
    #

    def self.create(attributes)
      self.new(attributes).save
    end

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
      self._fields ||= []
      self._fields = fields
    end

    def self.get_fields
      self._fields
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
      #puts "Redis.new(:host => #{ActiveRedis.host}, :port => #{ActiveRedis.port})"
      @@redis = Redis.new(:host => ActiveRedis.host, :port => ActiveRedis.port)
      @@class = child
    end

    def self.redis_information
      connection.info # call_command [:info]
    end

    def self.connection
      @@redis
    end

    def self.count
      size = connection.zcard "#{key_namespace}:all"
    end

    def self.find_all()
      records = []
      # TODO Interim fix, "QUEUED" is find(id) rescue
      ids = connection.zrange "#{key_namespace}:all", 0, count
      ids.each do |id|
        records << find(id)
      end
      records
    end

    def self.all
      find_all
    end

    def self.delete_all
      records = find_all
      records.each do |record|
        record.destroy
      end
      if ActiveRedis.fast_find_field != nil
        connection.del "#{key_namespace}:fast_find_field", "#{key_namespace}:no"
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
      find_id = self.fast_find_by_param(field, value)
      return find(find_id) if find_id != nil
      ids = connection.zrange "#{key_namespace}:all", 0, count
      ids.each do |id|
        record = find(id)
        if record.attributes[field.to_s] == value.to_s
          return record
        end
      end
      nil
    end

    def self.fast_find_by_param(field, value)
      if ActiveRedis.fast_find_field == field
        find_id = connection.hget "#{key_namespace}:fast_find_field", value
      elsif field == :no
        find_id = connection.hget "#{key_namespace}:no", value
      end
    end

    def self.method_missing(name, *args)
      return find_by_param($1.to_sym, args[0]) if name.to_s =~ /^find_by_(.*)/
      return find_all_by_param($1.to_sym, args[0]) if name.to_s =~ /^find_all_by_(.*)/
      super
    end

    def self.delete_unused_field
      ids = connection.zrange "#{key_namespace}:all", 0, count
      if ids.size > 0
        attributes = connection.hgetall "#{key_namespace}:#{ids[0]}:attributes"
        now_keys   = self.get_fields
        array = []
        now_keys.each do |key|
          array << key.to_s
        end
        attributes.reject! {|key| array.include? key }
        attributes.keys.each do |delete_key|
          ids.each do |id|
            connection.hdel "#{key_namespace}:#{id}:attributes", delete_key
          end
        end
      end
    end
  end
end
