# -*- encoding: utf-8 -*-
require File.expand_path('../lib/apple-dev/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Jerome Lacoste"]
  gem.email         = ["jerome.lacoste@gmail.com"]
  gem.description   = %q{a library and set of programs to manage Apple development site and data programatically including provisionning profiles, certificates...}
  gem.summary       = %q{The Apple Dev management toolbox Gem}
  gem.homepage      = "http://github.com/lacostej/apple-dev"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "apple-dev"
  gem.require_paths = ["lib"]
  gem.version       = Apple::Dev::VERSION

  gem.required_rubygems_version = ">= 1.3.6"
  gem.rubyforge_project = "apple-dev"

  gem.add_development_dependency "bundler", ">= 1.0.0"
  gem.add_development_dependency "rspec", "~> 2.6"

  gem.add_dependency "mechanize"
  gem.add_dependency "json"
  gem.add_dependency "plist"
  gem.add_dependency "encrypted_strings"
  gem.add_dependency "logger"
end
