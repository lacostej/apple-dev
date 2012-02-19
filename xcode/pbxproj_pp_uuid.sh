#!/bin/bash
#
# A script to get or set the provisioning profile UUID from a XCode .pbxproj files given its configuration name
#
debug=0
plistBuddy=/usr/libexec/PlistBuddy

if [ ! -x $plistBuddy ]; then
	echo "ERROR PlistBuddy not found in expected location"
	exit 1
fi

function usage() {
	echo -e "USAGE: $0 file configuration action [value]"
	echo -e "\tfile: the xcode project file"
	echo -e "\tconfiguration: name of the configuration e.g. 'Ad Hoc'"
	echo -e "\taction: get or set"
	echo -e "\tvalue: the new uuid to set (if action is 'set')"
}

function debug() {
	if [ $debug -ne 0 ]; then
		echo "DEBUG $1"
	fi
}
case "$#" in
	4)
	file=$1
	configuration=$2
	action=$3
	new_uuid=$4
	if [ "${action}" != "set" ]; then
		echo "ERROR: invalid action or arguments for action $action"
		usage
		exit 1
	fi
	;;
	3)
	file=$1
	configuration=$2
	action=$3
	if [ "${action}" != "get" ]; then
		echo "ERROR: invalid action or arguments for action $action"
		usage
		exit 1
	fi
	;;
	*)
	echo "ERROR: invalid arguments"
	usage
	exit 1
	;;
esac

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
case "${action}" in
set)
    echo "$plistBuddy $file -c Set objects:${buildConfigurationObjId}:buildSettings:PROVISIONING_PROFILE[sdk=iphoneos*] ${new_uuid}"
	uuid=`$plistBuddy $file -c "Set objects:${buildConfigurationObjId}:buildSettings:PROVISIONING_PROFILE[sdk=iphoneos*] ${new_uuid}" 2>/dev/null`
	if [ $? -ne 0 ]; then
		echo "ERROR: couldn't set the uuid to ${value} for object '${buildConfigurationObjId}'"
		exit 1
	fi
	exit 0
	;;
get)
	uuid=`$plistBuddy $file -c "Print objects:${buildConfigurationObjId}:buildSettings:PROVISIONING_PROFILE[sdk=iphoneos*]" 2>/dev/null`
	if [ $? -ne 0 ]; then
		echo "ERROR: couldn't find uuid name for object '${buildConfigurationObjId}'"
		exit 1
	fi
	debug "uuid $uuid"
	echo "$uuid"
	exit 0
	;;
*)
	echo "INVALID action $action"
	exit 1
	;;
esac