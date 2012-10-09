require 'rubygems'
require 'bundler/setup'

require 'activeredis' # and any other gems you need

RSpec.configure do |config|
  config.before(:each) do
    ActiveRedis::Base.connection.flushall
  end
end
