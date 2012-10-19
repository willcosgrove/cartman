# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cartman/version'

Gem::Specification.new do |gem|
  gem.name          = "cartman"
  gem.version       = Cartman::VERSION
  gem.authors       = ["Will Cosgrove"]
  gem.email         = ["will@willcosgrove.com"]
  gem.description   = %q{Cartman is a frameworke agnostic, redis-backed, shopping cart system}
  gem.summary       = %q{Doing shopping carts like a boss since 2012}
  gem.homepage      = "http://github.com/willcosgrove/cartman"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_dependency("redis")

  gem.add_development_dependency("rspec")
end
