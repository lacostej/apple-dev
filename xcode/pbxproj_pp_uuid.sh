#!/bin/bash
#
# A script to extract the provisioning profile UUID from a XCode .pbxproj files given its configuration name
#
debug=0

function usage() {
	echo "USAGE: $0 file configuration value"
	echo "file: the xcode project file"
	echo "configuration: name of the configuration e.g. 'Ad Hoc'"
}

function debug() {
	if [ $debug -ne 0 ]; then
		echo "DEBUG $1"
	fi
}

if [ $# -lt 2 ]; then
	echo "ERROR: invalid arguments"
	usage
	exit 1
fi
file=$1
configuration=$2
value=$3

plistBuddy=/usr/libexec/PlistBuddy

# 1- find the matching build configuration

rootObj=`$plistBuddy $file -c "Print rootObject"`
debug "rootObj $rootObj"
buildConfigurationList=`$plistBuddy $file -c "Print objects:$rootObj:buildConfigurationList"`
debug "buildConfigurationList $buildConfigurationList"
x1=`$plistBuddy $file -c "Print objects:$buildConfigurationList:buildConfigurations:size"`

buildConfigurationObjId=
idx=0

while [ 1 ]; do
	x=`$plistBuddy $file -c "Print objects:$buildConfigurationList:buildConfigurations:$idx" 2>/dev/null`
	if [ $? -ne 0 ]; then
		break
	fi
	namex=`$plistBuddy $file -c "Print objects:${x}:name"`
	debug "Configuration: $namex"
	if [ "$namex" == "$configuration" ]; then
		buildConfigurationObjId=$x
	fi
	let "idx++"
done

debug "buildConfigurationObjId for $configuration: ${buildConfigurationObjId}"

#codeSign=`$plistBuddy $file -c "Print objects:${buildConfigurationObjId}:buildSettings:CODE_SIGN_IDENTITY[sdk=iphoneos*]"`
provProfile=`$plistBuddy $file -c "Print objects:${buildConfigurationObjId}:buildSettings:PROVISIONING_PROFILE[sdk=iphoneos*]" 2>/dev/null`
#debug "codeSign $codeSign"
debug "provProfile $provProfile"

# 2- display the UUID
echo "$provProfile"