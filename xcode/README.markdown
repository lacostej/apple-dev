# What is this? #

This is a set of scripts written in bash used to manage provisioning profiles registered in xcode organizer and configured in xcode projects.

Here is a list of actions one can perform:

 * install or update a provisioning profile so that the xcode organizer folder is updated
 * update the selected provisioning profile in a xcode project file (.pbxproj)

Useful to automatically update configuration on CI environments when a provisioning profile has changed, e.g. when the associated device list was updated.

The scripts expects the profiles file & data information to be stored in the format created by the apple_dev_center.rb script.


# Links #

Some interesting links I've found along the way:

 - http://emilloer.com/2011/08/15/dealing-with-project-dot-pbxproj-in-ruby/
 - http://stackoverflow.com/questions/1549578/git-and-pbxproj
 - http://stackoverflow.com/questions/1452707/library-to-read-write-pbxproj-xcodeproj-files
 - http://mrox.net/blog/2008/11/16/adding-debug-only-preferences-in-iphone-applications/
 - http://prowiki.isc.upenn.edu/wiki/Manipulating_Plists