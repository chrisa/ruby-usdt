# -*- encoding: utf-8 -*-

lib = File.expand_path("../lib", __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'usdt/version'
require 'rbconfig'

Gem::Specification.new do |s|
  s.name        = "ruby-usdt"
  s.version     = USDT::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Kevin Chan"]
  s.email       = ["kevin@yinkei.com"]
  s.homepage    = "http://github.com/kevinykchan/ruby-usdt"
  s.extensions  = ['ext/usdt/extconf.rb']
  s.summary     = "Native DTrace probes for ruby."
  s.files        = Dir.glob("{lib,ext}/**/*") + %w(README.md LICENSE.md)
  s.require_paths = ['lib', 'ext']

  s.add_dependency('json', '> 0.0.0')

  s.add_development_dependency "ruby-dtrace-consumer", "~> 0.3.0"
  s.add_development_dependency "flexmock"
  s.add_development_dependency "rspec"
  s.add_development_dependency "rake"
end
