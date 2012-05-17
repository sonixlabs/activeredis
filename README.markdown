# ActiveRedis

ActiveModel based object persisting library for [Redis](http://code.google.com/p/redis) key-value database.

## Features

* ActiveModel compatibility
* Race condition free operations

## Missing features

A lot. ActiveRedis is currently designed to handle concurrency issues.  Use [OHM](http://ohm.keyvalue.org/) or [remodel](http://github.com/tlossen/remodel) if you need advanced features and can accept some potential concurrency issues.

* Indexes
* Relations
* Other cool stuff

## How to start

1. Clone the repository
3. Install gems 

    bundle install

4. Run spec

    rspec spec/core_spec.rb

## Sample Code

    require 'active_redis'
    require 'pp'
    
    class User < ActiveRedis::Base
      fields :name, :age, :country
    end

     create user(1)
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


## Contributing

Pull requests are welcome!

For any questions contact [yamadakazu45@gmail.com](mailto:yamadakazu45@gmail.com)
