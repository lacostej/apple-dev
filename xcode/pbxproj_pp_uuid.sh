#!/bin/bash
#
# DEPPRECATED use the ruby script instead
#
# A script to get or set the provisioning profile UUID from a XCode .pbxproj files given its configuration name
#
d=`dirname $0`
dir=`cd $d && pwd`
plutil -convert json $1
if [ "$3" == "get" ]; then
	$dir/pbxproj_pp_uuid.rb "$1" -p "$2" -g
elif [ "$3" == "set" ]; then
	$dir/pbxproj_pp_uuid.rb "$1" -p "$2" -s "$4"
else
	echo "Invalid arguments"
fi
plutil -convert xml1 $1