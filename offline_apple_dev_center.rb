#!/usr/bin/ruby
require 'rubygems'
require 'json'

file=ARGV[0]
type=ARGV[1]
name=ARGV[2]

f = File.open(file)
json = JSON f.read
profiles=json['profiles']

p = profiles.select{ |p| p['type'] == type and p['name'] == name }[0]

puts p['uuid']
