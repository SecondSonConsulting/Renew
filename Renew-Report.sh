#!/bin/bash
#set -x

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

renewLogFile="${userHomeFolder}/Library/Application Support/Renew/Renew.log"

renewUserDeferrals="${userHomeFolder}/Library/Preferences/com.secondsonconsulting.renew.user.plist"

echo "****************************************************"
echo "Deferral details for user: $currentUser"
echo "****************************************************"

if [ -f "$renewUserDeferrals" ]; then
    /usr/libexec/PlistBuddy -c "Print" "$renewUserDeferrals"
else
    echo "No user deferral file found"
fi

echo "****************************************************"
echo "$lineCount lines of Renew logs for $currentUser:"
echo "****************************************************"

if [ -f "$renewLogFile" ]; then
    tail -n $lineCount "$renewLogFile"
else
    echo "No Renew log files found"
fi

#Determine current Unix epoch time
current_unix_time="$(date '+%s')"

#This reports the unix epoch time that the kernel was booted
boot_unix_time="$(sysctl -n kern.boottime | awk -F 'sec = |, usec' '{ print $2; exit }')"

#Get uptime in seconds by doing maths
uptime_seconds="$(( current_unix_time - boot_unix_time ))"

#I'm spelling out the math in multiple steps because i'm kind of a dummy. This could be one unreadable command, but i prefer this.
uptime_minutes="$(( uptime_seconds / 60 ))"
uptime_hours="$(( uptime_minutes / 60 ))"
uptime_days="$(( uptime_hours / 24 ))"

echo "****************************************************"
if [ $uptime_days -gt 0 ]; then
    echo "Uptime is: $uptime_days days"
elif [ $uptime_hours -gt 0 ]; then
    echo "Uptime is: $uptime_hours hours"
elif [ $uptime_minutes -gt 0 ]; then
    echo "Uptime is: $uptime_minutes minutes"
else
    echo "Uptime less than 1 minute"
fi
echo "****************************************************"
