#!/usr/bin/ruby
require 'rubygems'
require 'encrypted_strings'
require 'yaml'

case ARGV.size 
when 3
  login=ARGV[0]
  password=ARGV[1]
  secret_key=ARGV[2]
when 2
  login=ARGV[0]
  password=ARGV[1]
  secret_key=''
else
  puts "ERROR: wrong number of arguments"
  puts "USAGE: #{File.basename($0)} login password [secret_key] generates a YAML config file for apple_dev_center.rb"
  exit 1
end

crypted_password = password.encrypt(:symmetric, :password => secret_key).to_s

data={}
data['default'] = login

# force to string
encrypted = '' + crypted_password
# remove trailing /n s
while encrypted[-1] == 10
  encrypted = encrypted[0..-2]
end

account = {}
account['login'] = login
account['password'] = '' + encrypted

data['accounts'] = [ account ]

s = YAML::dump(data)

puts s