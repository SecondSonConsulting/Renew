#!/bin/zsh
#set -x

##Renew.sh
scriptVersion="Beta 0.1.8"

#Written by Trevor Sysock (aka @BigMacAdmin) at Second Son Consulting Inc.

##################################################################
#
# This section sets up the basic variables, functions, and validation
#
##################################################################

##Current user/home used to set the deferral plist
##Each user on a system will have its own deferral count and log

# Get the currently logged in user
currentUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ { print $3 }' )

# Current User home folder
userHomeFolder=$(dscl . -read /users/${currentUser} NFSHomeDirectory | cut -d " " -f 2)

#Define folder and log file name
logDir="$userHomeFolder/Library/Application Support/Renew"
logFile="$logDir"/Renew.log

#Check if the log folder exists, if not then make it. 
if [ ! -d "$logDir" ]; then
	mkdir -p "$logDir"
fi
	
#Used only for debugging. Gives feedback into standard out if dryRun=1, also to $logFile if you set it
function debug_message()
{

if [ "$dryRun" = 1 ]; then
	/bin/echo "DEBUG: $*"
fi

}

#Publish a message to the log (and also to the debug channel)
function log_message()
{

if [ -e "$logFile" ]; then
	/bin/echo "$(date): $*" >> "$logFile"
fi

if [ "$dryRun" = 1 ]; then
	debug_message "$*"
fi

}


#Path to mobileconfig payload
renewConfig="/Library/Managed Preferences/com.secondsonconsulting.renew.plist"

#Path to swiftDialog binary
dialogPath='/usr/local/bin/dialog'

#Path to Plist Buddy for convenience and readability
pBuddy='/usr/libexec/PlistBuddy'

#Path to User deferral file
userDeferralProfile="$userHomeFolder/Library/Preferences/com.secondsonconsulting.renew.user.plist"

#This is up top so that it runs even if no validation succeeds.
if [ "$1" = "--version" ]; then
	log_message "--version argument passed. Printing version information and exiting."
	echo "Renew.sh version: $scriptVersion"
	echo "SwiftDialog Version: $($dialogPath --version)"
	exit 0
fi

#Exit if there is no mobileconfig payload
if [ ! -f "$renewConfig" ]; then
	log_message "Configuration profile missing. Exiting."
	exit 0
fi

#Exit if swiftDialog dependency isn't installed
if [ ! -e "$dialogPath" ]; then
	log_message "ERROR: Missing dependency: SwiftDialog"
	exit 3
fi

#This function confirms read/write permissions to the user deferral profile
if "$pBuddy" -c "Add :TestPerms integer 0" "$userDeferralProfile" >/dev/null 2>&1; then
	"$pBuddy" -c "Delete :TestPerms" "$userDeferralProfile" >/dev/null 2>&1
else
	log_message "ERROR: Failed to properly write to $userDeferralProfile - Exiting."
	echo "ERROR: Failed to properly right to $userDeferralProfile - Exiting."
	exit 2
fi

#This is the help dialog explaining the options and how to use
help_message()
{
cat <<HELPMESSAGE
NAME
	/usr/local/Renew.sh

SYNOPSIS
	/usr/local/Renew.sh [ --reset | --dry-run | --force-aggro | --force-normal | --force-notification | --help ]
	
DESCRIPTION
	The Renew script is designed to be run on regular intervals (about every 30 minutes, typically via a Global Launch Agent).
	In normal usage, no additional arguments are required. The Options below are primarily for testing.
	
	Multiple options are not supported, only one option can be chosen at a time.

OPTIONS
	--reset					This will reset the user's deferral profile to reset the Renew experience

	--dry-run				Disables the restart/quit functionality of the "Restart" button for testing purposes.
  				  			Also ignores active deferral count and sets uptime to ensure an event is triggered.

	--force-aggro			Aggressive mode will be executed regardless of deferrals or uptime.

	--force-normal			Normal mode will be executed regardless of deferrals or uptime.

	--force-notification	Notification mode will be executed regardless of deferrals or uptime.

	--version				Print the version of Renew and Dialog and exit.
	
	--help					Print this help message and exit.

EXIT CODES
	0						Successful exit
	1						Unknown or undefined error
	2						Permissions or home folder issue
	3						SwiftDialog binary missing
	4						Invalid arguments given at command line

HELPMESSAGE

}

