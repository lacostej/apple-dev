#!/usr/bin/env ruby
#
# A script to get or set the provisioning profile UUID from a XCode .pbxproj files given its configuration name
#
require 'rubygems'
require 'json'
require 'logger'

@log=Logger.new(STDOUT)
@log.level = Logger::WARN

def usage()
	puts "USAGE: #{ARGV[0]} file configuration action [value]"
	puts "\tfile: the xcode project file"
	puts "\tconfiguration: name of the configuration e.g. 'Ad Hoc'"
	puts "\taction: get or set"
	puts "\tvalue: the new uuid to set (if action is 'set')"
end

def debug(msg)
	@log.debug("DEBUG #{msg}")
end

if (ARGV.length < 3 || ARGV.length > 4)
	puts "ERROR invalid arguments"
	usage()
	exit
end

file=ARGV[0]
configuration=ARGV[1]
action=ARGV[2]
value=ARGV[3]

debug("ARGUMENTS: f:#{file} f:#{configuration} a:#{action} #{value} ")

if ! File.exist?(file)
	puts "ERROR: $#{file} file not found"
	usage
	exit
end

json = File.open(file, "r") { |f| JSON f.read }

rootObj=json['rootObject']
debug "rootObj #{rootObj}"

buildConfigurationList=json['objects'][rootObj]['buildConfigurationList']
debug "buildConfigurationList #{buildConfigurationList}"

buildConfigurationObjId=json['objects'][buildConfigurationList]['buildConfigurations'].find { |x| json['objects'][x]['name'] == configuration }
debug "buildConfigurationObjId for #{configuration}: #{buildConfigurationObjId}"

buildSettings=json['objects'][buildConfigurationObjId]['buildSettings']
case action
when 'set'
	buildSettings['PROVISIONING_PROFILE[sdk=iphoneos*]']=value
	File.open(file, "w") { |f| f.write(json.to_json) }
when 'get'
	puts buildSettings['PROVISIONING_PROFILE[sdk=iphoneos*]']
else
	puts "INVALID action #{action}"
end