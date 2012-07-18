debug=0

function debug() {
        if [ $debug -ne 0 ]; then
                echo "DEBUG $1"
        fi
}

PP_DIR="$HOME/Library/MobileDevice/Provisioning Profiles"

ADC=$1
SITE_JSON=$2
file=$3
configuration=$4
profile_type=$5
profile_name=$6

function printStatus() {
	if [ $debug -ne 0 ]; then
    	ls -la "$ADC"
		ls -la "$PP_DIR"
		ls -la "$file"
	fi
}

printStatus
current_pp_uuid=`./pbxproj_pp_uuid.sh $file "$configuration" get`
debug "current_pp_uuid ${current_pp_uuid}"

if [ -z "${current_pp_uuid}" ]; then
	echo "ERROR no selected provisioning profile in XCode project file for configuration '$configuration'. The script only supports updating the configuration today."
	exit 1
fi

if [ $? -ne 0 ]; then
	echo "ERROR Profile UUID not found in $file for configuration $configuration"
	exit
fi

#ls "$PP_DIR"
new_pp_uuid=`../bin/offline_apple_dev_center.rb ${SITE_JSON} ${profile_type} "${profile_name}"`
debug "new_pp_uuid ${new_pp_uuid}"

# 1- install in PP_DIR if necessary
installed_pp="${PP_DIR}/${new_pp_uuid}.mobileprovision"
if [ ! -f "${installed_pp}" ]; then
	echo "INFO profile ${installed_pp} not yet installed. Installing..."
	new_pp="$ADC/$new_pp_uuid.mobileprovision"
	if [ ! -f "${new_pp}" ]; then
		echo "ERROR: couldn't find #{new_pp_uuid} provisioning profile in Local ADC dump. Cannot pursue installation. Exiting."
		exit 1
	fi
	cp "${new_pp}" "${installed_pp}"
	if [ $? -ne 0 ]; then
	    echo "ERROR: failure to install ${new_pp} in ${installed_pp}. Exiting"
		exit 1	
	fi
else
	echo "INFO profile ${installed_pp} already installed. Nothing to do"
fi

# 2- modify xcode project if necessary
if [ "${current_pp_uuid}" == "${new_pp_uuid}" ]; then
   echo "INFO latest (${new_pp_uuid}) Provisioning Profile installed in XCode project. Nothing to do"
else
	echo "INFO Replacing ${current_pp_uuid} with ${new_pp_uuid} in $file"
	# this doesn't work as it converts the file into XML and we lose the comments
	#echo ./pbxproj_pp_uuid.sh $file "$configuration" set $new_pp_uuid
	sed "s/${current_pp_uuid}/${new_pp_uuid}/"  ${file} > ${file}.new
	if [ $? -ne 0 ]; then
    	echo "ERROR: failure to set new ${configuration} provisioning profile to ${new_pp} in ${file}. Exiting"
		exit 1
	fi
	diff -u ${file} ${file}.new
	mv ${file}.new ${file}
fi
# we voluntarily do not clean up the old PP as it might still be in used by other projects
printStatus
exit 0