##################################################################
#
# This section sets the primary functions of the script
# and identifies if testing parameters were provided at commmand line
#
##################################################################

#This function resets deferrals for the logged in user.
function reset_deferral_profile ()
{

defaults delete "$userDeferralProfile" >/dev/null 2>&1

"$pBuddy" -c "Add :CurrentDeferralCount integer 0" "$userDeferralProfile" >/dev/null 2>&1
"$pBuddy" -c "Add :NotificationCount integer 0" "$userDeferralProfile" >/dev/null 2>&1
"$pBuddy" -c "Add :ActiveDeferral integer 0" "$userDeferralProfile" >/dev/null 2>&1
"$pBuddy" -c "Add :HumanReadableDeferDate string 0" "$userDeferralProfile" >/dev/null 2>&1

}

##Check for testing parameters. This section could be redone using getopts, but the purpose of this script is not to be used with arguments. Arguments are just for testing, and are limited to 1 argument each run.

if [ -n "$2" ]; then
	log_message "ERROR: Invalid arguments: $@"
	exit 4
elif [ "$1" = "--dry-run" ]; then
	log_message "--dry-run used. Device will not restart during this run."
	dryRun=1
elif  [ "$1" = "--force-aggro" ]; then
	log_message "--force-aggro used. Aggressive mode will be executed regardless of deferrals or uptime."
	forceAggro=1
elif [ "$1" = "--force-normal" ]; then
	log_message "--force-normal used. Normal mode will be executed regardless of deferrals or uptime."
	forceNormal=1
elif [ "$1" = "--force-notification" ]; then
	log_message "--force-notification used. Notification mode will be executed regardless of deferrals or uptime."
	forceNotification=1
elif [ "$1" = "--reset" ]; then
	log_message "--reset used. Resetting deferral profile and exiting."
	reset_deferral_profile
	exit 0
