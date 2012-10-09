# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'activeredis/version'

Gem::Specification.new do |gem|
  gem.name          = "activeredis"
  gem.version       = ActiveRedis::VERSION
  gem.authors       = ["Kazuhiro Yamada", "Yuta Hirakawa"]
  gem.email         = ["sonixlabs@sonix.asia", "kyamada@sonix.asia"]
  gem.description   = %q{ActiveModel based object persistance library for Redis}
  gem.summary       = %q{ActiveModel based object persisting library for Redis key-value database.}
  gem.homepage      = "https://github.com/sonixlabs/activeredis"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_dependency 'redis'
  gem.add_dependency 'activemodel'
  gem.add_development_dependency 'rspec'
end
