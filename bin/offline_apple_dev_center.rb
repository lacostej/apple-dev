#!/usr/bin/ruby
require 'rubygems'
require 'json'

file=ARGV[0]
type=ARGV[1]
name=ARGV[2]

json = File.open(file) { |f| JSON f.read }

profiles=json['profiles']
ps = profiles.select{ |p| p['type'] == type and p['name'] == name }
if (ps.nil? || ps.count == 0) 
	puts "No profile found with name '#{name}' and type '#{type}' in '#{file}'"
	profiles.each { |p| puts "#{p['type']} - #{p['name']}" }
	exit -1
end
p = ps[0]
puts p['uuid']
