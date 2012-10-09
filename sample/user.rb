require 'active_redis'
require 'pp'

# ActiveRedis.host = "localhost"
# ActiveRedis.port = "6379"
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
pp joe = User.find_by_name("Joe") #=>#<User:0x0000010193e930 @attributes={"age"=>"22", "name"=>"Joe"}, @id="1">
pp tom = User.find_by_name("Tom") #=>#<User:0x00000101910c60 @attributes={"age"=>"12", "name"=>"Tom", "country"=>"japan"}, @id="2">

tom.update_attributes({:age => 20})
#tom = User.find_by_age(20)
tom.reload
pp tom

joe.destroy
puts "count: #{User.count}" #=> 1

User.delete_all
puts "count: #{User.count}" #=> 0

pp User.find_by_name("Tom") #=> nil


