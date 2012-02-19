#!/bin/bash
#
# A script to extract the provisioning profile UUID from a XCode .pbxproj files given its configuration name
#
debug=0
plistBuddy=/usr/libexec/PlistBuddy

if [ ! -x $plistBuddy ]; then
	echo "ERROR PlistBuddy not found in expected location"
	exit 1
fi

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

if [ ! -f $file ]; then
	echo "ERROR: $file file not found"
	usage
	exit 1
fi

# 1- find the matching build configuration
rootObj=`$plistBuddy $file -c "Print rootObject" 2>/dev/null`
if [ $? -ne 0 ]; then
	echo "ERROR: couldn't find rootObject in file '${file}'. Is the file an XCode project file ?"
	exit 1
fi
debug "rootObj $rootObj"
buildConfigurationList=`$plistBuddy $file -c "Print objects:$rootObj:buildConfigurationList" 2>/dev/null`
if [ $? -ne 0 ]; then
	echo "ERROR: couldn't find buildConfigurationList in file '${file}'"
	exit 1
fi
debug "buildConfigurationList $buildConfigurationList"

buildConfigurationObjId=
idx=0
while [ 1 ]; do
	x=`$plistBuddy $file -c "Print objects:$buildConfigurationList:buildConfigurations:$idx" 2>/dev/null`
	if [ $? -ne 0 ]; then
		break
	fi
	namex=`$plistBuddy $file -c "Print objects:${x}:name" 2>/dev/null`
	if [ $? -ne 0 ]; then
		echo "ERROR: couldn't find buildConfiguration name for object '${x}'"
		exit 1
	fi
	debug "Configuration: $namex"
	if [ "$namex" == "$configuration" ]; then
		buildConfigurationObjId=$x
		break
	fi
	let "idx++"
done

debug "buildConfigurationObjId for $configuration: ${buildConfigurationObjId}"

uuid=`$plistBuddy $file -c "Print objects:${buildConfigurationObjId}:buildSettings:PROVISIONING_PROFILE[sdk=iphoneos*]" 2>/dev/null`
if [ $? -ne 0 ]; then
	echo "ERROR: couldn't find uuid name for object '${buildConfigurationObjId}'"
	exit 1
fi
debug "uuid $uuid"
#codeSign=`$plistBuddy $file -c "Print objects:${buildConfigurationObjId}:buildSettings:CODE_SIGN_IDENTITY[sdk=iphoneos*]"`
#debug "codeSign $codeSign"

# 2- display the UUID
echo "$uuid"