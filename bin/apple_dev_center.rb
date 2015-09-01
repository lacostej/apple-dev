#!/usr/bin/ruby
require 'rubygems'
require 'bundler/setup'
require 'optparse'
require 'yaml'
require 'apple-dev'
require 'encrypted_strings'

INSTALL_DIR = File.dirname($0)
USAGE =  "Usage: #{File.basename($0)} [-d [DIR]] [-u login] [-p password] [-t teamid] [-O file] [-C config] [-S secret_key] [-n] [-h] [-f filter] [-P profile_type]"

def info(message)
  puts message
end

def parse_config(options)
  config = YAML::load_file(options[:config_file])

  login_to_fetch = options[:login]
  if login_to_fetch.nil? 
    login_to_fetch = config['default']
    options[:login] = login_to_fetch
  end
  account = config['accounts'].select { |a| a['login'] == login_to_fetch }[0]
  secret_key = options[:secret_key].nil? ? '' : options[:secret_key]
  encrypted = account['password']
  decrypted = encrypted.decrypt(:symmetric, :password => secret_key)
  options[:passwd] = decrypted
  
  #If we have a team id from command line, ignore this
  if options[:teamid].nil?
    options[:teamid] = account['teamid']
    options[:teamname] = account['teamname']
  end
end

def parse_command_line(args)
  options = {}
  options[:profile_file_name] = :uuid

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
      options[:profile_file_name] = :name
    end
    opts.on( '-d', '--dump [DIR]', 'Dump the site content as JSON format to current dir (or to the optional specified directory, that will be created if non existent).') do |dir|
      options[:dump] = true
      options[:dump_dir] = dir.nil? ? '.' : dir
      if not File.exists?(options[:dump_dir])
        Dir.mkdir(options[:dump_dir])
      end
    end
    opts.on( '-S', '--seed SEED', 'The secret_key for the config file if required.') do |secret_key|
      options[:secret_key] = secret_key.nil? ? '' : secret_key
    end
    opts.on( '-C', '--config FILE', 'Fetch password (and optionally default user and team id) information from the specified config file, with the optional secret_key.') do |config_file, secret_key|
      options[:config_file] = config_file
      if not File.exists?(options[:config_file])
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
    opts.on( '-f', '--profile-filter FILTER', 'Download profiles matching FILTER only' ) do |profile_filter|
      options[:profile_filter] = profile_filter.to_sym
    end    
    opts.on( '-P', '--profile-type (development|distribution)', 'Download profiles with certain type only' ) do |profile_type|
      if ! ['development', 'distribution'].include? profile_type
        raise OptionParser::InvalidArgument, "Profile type used for filtering must be either 'development' or 'distribution'"
      end
      options[:profile_type] = profile_type.to_sym
    end    
  }.parse!(args)

  parse_config(options) unless options[:config_file].nil?

  options
end

def dump(text, file)
  if file
    File.open(file, 'w') { |f| f.write(text) }
  else
    puts text
  end
end


def dump_site(options)
  @ADC = Apple::Dev::IOSProvisioningPortal.new(options)
  site = @ADC.fetch_site_data()
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

  if options[:dump]
    dump_site(options)
  end
end

main()
