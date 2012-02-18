# What is this? #

This is a set of scripts written in Ruby used to manage provisioning profiles either locally or through the Apple developer portal.

They are used in continuous integration environments (for example using [Jenkins](http://jenkins-ci.org)) to update, compile & validate iOS (or [Unity3d](http://unity3d.com) projects.

# required dependencies #

to manipulate provisioning profiles, you will need [plist](http://plist.rubyforge.org/Plist.html)
to access the Apple development center site, you will need [mechanize >= 2.2](http://mechanize.rubyforge.org/)

# provisioningprofile.rb #

	$ ruby ./mobileprovisioning.rb YEHUKG8P95.mobileprovision -d -O plist.xml
	$ tail plist.xml
			<string>D7NQRKKW84</string>
			</array>
			<key>TimeToLive</key>
			<integer>340</integer>
			<key>UUID</key>
			<string>A7D868EA-B1F3-4280-BD01-464653A7449D</string>
			<key>Version</key>
			<integer>1</integer>
		</dict>
	</plist>
	$ ruby ./mobileprovisioning.rb YEHUKG8P95.mobileprovision -d UUID
	A7D868EA-B1F3-4280-BD01-464653A7449D
	$ ruby ./mobileprovisioning.rb YEHUKG8P95.mobileprovision -t
	distribution
	$ ruby ./mobileprovisioning.rb YEHUKG8P95.mobileprovision -d Name
	TestFlight WWTK All Projects

## Explanation ##

Provisioning profiles are PKCS7 signed messages. The message itself is an XML plist. The script extracts the plist.

# apple_dev_center.rb #

	$ ./apple_dev_center.rb -u adminwwtk@wewanttoknow.com -p xxxxxxx -d -O site.json
    $ prettyprint site.json
	{
	    "profiles": [
	        {
	            "name": "iOS Team Provisioning Profile: *",
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

# Feedback #

Question & feedback: jerome.lacoste@gmail.com

# Links #

https://github.com/quadion/iOSValidation