elif [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
	debug_message "--help used. Printing help message and exiting."
	help_message
	exit 0
elif [ "$1" = "" ]; then
	debug_message "No testing arguments passed during execution."
else
	debug_message "ERROR: Invalid arguments given. Printing help message and exiting."
	help_message
	exit 4
fi

#Ensure the user deferral file exists with valid entries
#If any of these commands fail, reset and rebuild
debug_message "Validating user deferral profile plist"
"$pBuddy" -c "Print :CurrentDeferralCount" "$userDeferralProfile" >/dev/null 2>&1 || validationFail=1
"$pBuddy" -c "Print :NotificationCount" "$userDeferralProfile" >/dev/null 2>&1 || validationFail=1
"$pBuddy" -c "Print :ActiveDeferral" "$userDeferralProfile" >/dev/null 2>&1 || validationFail=1

if [ "$validationFail" = 1 ]; then
	log_message "WARNING: User deferral profile plist FAILED validation. Resetting."
	reset_deferral_profile
else
	debug_message "User deferral profile plist validated successfully"
fi

#This function validates whether a preference option exists in the configuration file or not
#If the required preference value doesn't exist, exit
function validate_required_argument()
{

"$pBuddy" -c "Print $1" "$renewConfig" >/dev/null 2>&1  \
	&& debug_message "Required Argument found: $1" \
	|| { log_message "ERROR: Required Argument missing: $1" ; exit 2 ; }

}

#Perform validation of Required Arguments. Script exits if required arguments are missing.
validate_required_argument ":RequiredArguments:UptimeThreshold"
validate_required_argument ":RequiredArguments:MaximumDeferrals"
validate_required_argument ":RequiredArguments:DeferralDuration"
validate_required_argument ":RequiredArguments:NotificationThreshold"

#Setting variables based on mobileconfig profile - RequiredArguments
uptimeThreshold=$("$pBuddy" -c "Print :RequiredArguments:UptimeThreshold" "$renewConfig")
maximumDeferrals=$("$pBuddy" -c "Print :RequiredArguments:MaximumDeferrals" "$renewConfig")
deferralDuration=$("$pBuddy" -c "Print :RequiredArguments:DeferralDuration" "$renewConfig")
notificationThreshold=$("$pBuddy" -c "Print :RequiredArguments:NotificationThreshold" "$renewConfig")

#Check if there is a deferral count already, and set it to 0 or current value.
currentDeferralCount=$("$pBuddy" -c "Print :CurrentDeferralCount" "$userDeferralProfile" 2>/dev/null)

#Check if there is a value for an active deferral
activeDeferral=$("$pBuddy" -c "Print :ActiveDeferral" "$userDeferralProfile" 2>/dev/null)

#Set value for how many notifications have been completed
notificationCount=$("$pBuddy" -c "Print :NotificationCount" "$userDeferralProfile")

#Do math to determine remaining deferrals
deferralsRemaining=$((maximumDeferrals-currentDeferralCount))

#Setting variables based on mobileconfig profile - OptionalArguments
#If no argument is given in the config file, set the script default
defaultDialogAdditionalOptions=""
defaultDialogAggressiveOptions=""
defaultSecretQuitKey="]"
defaultDialogIcon="SF=bolt.circle color1=pink color2=blue"
defaultNotificationIcon=""

#Language Support starts here. There is probably a cleaner way to get this.
#Get an array containing all selected languages
languagesArray=( $(defaults read .GlobalPreferences AppleLanguages ) )

#Array entry 1 is a parenthesis and entry 2 is the language. Grab just the first two characters of the 2nd entry in the array
languageChoice=${languagesArray[2]:1:2}

#languageChoice="en"
#languageChoice="fr"

debug_message "Language identified: $languageChoice"

#To add additional language support, create a case statement for the 2 letter language prefix
#For example: "en" for english or "es" for espaniol
#Then enter the desired text for those strings.

case "$languageChoice" in
    en)
        #Define script default messaging ENGLISH
		defaultDialogTitle="Please Restart"
		defaultDialogNormalMessage="In order to keep your system healthy and secure it needs to be restarted.  \n**Please save your work** and restart as soon as possible.\n\nDeferrals remaining until required restart:  "
		defaultDialogAggroMessage="**Please save your work and restart**"
		defaultDialogNotificationMessage="In order to keep your system healthy and secure it needs to be restarted.  \nPlease save your work and restart as soon as possible."
		defaultRestartButtonText="OK, Restart Now I am Ready"
		defaultDeferralButtonText="Not now, remind me later..."
		defaultNoDeferralsRemainingButtonText="No deferrals remaining"
    ;;
	   fr)
       #Define script default messaging FRENCH
       #Credit and thanks to Martin Cech (@martinc on MacAdmins Slack)
       defaultDialogTitle="Veuillez redemarrer"
       defaultDialogNormalMessage="Afin de garder votre système sain et sécurisé, il doit être redémarré.  \n**Veuillez enregistrer votre travail** et redemarrer dès que possible.\n\nReports restants jusqu'au redémarrage requis:  "
       defaultDialogAggroMessage="**Veuillez enregistrer votre travail et redémarrer**"
       defaultDialogNotificationMessage="Afin de garder votre système sain et sécurisé, il doit être redémarré.  \nVeuillez enregistrer votre travail et redémarrer dès que possible."
       defaultRestartButtonText="OK, Redémarrez maintenant je suis prêt"
       defaultDeferralButtonText="Pas maintenant, rappelle-moi plus tard..."
       defaultNoDeferralsRemainingButtonText="Aucun report restant"
   ;;
    *)
		#Define script default messaging ENGLISH
		defaultDialogTitle="Please Restart"
		defaultDialogNormalMessage="In order to keep your system healthy and secure it needs to be restarted.  \n**Please save your work** and restart as soon as possible."
		defaultDialogAggroMessage="**Please save your work and restart**"
		defaultDialogNotificationMessage="In order to keep your system healthy and secure it needs to be restarted.  \nPlease save your work and restart as soon as possible."

    ;;
esac

