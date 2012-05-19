$LOAD_PATH << File.dirname(__FILE__) + "/../lib"
require 'active_redis'
require 'pp'

class User < ActiveRedis::Base
  fields "name", "age", "country", "updated_at"
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
joe = User.find_by_name("Joe") #=>#<User:0x0000010193e930 @attributes={"age"=>"22", "name"=>"Joe"}, @id="1">
tom = User.find_by_name("Tom") #=>#<User:0x00000101910c60 @attributes={"age"=>"12", "name"=>"Tom", "country"=>"japan"}, @id="2">
puts tom.updated_at

sleep 1
tom.age = 20
tom.age
tom.save
#tom = User.find_by_age(20)
pp tom.updated_at
tom.reload
pp tom.updated_at

joe.destroy
puts "count: #{User.count}" #=> 1

User.delete_all
puts "count: #{User.count}" #=> 0

pp User.find_by_name("Tom") #=> nil


