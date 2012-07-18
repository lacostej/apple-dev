#!/usr/bin/env ruby
#
# A script to get or set the provisioning profile UUID from a XCode .pbxproj files given its configuration name
#
require 'rubygems'
require 'json'
require 'logger'

@log=Logger.new(STDOUT)
@log.level = Logger::WARN


#if ! File.exists(plutil)
#	puts "ERROR plutil not found in expected location"
#	exit
#end

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
end

file=ARGV[0]
configuration=ARGV[1]
action=ARGV[2]
value=ARGV[3]


if ! File.exist?(file)
	puts "ERROR: $#{file} file not found"
	usage
	exit
end

#plutil='/usr/bin/plutil'
#wasBinary=false
#f = File.open(file)
#
#begin
#	json = JSON f.read
#rescue
#	f.close
#	wasBinary=true
#	`#{plutil} -convert json -r #{file}`
	# TODO check result
	f = File.open(file, "r")
	json = JSON f.read
#end


# 1- find the matching build configuration
rootObj=json['rootObject']
debug "rootObj #{rootObj}"

buildConfigurationList=json['objects'][rootObj]['buildConfigurationList']
debug "buildConfigurationList $buildConfigurationList"

buildConfigurationObjId=json['objects'][buildConfigurationList]['buildConfigurations'].find { |x| json['objects'][x]['name'] == configuration }
debug "buildConfigurationObjId for #{configuration}: #{buildConfigurationObjId}"

case action
when 'set'
	json['objects'][buildConfigurationObjId]['buildSettings']['PROVISIONING_PROFILE[sdk=iphoneos*]'] = value
	f = File.open(file, "w")
	f.write(json.to_json)
when 'get'
	uuid=json['objects'][buildConfigurationObjId]['buildSettings']['PROVISIONING_PROFILE[sdk=iphoneos*]']
	puts uuid
else
	puts "INVALID action #{action}"
end
f.close

#if wasBinary
#	`#{plutil} -convert binary1 -r #{file}`
#end