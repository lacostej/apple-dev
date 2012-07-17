#!/usr/bin/ruby
require "rubygems"
require "bundler/setup"
require 'apple-dev'

USAGE = "Usage: #{File.basename($0)} profileFile [-t] [-d [key]] [-c certificate] [-O output] [-h]"

def ensure_file_specified_and_exists(name, file)
  raise OptionParser::MissingArgument, name if file.nil?
  raise OptionParser::InvalidArgument, "'#{file}' #{name} file doesn't exists" if not File.exists?(file)
end

def parse_command_line(args)
  options = {}

  OptionParser.new { |opts|
    opts.banner = USAGE
    
    opts.on( '-d', '--dump [KEY]', 'dumps a particular key or the full xml') do |key|
      options[:dump] = true
      options[:dumpKey] = key
    end
    opts.on( '-t', '--type', 'prints the type of the profile. distribution or development') do |key|
      options[:type] = true
    end
    opts.on( '-O', '--output FILE', 'writes output to the specified file. Uses standard output otherwise') do |output|
      options[:output] = output
    end
    opts.on( '-h', '--help', 'Display this screen' ) do
      puts opts
      exit
    end
    opts.on('-c', '--certificate CERTIFICATE', 'Use CERTIFICATE to verify profile.') do |certificate|
      options[:certificate] = certificate
    end
  }.parse!(args)

  options[:profile] = args[0]
  ensure_file_specified_and_exists("profile", options[:profile])
  
  options
end

def dump(text, file)
  if (file)
    File.open(file, 'w') { |f| f.write(text) }
  else
    puts text
  end
end

def dumpProfile(pp, options)
  text = pp
  key = options[:dumpKey]
  if key
    text = pp[key]
  end
  dump(text, options[:output])
end

def dumpProfileType(pp, options)
  # http://stackoverflow.com/questions/1003066/what-does-get-task-allow-do-in-xcode
  get_task_allow = pp["Entitlements"]["get-task-allow"]
  type = get_task_allow ? "development" : "distribution"
  dump(type, options[:output])
end

def main()
  begin
    options = parse_command_line(ARGV)
  rescue OptionParser::ParseError => e
    puts "Invalid argument: #{e}"
    puts "#{USAGE}"
    exit 1
  end
  
  pp = Apple::Dev::ProvisioningProfile.new(options[:profile], options[:certificate])

  #pp.dump
  
  if (options[:dump])
    dumpProfile(pp, options)
  elsif (options[:type])
    dumpProfileType(pp, options)
  end
end

main()
