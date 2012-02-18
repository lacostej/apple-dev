#!/usr/bin/ruby
require "rubygems"
require "plist"
require "openssl"
require "optparse"

USAGE =  "Usage: #{File.basename($0)} profileFile [-t] [-d [key]] [-O output] [-h]"

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

def dumpProfile(xml, options)
  text = xml
  if (options[:dumpKey])
    r = Plist::parse_xml(xml)  
    text = r[options[:dumpKey]]
  end
  dump(text, options[:output])
end

def dumpProfileType(xml, options)
  r = Plist::parse_xml(xml)
  # http://stackoverflow.com/questions/1003066/what-does-get-task-allow-do-in-xcode
  get_task_allow = r["Entitlements"]["get-task-allow"]
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
  
  profile = File.read(options[:profile])

  p7 = OpenSSL::PKCS7.new(profile)

  store = OpenSSL::X509::Store.new
  p7.verify([], store)

  text = p7.data

  if (options[:dump])
    dumpProfile(text, options)
  elsif (options[:type])
    dumpProfileType(text, options)
  end
end

main()