#Now do the logic to set the variables that will actually be used
#This is tedious code that could be simplified with a function, but i couldn't get my brain around it
#How do you set a variable to have the name of a argument you pass to a function? Need someone smarter than me.

if "$pBuddy" -c "Print :OptionalArguments:MessageIcon" "$renewConfig" >/dev/null 2>&1 ; then
	dialogIcon=$("$pBuddy" -c "Print :OptionalArguments:MessageIcon" "$renewConfig")
	#If an icon is defined, but the file doesnt exist, fall back to default.
	if [ ! -e "$dialogIcon" ]; then
		dialogIcon="$defaultDialogIcon"
	fi	
else
	dialogIcon="$defaultDialogIcon"
fi

if "$pBuddy" -c "Print :OptionalArguments:NotificationIcon" "$renewConfig" >/dev/null 2>&1 ; then
	notificationIcon=$("$pBuddy" -c "Print :OptionalArguments:NotificationIcon" "$renewConfig")
	#If an icon is defined, but the file doesnt exist, fall back to default.
	if [ ! -e "$notificationIcon" ]; then
		notificationIcon="$defaultNotificationIcon"
	fi	
else
	notificationIcon="$defaultNotificationIcon"
fi

if "$pBuddy" -c "Print :OptionalArguments:NormalMessage" "$renewConfig" >/dev/null 2>&1 ; then
	dialogNormalMessage=$("$pBuddy" -c "Print :OptionalArguments:NormalMessage" "$renewConfig")
else
	dialogNormalMessage="$defaultDialogNormalMessage"
fi

if "$pBuddy" -c "Print :OptionalArguments:AggroMessage" "$renewConfig" >/dev/null 2>&1 ; then
	dialogAggroMessage=$("$pBuddy" -c "Print :OptionalArguments:AggroMessage" "$renewConfig")
else
	dialogAggroMessage="$defaultDialogAggroMessage"
fi

if "$pBuddy" -c "Print :OptionalArguments:NotificationMessage" "$renewConfig" >/dev/null 2>&1 ; then
	dialogNotificationMessage=$("$pBuddy" -c "Print :OptionalArguments:NotificationMessage" "$renewConfig")
else
	dialogNotificationMessage="$defaultDialogNotificationMessage"
fi

if "$pBuddy" -c "Print :OptionalArguments:Title" "$renewConfig" >/dev/null 2>&1 ; then
	dialogTitle=$("$pBuddy" -c "Print :OptionalArguments:Title" "$renewConfig")
else
	dialogTitle="$defaultDialogTitle"
fi

if "$pBuddy" -c "Print :OptionalArguments:RestartButtonText" "$renewConfig" >/dev/null 2>&1 ; then
	dialogRestartButtonText=$("$pBuddy" -c "Print :OptionalArguments:RestartButtonText" "$renewConfig")
else
	dialogRestartButtonText="$defaultRestartButtonText"
fi

if "$pBuddy" -c "Print :OptionalArguments:DeferralButtonText" "$renewConfig" >/dev/null 2>&1 ; then
	dialogDeferralButtonText=$("$pBuddy" -c "Print :OptionalArguments:DeferralButtonText" "$renewConfig")
else
	dialogDeferralButtonText="$defaultDeferralButtonText"
fi

if "$pBuddy" -c "Print :OptionalArguments:NoDeferralsRemainingButtonText" "$renewConfig" >/dev/null 2>&1 ; then
	dialogNoDeferralsRemainingButtonText=$("$pBuddy" -c "Print :OptionalArguments:NoDeferralsRemainingButtonText" "$renewConfig")
else
	dialogNoDeferralsRemainingButtonText="$defaultNoDeferralsRemainingButtonText"
fi

if "$pBuddy" -c "Print :OptionalArguments:AdditionalDialogOptions" "$renewConfig" >/dev/null 2>&1 ; then
	dialogAdditionalOptions=$("$pBuddy" -c "Print :OptionalArguments:AdditionalDialogOptions" "$renewConfig")
else
	dialogAdditionalOptions="$defaultDialogAdditionalOptions"
fi

