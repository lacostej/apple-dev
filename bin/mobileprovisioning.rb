#!/usr/bin/ruby
require "rubygems"
require "bundler/setup"
require 'optparse'
require 'yaml'
require 'apple-dev'

def ensure_file_specified_and_exists(name, file)
  raise OptionParser::MissingArgument, name if file.nil?
  raise OptionParser::InvalidArgument, "'#{file}' #{name} file doesn't exists" if not File.exists?(file)
end

def parse_command_line(args)
  options = {}

  opts = OptionParser.new { |opts|
    opts.banner = "Usage: #{File.basename($0)} profileFile options"
    opts.separator("Options:")
    
    opts.on( '-d', '--dump [KEY]', 'Dump a particular KEY or the full XML.') do |key|
      options[:dump] = true
      options[:dumpKey] = key
    end
    opts.on( '-t', '--type', 'Prints the type of the profile (distribution or development).') do |key|
      options[:type] = true
    end
    opts.on( '-o', '--output FILE', 'Write output to FILE. Default is standard output.') do |output|
      options[:output] = output
    end
    opts.on('-c', '--certificate CERTIFICATE', 'Use CERTIFICATE to verify profile.') do |certificate|
      options[:certificate] = certificate
    end
    options[:verbose] = false
    opts.on('-v', '--verbose', "Show the profile's type, verification, signers, recipients and certificates.") do
      options[:verbose] = true
    end
    opts.on_tail( '-h', '--help', 'Display this screen.' ) do
      puts opts
      exit
    end
  }
  
  if (args.empty?)
    puts opts
    exit
  end
  
  begin 
    opts.parse!(args)
  rescue OptionParser::ParseError => e
    puts "Found #{e}"
    puts opts
    exit 1
  end

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
  if pp.text.nil?
    puts "The profile content is nil. Maybe the verification failed? Try -v."
  else
    text = pp
    key = options[:dumpKey]
    if key
      text = pp[key]
    end
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
  options = parse_command_line(ARGV)
  
  pp = Apple::Dev::ProvisioningProfile.new(options[:profile], options[:certificate])

  if options[:verbose]
    pp.dump
  end
  
  if (options[:dump])
    dumpProfile(pp, options)
  elsif (options[:type])
    dumpProfileType(pp, options)
  end
end

main()
