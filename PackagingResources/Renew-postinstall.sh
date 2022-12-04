#!/bin/bash
#set -x

#Set variables for path/name
launchDPath="/Library/LaunchAgents"
launchDName="com.secondsonconsulting.renew"

#Get current user (use only if launch agent, not daemon)
currentUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ { print $3 }' )
currentUserUID=$(/usr/bin/id -u "$currentUser")

#If someone is logged in, load the job right away. Check for edge case users first.
if [ "$currentUser" = "root" ] \
	|| [ "$currentUser" = "loginwindow" ] \
	|| [ "$currentUser" = "_mbsetupuser" ] \
	|| [ -z "$currentUser" ] 
then
	exit 0
else
	#Load the launch d
	launchctl asuser "${currentUserUID}" launchctl load -w "$launchDPath"/"$launchDName".plist > /dev/null 2>&1
	launchDResult=$?
	#Uncomment below for debugging
	#echo "LaunchD Result: $launchDResult"
fi

exit "$launchDResult"