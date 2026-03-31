#!/bin/bash
# CVE: CloudMensis [Mac]
# Checks for indicators of compromise (IOCs) related to CloudMensis malware.
# Accepts username via $username environment variable (NinjaOne), command-line
# argument, or interactive prompt.
#
# Usage:
#   ./CVE CloudMensis.sh <username>
#   username=jdoe ./CVE CloudMensis.sh
#   ./CVE CloudMensis.sh  (will prompt)

# Determine target username
username="${username:-$1}"
if [[ -z "$username" ]]; then
    if [[ -t 0 ]]; then
        read -rp "Enter the primary user's username: " username
    fi
fi

if [[ -z "$username" ]]; then
    echo "ERROR: Username is required. Pass as argument, set \$username env var, or run interactively." >&2
    exit 1
fi

echo "Checking for CloudMensis IOCs for user: $username"
echo "Expected results are 'No such file or directory'"
echo "If files are found, they are an IOC or Indicator Of Compromise"
echo

ls /Library/WebServer/share/httpd/manual/WindowServer
ls /Library/LaunchDaemons/.com.apple.WindowServer.plist
ls /users/$username/Library/Containers/com.apple.FaceTime/Data/Library/windowserver
ls /users/$username/Library/Containers/com.apple.Notes/Data/Library/.CFUserTextDecoding
ls /users/$username/Library/Containers/com.apple.languageassetd/loginwindow
ls /users/$username/Library/Application Support/com.apple.spotlight/Resources_V3/.CrashRep