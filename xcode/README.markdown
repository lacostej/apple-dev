# What is this? #

This is a set of scripts written in bash used to manage provisioning profiles registered in xcode organizer and configured in xcode projects.

Here is a list of actions one can perform:
* install or update a provisioning profile so that the xcode organizer folder is updated
* update the selected provisioning profile in a xcode project file (.pbxproj)

Useful to automatically update configuration on CI environments when a provisioning profile has changed, e.g. when the associated device list was updated.

The scripts expects the profiles file & data information to be stored in the format created by the apple_dev_center.rb script.

