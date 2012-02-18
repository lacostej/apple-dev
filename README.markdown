# What is this? #

This is a set of scripts written in Ruby used to manage provisioning profiles either locally or through the Apple developer portal.

They are used in continuous integration environments (for example using [Jenkins](http://jenkins-ci.org)) to update, compile & validate iOS (or [Unity3d](http://unity3d.com) projects.

# required dependencies #

to manipulate provisioning profiles, you will need [plist](http://plist.rubyforge.org/Plist.html) and [json](http://flori.github.com/json/)
to access the Apple development center site, you will need [mechanize >= 2.2](http://mechanize.rubyforge.org/) and [encrypted_strings](https://github.com/pluginaweek/encrypted_strings)

# provisioningprofile.rb #

	$ ruby ./mobileprovisioning.rb 65RAGE----.mobileprovision -d -O plist.xml
	$ tail plist.xml
			<string>D7NQRKKW84</string>
			</array>
			<key>TimeToLive</key>
			<integer>340</integer>
			<key>UUID</key>
			<string>A7D868EA-B1F3-4280-BD01-464653A-----</string>
			<key>Version</key>
			<integer>1</integer>
		</dict>
	</plist>
	$ ruby ./mobileprovisioning.rb 65RAGE----.mobileprovision -d UUID
	A7D868EA-B1F3-4280-BD01-464653A-----
	$ ruby ./mobileprovisioning.rb 65RAGE----.mobileprovision -t
	distribution
	$ ruby ./mobileprovisioning.rb 65RAGE----.mobileprovision -d Name
	TestFlight WWTK All Projects

# apple_dev_center.rb #

	$ ./apple_dev_center.rb -u adminwwtk@wewanttoknow.com -p xxxxxxx -d devcenter -O devcenter/site.json
	$ ls devcenter/
	65RAGE----.mobileprovision site.json
	$ prettyprint devcenter/site.json
	{
	    "profiles": [
	        {
	            "name": "iOS Team Provisioning Profile: *",
	            "type": "development",
				"appid": "D7NQRK----.*",
	            "blobId": "65RAGE----",
	            "statusXcode": "Active"
	        }
	    ],
	    "devices": [
	        {
	            "name": "------- iPad 2 Wi-Fi",
	            "udid": "96b9d40cdc20417928dd71c4a0cc03----------"
	        }
	    ]
	}

## storing the password (encrypted in a configuration file instead) ##

If you don't want to have your password on the command line (so that it doesn't appear in log files), you can generate a config file

	$ ./generate_apple_dev_center_config.rb yourlogin@apple.com YourSecretPassword "an optional seed key" > /path/to/config/apple_dev_center.config
	$ cat /path/to/config/apple_dev_center.config
	--- 
	default: yourlogin@apple.com
	accounts: 
	- password: l1/ChJtwxlmDnav8D4dZafRi6NOdme4Z
	  login: yourlogin@apple.com

then use the apple_dev_center script as following:

	# to avoid having to place password information on the command line
	$ ./apple_dev_center.rb -u adminwwtk@wewanttoknow.com -C /path/to/config/apple_dev_center.config -S "an optional seed key" -d
	[...]
	# or to pick the default account and an empty secret key
	$ ./apple_dev_center.rb -C /path/to/config/apple_dev_center.config -d 

## Technical information ##

Provisioning profiles are PKCS7 signed messages. The message itself is an XML plist. The script extracts the plist.

	

# Feedback #

Question & feedback: jerome.lacoste@gmail.com

# Links #

https://github.com/quadion/iOSValidation where I got some tips for parsing provisioning profiles
http://www.peerassembly.com/2011/09/30/Downloading-UDID-From-Apple/ where I got some tips for downloading data from Apple developer center