if "$pBuddy" -c "Print :OptionalArguments:AdditionalAggressiveOptions" "$renewConfig" >/dev/null 2>&1 ; then
	dialogAggressiveOptions=$("$pBuddy" -c "Print :OptionalArguments:AdditionalAggressiveOptions" "$renewConfig")
else
	dialogAggressiveOptions="$defaultDialogAggressiveOptions"
fi

if "$pBuddy" -c "Print :OptionalArguments:SecretQuitKey" "$renewConfig" >/dev/null 2>&1 ; then
	secretQuitKey=$("$pBuddy" -c "Print :OptionalArguments:SecretQuitKey" "$renewConfig")
else
	secretQuitKey="$defaultSecretQuitKey"
fi

#Define what happens when Aggressive mode is engaged
function exec_aggro_mode()
{

log_message "Executing aggressive mode"

#go aggro

	"$dialogPath" -o \
	--title "$dialogTitle" \
	--button1text "$dialogNoDeferralsRemainingButtonText" \
	--button1disabled \
	--infobuttontext "$dialogRestartButtonText" \
	--icon "$dialogIcon" \
	--messagealignment centre \
	--centericon \
	--messagealignment center \
	--quitkey "$secretQuitKey" \
	$(echo $dialogAdditionalOptions) \
	$(echo $dialogAggressiveOptions) \
	--message "$dialogAggroMessage" \
	
	#Set exit code based on user input
	dialogExitCode=$?
	
}

#Define what happens when  Normal mode is engaged
function exec_normal_mode()

{

log_message "Executing normal mode"


#go normal
	
	"$dialogPath" -o \
	--title "$dialogTitle" \
	--infobuttontext "$dialogRestartButtonText" \
	--button1text "$dialogDeferralButtonText" \
	--centericon \
	--icon "$dialogIcon" \
	--messagealignment centre \
	--quitkey "$secretQuitKey" \
	$(echo $dialogAdditionalOptions) \
	--message "$dialogNormalMessage $deferralsRemaining" \

	#Set exit code based on user input
	dialogExitCode=$?

}

#Define what happens when Notification mode is engaged
function exec_notification_mode()
{

log_message "Executing notification mode"

#go notification

	"$dialogPath" \
	--notification \
	--title "$dialogTitle" \
	--icon "$notificationIcon" \
	--message "$dialogNotificationMessage" \
	
	((notificationCount=notificationCount+1))
	"$pBuddy" -c "Set :NotificationCount $notificationCount" "$userDeferralProfile"
	
	exec_deferral
	
	exit 0
}

#This function adds to the deferral count and sets an active deferral time
function exec_deferral()
{
	log_message "Executing deferral process."
	((currentDeferralCount=currentDeferralCount+1))
	log_message "New current deferral count: $currentDeferralCount"
	"$pBuddy" -c "Set :CurrentDeferralCount $currentDeferralCount" "$userDeferralProfile"
	log_message "New defer until value: $deferUntil"
	"$pBuddy" -c "Set :ActiveDeferral $deferUntil" "$userDeferralProfile"
	log_message "New human readabale deferral date: $humanReadableDeferDate"
	"$pBuddy" -c "Set :HumanReadableDeferDate $humanReadableDeferDate" "$userDeferralProfile"
}

#If the --dry-run flag is passed as a script argument for testing, then the reboot button doesn't actually reboot
if [ "$dryRun" = 1 ]; then

function exec_restart()
{
	log_message "DRY-RUN: Restart would happen here"
	exit 0
}

else

#This is the proper reboot function, thanks to: @Charles Mangin in Mac Admins slack (who in turns gave thanks to https://community.jamf.com/t5/user/viewprofilepage/user-id/73522 )
function exec_restart()
{

log_message "Executing restart!"

#This is the restart command. Thank you Dan Snelson: https://snelson.us/2022/07/log-out-restart-shut-down/

osascript -e 'tell app "loginwindow" to «event aevtrrst»'

}

fi

##################################################################
#
# This section does maths
#
##################################################################

###Big thanks to Pico on the Mac Admins slack for the logic on the time variables.
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

