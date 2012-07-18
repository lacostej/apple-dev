#!/usr/bin/env ruby
#
# A script to get or set the provisioning profile UUID from a XCode .pbxproj files given its configuration name
#
require 'rubygems'
require 'json'
require 'logger'
require 'optparse'

@log=Logger.new(STDOUT)
@log.level = Logger::WARN

def ensure_file_specified_and_exists(name, file)
  raise OptionParser::MissingArgument, name if file.nil?
  raise OptionParser::InvalidArgument, "'#{file}' #{name} file doesn't exists" if not File.exists?(file)
end

def parse_command_line(args)
	options = {}

	opts = OptionParser.new { |opts|
		opts.banner = "Usage: #{File.basename($0)} jsonProjectFile options"
		opts.separator("Options:")

		opts.on( '-p', '--profile-name [NAME]', 'The provisioning profile to work with.') do |key|
			options[:profile] = key
		end
		opts.on( '-g', '--get', 'Get the current value') do
		end
		opts.on( '-s', '--set NEW', 'sets the new value') do |value|
			options[:value] = value
		end
		opts.on('-v', '--verbose', "Verbose output") do
			@log.level = Logger::DEBUG
		end
		opts.on_tail( '-h', '--help', 'Display this screen.' ) do
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
	}

	options[:projfile] = args[0]
	ensure_file_specified_and_exists("json pbxproj", options[:projfile])

	options
end

def debug(msg)
	@log.debug("DEBUG #{msg}")
end

def main()
	options = parse_command_line(ARGV)

	file=options[:projfile]
	configuration=options[:profile]
	value=options[:value]

	debug("ARGUMENTS: f:#{file} f:#{configuration} v:#{value} ")


	json = File.open(file, "r") { |f| JSON f.read }

	rootObj=json['rootObject']
	debug "rootObj #{rootObj}"

	buildConfigurationList=json['objects'][rootObj]['buildConfigurationList']
	debug "buildConfigurationList #{buildConfigurationList}"

	buildConfigurationObjId=json['objects'][buildConfigurationList]['buildConfigurations'].find { |x| json['objects'][x]['name'] == configuration }
	debug "buildConfigurationObjId for #{configuration}: #{buildConfigurationObjId}"

	buildSettings=json['objects'][buildConfigurationObjId]['buildSettings']
	if !value.nil?
		buildSettings['PROVISIONING_PROFILE[sdk=iphoneos*]']=value
		File.open(file, "w") { |f| f.write(json.to_json) }
	else
		puts buildSettings['PROVISIONING_PROFILE[sdk=iphoneos*]']
	end
end

main