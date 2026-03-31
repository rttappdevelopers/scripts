#!/bin/bash
launchctl unload /Library/LaunchDaemons/com.webroot.security.mac.plist
kextunload /Library/Extensions/SecureAnywhere.kext
kextunload /System/Library/Extensions/SecureAnywhere.kext
rm /usr/local/bin/WSDaemon
rm /usr/local/bin/WFDaemon
killall -9 WSDaemon
killall -9 WFDaemon
killall -9 "Webroot SecureAnywhere"
rm -rf /Library/Extensions/SecureAnywhere.kext
rm -rf /System/Library/Extensions/SecureAnywhere.kext
rm -rf "/Applications/Webroot SecureAnywhere.app"
rm /Library/LaunchAgents/com.webroot.WRMacApp.plistSudo
rm /Library/LaunchDaemons/com.webroot.security.mac.plist
rm ~/Library/Preferences/com.webroot.WSA.plist
rm ~/Library/Preferences/com.webroot.Webroot-SecureAnywhere.plist
rm -rf ~/Library/Application\ Support/Webroot
rm -rf /Library/Application\ Support/Webroot