debug_message "Uptime values are: $uptime_days days = $uptime_hours hours = $uptime_minutes minutes = $uptime_seconds seconds"

deferUntilSeconds=$((deferralDuration * 60 * 60 - 300))
deferUntil=$((current_unix_time+deferUntilSeconds))

debug_message "Defer Until: "$deferUntil" which is $(date -j -f %s $deferUntil)"
humanReadableDeferDate=$(date -j -f %s $deferUntil)

##################################################################
#
# This section processes command line arguments used for testing
#
##################################################################

#To reset deferrals, execute sript with /Renew.sh --reset
if [ "$1" = "--reset" ]; then
		reset_deferral_profile && log_message "Resetting deferrals." || { log_message "ERROR: Could not reset deferral profile. Probably a permissions issue." ; exit 2 ; }
	exit 0
fi

#If dryRun is enabled, set uptime days to a value that is sure to trip your policy
if [ "$dryRun" = 1 ]; then
	uptime_days=$(( uptimeThreshold+1 ))
	activeDeferral=0
	debug_message "DRY-RUN: Setting uptime_days to $uptime_days value for testing purposes."
fi

#Check if we're forcing aggro for testing
if [ "$forceAggro" = 1 ]; then
	uptime_days=$(( uptimeThreshold+1 ))
	currentDeferralCount=$(( maximumDeferrals+1 ))
	activeDeferral=0
	notificationCount=$((notificationThreshold+1))
	debug_message "FORCE-AGGRO: Setting uptime_days to $uptime_days value for testing purposes."
fi

#Check if we're forcing normal for testing
if [ "$forceNormal" = 1 ]; then
	uptime_days=$(( uptimeThreshold+1 ))
	activeDeferral=0
	notificationCount=$((notificationThreshold+1))
	currentDeferralCount=0
	debug_message "FORCE-NORMAL: Setting uptime_days to $uptime_days value for testing purposes."
fi

#Check if we're forcing normal for testing
if [ "$forceNotification" = 1 ]; then
	activeDeferral=0
	debug_message "FORCE-NOTIFICAION: Setting activeDeferral to $activeDeferral for testing purposes."
	exec_notification_mode
fi

##################################################################
#
# This section has the primary logic that dictates the user experience
#
##################################################################
#Test if we can write to the log file
echo "$(date): Renew - Executing logic" >> "$logFile" || { echo "ERROR: Cannot write to log file. Exiting" ; exit 2 ; }

#Are we in a deferral time range? If so, exit quietly.
if [ $activeDeferral -ge $current_unix_time ]; then
	log_message "A deferral is active. Exiting."
	exit 0
fi

#First check if the uptime necessitates action. If not, reset all deferrals and exit 0.
if [ "$uptime_days" -ge "$uptimeThreshold" ]; then
	#First check if the user has received the desired number of notifications, and if not execute notification mode.
	if [ "$notificationCount" -lt "$notificationThreshold" ]; then
		debug_message "Notification count has not met notification threshold."
		exec_notification_mode
	fi
	
	if [ "$currentDeferralCount" -ge "$maximumDeferrals" ]; then
		debug_message "Aggressive mode conditions met."
		exec_aggro_mode
	else
		debug_message "Normal mode conditions met."
		exec_normal_mode
	fi
	
	#User has made a selection. Now we process it.
	debug_message "DIALOG EXIT CODE: $dialgoExitCode."

	
	if [[ "$dialogExitCode" = 0 ]]; then
		log_message "USER ACTION: User chose deferral."
		exec_deferral
	elif [[ "$dialogExitCode" = 10 ]]; then
		log_message "USER ACTION: User pressed the secret quit button."
		exit $dialogExitCode
	elif [[ "$dialogExitCode" = 3 ]]; then
		log_message "USER ACTION: User chose to restart now."
		exec_restart
	else
		log_message "USER ACTION: Dialog exited with an unexpected code. Possibly it was killed unexpectedly."
		exit $dialogExitCode
	fi
else
	#No enforcement needed, so we set deferrals to zero
	log_message "Device does not need to be restarted."
	reset_deferral_profile
fi

exit 0
