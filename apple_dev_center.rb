#!/usr/bin/ruby
require 'rubygems'
require "bundler/setup"
require 'apple-dev'

INSTALL_DIR = File.dirname($0)
USAGE =  "Usage: #{File.basename($0)} [-d [DIR]] [-u login] [-p password] [-t teamid] [-O file] [-C config] [-S secret_key] [-n] [-h]"

def info(message)
  puts message
end

def parse_config(options)
  config = YAML::load_file(options[:configFile])
  
  login_to_fetch = options[:login]
  if login_to_fetch.nil? 
    login_to_fetch = config['default']
    options[:login] = login_to_fetch
  end
  account = config['accounts'].select { |a| a['login'] == login_to_fetch }[0]
  secret_key = options[:secretKey].nil? ? "" : options[:secretKey]
  encrypted = account['password']
  decrypted = encrypted.decrypt(:symmetric, :password => secret_key)
  options[:passwd] = decrypted
  options[:teamid] = account['teamid']
  options[:teamname] = account['teamname']
end

def parse_command_line(args)
  options = {}
  options[:profileFileName] = :uuid

  OptionParser.new { |opts|
    opts.banner = USAGE
    
    opts.on( '-u', '--user USER', 'The apple developer store login') do |login|
      options[:login] = login
    end
    opts.on( '-p', '--password PASSWORD', 'The apple developer store password') do |passwd|
      options[:passwd] = passwd
    end
    opts.on( '-t', '--team-id TEAMID', 'The team ID from the Multiple Developer Programs') do |teamid|
      options[:teamid] = teamid
    end
    opts.on( '-T', '--team-name TEAMID', 'The team name from the Multiple Developer Programs') do |teamname|
      options[:teamname] = teamname
    end
    opts.on( '-n', '--name', 'Use the profile name instead of its UUID as basename when saving them') do
      options[:profileFileName] = :name
    end
    opts.on( '-d', '--dump [DIR]', 'Dump the site content as JSON format to current dir (or to the optional specified directory, that will be created if non existent).') do |dir|
      options[:dump] = true
      options[:dumpDir] = dir.nil? ? "." : dir
      if not File.exists?(options[:dumpDir])
        Dir.mkdir(options[:dumpDir])
      end
    end
    opts.on( '-S', '--seed SEED', 'The secret_key for the config file if required.') do |secret_key|
      options[:secretKey] = secret_key.nil? ? "" : secret_key
    end
    opts.on( '-C', '--config FILE', 'Fetch password (and optionally default user and team id) information from the specified config file, with the optional secret_key.') do |config_file, secret_key|
      options[:configFile] = config_file
      if not File.exists?(options[:configFile])
        raise OptionParser::InvalidArgument, "Specified '#{config_file}' file doesn't exist."
      end
    end
    opts.on( '-O', '--output FILE', 'Write output to the specified file. Use standard output otherwise.') do |output|
      options[:output] = output
    end
    opts.on( '-h', '--help', 'Display this screen' ) do
      puts opts
      exit
    end    
  }.parse!(args)

  parse_config(options) unless options[:configFile].nil?

  options
end

def dump(text, file)
  if (file)
    File.open(file, 'w') { |f| f.write(text) }
  else
    puts text
  end
end


def dumpSite(options)
  @ADC = Apple::Dev::IOSProvisioningPortal.new()
  site = @ADC.fetch_site_data(options)
  text = site.to_json
  dump(text, options[:output])
end

def main()
  begin
    options = parse_command_line(ARGV)
  rescue OptionParser::ParseError => e
    puts "Invalid argument: #{e}"
    puts "#{USAGE}"
    exit 1
  end

  if (options[:dump])
    dumpSite(options)
  end
end

main()
