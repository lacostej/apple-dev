#!/usr/bin/ruby
require 'optparse'
require 'ostruct'
require 'rubygems'
require 'encrypted_strings'
require 'yaml'

# Set default options.
opts = OpenStruct.new
opts.login = ""
opts.password = ""
opts.secret_key = ""
opts.teamid = ""

# Specify options.
options = OptionParser.new do |options|
  options.banner = "Usage: #{File.basename($0)} [options]\nGenerates a YAML config file for apple_dev_center.rb"
  options.separator "Mandatory options:"
  options.on("-l", "--login LOGIN", "Login e-mail address") {|l| opts.login = l}
  options.on("-p", "--password PASS", "Login password") {|p| opts.password = p}
  options.separator "Optional options:"
  options.on("-t", "--team-id TID", "Team ID - The team ID from the Multiple Developer Programs") {|t| opts.teamid = t}
  options.on("-s", "--secret-key SECRET-KEY", "Secret key") {|s| opts.secret_key = s}
  options.separator "General options:"
  options.on_tail("-h", "--help", "Show this message") do
    puts options
    exit
  end
end

# Show usage if no arguments are given.
if (ARGV.empty?)
  puts options
  exit
end

# Parse options.
begin 
  options.parse!
rescue
  puts options
  exit 1
end

crypted_password = opts.password.encrypt(:symmetric, :password => opts.secret_key).to_s

data={}
data['default'] = opts.login

# Force to string
encrypted = '' + crypted_password
# Remove trailing carriage return characters (\n, \r, and \r\n)
encrypted = encrypted.chomp()

account = {}
account['login'] = opts.login
account['password'] = encrypted
account['teamid'] = opts.teamid

data['accounts'] = [account]

s = YAML::dump(data)

puts s
