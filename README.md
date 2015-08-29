# Note:

While the following tools are working as they should I am in the process of migrating our infrastructure to [Fastlane](http://fastlane.tools/). The tool below might be rewritten using [spaceship](https://github.com/fastlane/spaceship) for all the benefits it provides.

# Apple::Dev

This is a set of scripts written in Ruby used to manage provisioning profiles and certificates either locally or through the Apple Developer Center (ADC).

The project also contains a few scripts related to managing the provisioning profiles in [Xcode](iOSprovisioningprofiles/tree/master/xcode/).

They are used in continuous integration environments (for example  [Jenkins](http://jenkins-ci.org)) to update, compile & validate iOS or [Unity3d](http://unity3d.com) projects.

# Required dependencies #

To manipulate provisioning profiles, you will need [plist](http://plist.rubyforge.org/Plist.html) and [json](http://flori.github.com/json/)
to access the Apple development center site, you will need [mechanize >= 2.2](http://mechanize.rubyforge.org/) and [encrypted_strings](https://github.com/pluginaweek/encrypted_strings).

# mobileprovisioning.rb #

    $ wget http://www.apple.com/appleca/AppleIncRootCertificate.cer
    $ ruby ./mobileprovisioning.rb 65RAGE----.mobileprovision -c AppleIncRootCertificate.cer -d -O plist.xml
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
    $ ruby ./mobileprovisioning.rb 65RAGE----.mobileprovision -c AppleIncRootCertificate.cer -d UUID
    A7D868EA-B1F3-4280-BD01-464653A-----
    $ ruby ./mobileprovisioning.rb 65RAGE----.mobileprovision -c AppleIncRootCertificate.cer -t
    distribution
    $ ruby ./mobileprovisioning.rb 65RAGE----.mobileprovision -c AppleIncRootCertificate.cer -d Name
    TestFlight WWTK All Projects

### apple_dev_center.rb #

	$ ./apple_dev_center.rb -u adminwwtk@wewanttoknow.com -p xxxxxxx -d devcenter -O devcenter/site.json
	$ ls devcenter/
	A7D868EA-B1F3-4280-BD01-464653A-----.mobileprovision site.json DL29------.cer
	$ prettyprint devcenter/site.json
	{
	    "certificates":[
	        {
	    	    "name":"XXXXXXXXXXXXXX",
	    	    "displayId":"DL29------",
	    	    "profile":"TestFlight XXXX All Projects",
	    	    "type":"distribution",
	    	    "status":"Issued",
	    	    "exp_date":"Jan 22, 2013"
	    	}
	    ],
	    "profiles": [
	        {
	            "name": "iOS Team Provisioning Profile: *",
	            "type": "development",
				"appid": "D7NQRK----.*",
	            "uuid": "A7D868EA-B1F3-4280-BD01-464653A-----",
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

#### Storing the password (encrypted in a configuration file)

If you don't want to have your password on the command line (so that it doesn't appear in log files), you can generate a config file.

    $ ./generate_apple_dev_center_config.rb -l yourlogin@apple.com -p YourSecretPassword -s "an optional seed key" > /path/to/config/apple_dev_center.config
    $ cat /path/to/config/apple_dev_center.config
    ---
    default: yourlogin@apple.com
    accounts:
    - login: yourlogin@apple.com
      password: l1/ChJtwxlmDnav8D4dZafRi6NOdme4Z
      teamid: ''

Then use the apple_dev_center.rb script as following:

	# To avoid having to place password information on the command line
	$ ./apple_dev_center.rb -u adminwwtk@wewanttoknow.com -c /path/to/config/apple_dev_center.config -S "an optional seed key" -d
	[...]
	# or to pick the default account and an empty secret key
	$ ./apple_dev_center.rb -C /path/to/config/apple_dev_center.config -d

#### Use a proxy ####

To use a proxy set the environment variable `https_proxy`:

    $ export https_proxy=https://proxy.yourcompany:port/
    $ env|grep https_proxy
    https_proxy=https://proxy.yourcompany:port/

#### Select a team ####
Select a team, if you are a member of multiple teams:

    # By the team id
    $ ./apple_dev_center.rb -u adminwwtk@wewanttoknow.com -p xxxxxxx -t 2xxxxxxxx6 -d devcenter -O devcenter/site.json

    # By the team name
    $ ./apple_dev_center.rb -u adminwwtk@wewanttoknow.com -p xxxxxxx -T "My development team" -d devcenter -O devcenter/site.json

Or save the team to the config file:

    # Team id
    $ ./generate_apple_dev_center_config.rb -l yourlogin@apple.com -p YourSecretPassword -t 2xxxxxxxx6 -s "an optional seed key"

    # Team name
    $ ./generate_apple_dev_center_config.rb -l yourlogin@apple.com -p YourSecretPassword -T "My development team" -s "an optional seed key"

The team id has precedence over the team name. 

The first team from the team selection is selected by default if neither team id nor team name are given.

### Use with Jenkins ###

In a CI environment, you will probably want to avoid printing out the password and use the config. I like the build secrets plugin to be able to send that to any slave.
	
Here's a useful step by step job configuration.

0. Generate your config file

		./generate_apple_dev_center_config.rb yourlogin@apple.com YourSecretPassword "an optional seed key" > your_apple_dev_center.config
		zip your_apple_dev_center.config.zip your_apple_dev_center.config

1. A build step with the build secrets plugin in which you attach to a environment variable a zip file containing your config:

    	APPLE_DEV_CENTER_CONFIG => your_apple_dev_center.config.zip

2. A shell script that creates an adc.zip file containing the site.json and related provisioning profiles:

		ls -lR $APPLE_DEV_CENTER_CONFIG
		mkdir -p adc
		rm -f adc/*
		ruby ./apple_dev_center.rb -C $APPLE_DEV_CENTER_CONFIG/your_apple_dev_center.config -S "an optional seed key" -u yourlogin@apple.com -d -O adc/site.json
		zip -r adc.zip adc/

3. [optional] Archive the artifact adc.zip, deploy it on a common place, etc.

## Technical information ##

Provisioning profiles are PKCS7 signed messages. The message itself is an XML plist. The script extracts the plist.

# TODO #

I am considering the following improvements:

  * Extract out the password storage functionality into an reusable encrypted password store for use by ruby scripts (in CI environments).
  * Package the ruby scripts into libs and a gem to ease installation and update.
  * Add some functions to upload devices or sync an externally managed list of devices onto the Apple Developer Center.

# Feedback #

Question & feedback: jerome.lacoste@gmail.com

# Links #

* https://github.com/quadion/iOSValidation where I got some tips for parsing provisioning profiles
* http://www.peerassembly.com/2011/09/30/Downloading-UDID-From-Apple/ where I got some tips for downloading data from Apple developer center
* [Xcode “Build and Archive” from command line](http://stackoverflow.com/questions/2664885/xcode-build-and-archive-from-command-line/10981634#10981634)

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
