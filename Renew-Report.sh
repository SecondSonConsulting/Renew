#!/bin/bash

# Renew Report v1.0
# Trevor Sysock aka Big Mac Admin

# This script is meant to be run from a management tool.
# It will report information regarding active deferrals 
# and will read the last X lines of the Renew log for the 
# currently logged in user.

# Set the number of lines you want to read from the log. 10 should be sufficient for testing
lineCount='10'

# Get the currently logged in user
currentUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ { print $3 }' )

# Current User home folder
userHomeFolder=$(dscl . -read /users/${currentUser} NFSHomeDirectory | cut -d " " -f 2)

renewLogFile="$userHomeFolder"/Library/"Application Support"/Renew/Renew.log

renewUserDeferrals="$userHomeFolder"/Library/Preferences/com.secondsonconsulting.renew.user.plist

echo "Reading details for user: $currentUser"

if [ -f "$renewUserDeferrals" ]; then
    /usr/libexec/PlistBuddy -c "Print" "$renewUserDeferrals"
else
    echo "No user deferral file found"
fi

echo ""
echo "****************************************************"
echo ""

if [ -f "$renewLogFile" ]; then
    tail -n $lineCount "$renewLogFile"
else
    echo "No Renew log files found"
fi
