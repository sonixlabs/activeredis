$LOAD_PATH << File.dirname(__FILE__) + "/../lib"
require 'active_redis'
require 'pp'

class User < ActiveRedis::Base
  fields :name, :age, :country
end

# create user(1)
user = User.new :age => 22, :name => "Joe"
user.save

# create user(2)
user = User.new
user.age = 12
user.name = "Tom"
user.country = "japan"
user.save

puts "count: #{User.count}" #=> 2
pp joe = User.find_by_name("Joe") #=>#<User:0x0000010193e930 @attributes={"age"=>"22", "name"=>"Joe"}, @id="1">
pp tom = User.find_by_age(12) #=>#<User:0x00000101910c60 @attributes={"age"=>"12", "name"=>"Tom", "country"=>"japan"}, @id="2">

joe.destroy
puts "count: #{User.count}" #=> 1

tom.destroy
puts "count: #{User.count}" #=> 0

pp User.find_by_name("Tom") #=> nil

User.delete_all
