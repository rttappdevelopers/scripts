#!/bin/bash
# Source: https://github.com/rtrouton/rtrouton_scripts/blob/master/rtrouton_scripts/enable_automatic_apple_software_updates/enable_automatic_apple_software_updates.sh
# modified by Jeff Pelletier for Datto RMM 8-14-2019

# Check for macOS version
osvers=$(/usr/bin/sw_vers -productVersion | awk -F. '{print $2}')

# Enable automatic download and install of system updates
# for OS X Yosemite and later.
 
plist_file="/Library/Preferences/com.apple.SoftwareUpdate.plist"

# Enable the following:
#
# Automatic background check for macOS software updates
# Automatic download of macOS software updates
# Automatic download and installation of XProtect, MRT and Gatekeeper updates
# Automatic download and installation of automatic security updates
# Automatic download and installation of App Store app updates

/usr/bin/defaults write "$plist_file" AutomaticCheckEnabled -bool $AutomaticCheckEnabled
/usr/bin/defaults write "$plist_file" AutomaticDownload -bool $AutomaticDownload
/usr/bin/defaults write "$plist_file" ConfigDataInstall -bool $ConfigDataInstall
/usr/bin/defaults write "$plist_file" CriticalUpdateInstall -bool $CriticalUpdateInstall
/usr/bin/defaults write /Library/Preferences/com.apple.commerce.plist AutoUpdate -bool $AppStore

# For macOS Mojave and later, enable the automatic installation of macOS updates.

if [[ "$osvers" -ge 14 ]]; then
	/usr/bin/defaults write "$plist_file" AutomaticallyInstallMacOSUpdates -bool $InstallMacOSUpdates
fi

# For OS X Yosemite through macOS High Sierra, enable the automatic installation
# of OS X and macOS updates.

plist_file="/Library/Preferences/com.apple.commerce.plist"

if [[ "$osvers" -ge 10 ]] && [[ "$osvers" -lt 14 ]]; then
	/usr/bin/defaults write "$plist_file" AutoUpdateRestartRequired -bool $InstallMacOSUpdates 
fi
