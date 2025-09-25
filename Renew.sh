#!/bin/zsh
#set -x
# shellcheck shell=bash

## Renew.sh
scriptVersion="1.5"

# Written by Trevor Sysock (aka @BigMacAdmin) at Second Son Consulting Inc.
# 
# With Contributions by:
# 	@drtaru
#	@aschwanb

# Language Contributions by:
#	@martinc
#	@ConstantinLorenz
#	@toni-boettcher
#	@devliegereM
#
#	And others in the Mac Admins community

# MIT License
#
# Copyright (c) 2024 Second Son Consulting
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

#####################
#	Prerequisites	#
#####################
# This is the help dialog explaining the options and how to use
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
							Also disables notification action button.

	--force-aggro			Aggressive mode will be executed regardless of deferrals or uptime.

	--force-normal			Normal mode will be executed regardless of deferrals or uptime.

	--force-notification	Notification mode will be executed regardless of deferrals or uptime.

	--version				Print the version of Renew and Dialog and exit.

	--verbose				Enable verbose mode for debugging.

	--configuration <path>	Load a custom configuration plist (not mobileconfig) file from the specified path.

	--print-configuration	Display the active configuration and exit.

	--defer <minutes>		Force a deferral for the specified number of minutes. This will reset the deferral profile.

	--deadline <days>		Set the deadline for the restart to the specified number of days.

	--language <language>	Set the language for the dialog. This will override the system language.
	
	--help					Print this help message and exit.

TESTING TIPS
	Use the secret quit key to exit the dialog without restarting. The default is "Command ]".
	
EXIT CODES
	0						Successful exit
	1						Unknown or undefined error
	2						Permissions or home folder issue
	3						SwiftDialog binary missing
	4						Invalid arguments given at command line
	5						Script executed as root
	*						Other undefined exit codes are most likely passed from SwiftDialog exiting improperly

HELPMESSAGE

}

# Check if we're running in verbose mode
if echo "$@" | grep -q '\-\-verbose'; then
	set -x
fi

# This is up top so that it runs even if no validation succeeds.
if echo "$@" | grep -q '\-\-version'; then
	echo "$scriptVersion"
	exit 0
fi

# Check we are NOT running as root
if [[ $(id -u) = 0 ]]; then
  echo "ERROR: This script should never be run as root **EXITING**"
  exit 5
fi

#############
#	Tools	#
#############

# Path to swiftDialog binary
dialogPath='/usr/local/bin/dialog'

# Path to Plist Buddy for convenience and readability
pBuddy='/usr/libexec/PlistBuddy'

#############################
#	Home Folder/Log Setup	#
#############################

## Current user/home used to set the deferral plist
## Each user on a system will have its own deferral count and log

# Get the currently logged in user
currentUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ { print $3 }' )

# Current User home folder
userHomeFolder=$(dscl . -read /users/${currentUser} NFSHomeDirectory | cut -d " " -f 2)

# Path to User deferral file
userDeferralProfile="$userHomeFolder/Library/Preferences/com.secondsonconsulting.renew.user.plist"

# Define folder and log file name
logDir="$userHomeFolder/Library/Application Support/Renew"
logFile="$logDir"/Renew.log

# These messages will only be see in verbose mode
function debug_message()
{
	/bin/echo "DEBUG: $*" > /dev/null 2>&1
}

# Publish a message to the log (and also to the debug channel)
function log_message(){
    echo "$(date): $*" | tee >( cat >> "$logFile" ) 
}

# Check if the log folder exists, if not then make it. 
if [ ! -d "$logDir" ]; then
	mkdir -p "$logDir"
fi

# Create the log file if its missing
touch "$logFile"

# If the log file is over 3k lines, make a new log file. We keep one old version and write over the top of it when rotating
logLength=$(wc -l < "$logFile" | xargs)
if [ "$logLength" -ge 3000 ]; then
	debug_message "Rotating Logs"
	mv "$logFile" "${logDir}/old_Renew.log"
	touch "$logFile"
	log_message "Logfile Rotated"
fi

# Check that we can write to the log
echo "$(date): Renew Initiated" >> "$logFile" || { echo "ERROR: Cannot write to log file. Exiting" ; exit 2 ; }

# Exit if swiftDialog dependency isn't installed
if [ ! -e "$dialogPath" ]; then
	log_message "ERROR: Missing dependency: SwiftDialog"
	exit 3
fi

# Confirm read/write permissions to the user deferral profile
if "$pBuddy" -c "Add :TestPerms integer 0" "$userDeferralProfile" >/dev/null 2>&1; then
	"$pBuddy" -c "Delete :TestPerms" "$userDeferralProfile" >/dev/null 2>&1
else
	log_message "ERROR: Failed to properly write to $userDeferralProfile - Exiting."
	exit 2
fi

# This function resets deferrals for the logged in user.
function reset_deferral_profile ()
{

defaults delete "$userDeferralProfile" >/dev/null 2>&1

"$pBuddy" -c "Add :CurrentDeferralCount integer 0" "$userDeferralProfile" >/dev/null 2>&1
"$pBuddy" -c "Add :NotificationCount integer 0" "$userDeferralProfile" >/dev/null 2>&1
"$pBuddy" -c "Add :ActiveDeferral integer 0" "$userDeferralProfile" >/dev/null 2>&1
"$pBuddy" -c "Add :HumanReadableDeferDate string 0" "$userDeferralProfile" >/dev/null 2>&1

}

#####################################
#	Process Command Line Arguments	#
#####################################

while [ -n "${1}" ]; do
	case "${1}" in
		--help|-h)
			help_message
			exit 0
		;;
		--verbose|-v)
			set -x
		;;
		--configuration)
			customConfig="${2}"
			shift
		;;
		--reset)
			log_message "--reset used. Resetting deferral profile and exiting."
			reset_deferral_profile
			exit 0
		;;
		--dryrun|--dry-run)
			log_message "Dry-Run mode enabled"
			dryRun=1
		;;
		--force-normal)
			log_message "Force Normal Mode Enabled"
			forceNormal=1
		;;
		--force-aggro)
			log_message "Force Aggressive Mode Enabled"
			forceAggro=1
		;;
		--force-notification)
			log_message "Force notification Mode Enabled"
			forceNotification=1
		;;
		--deadline)
			log_message "Setting Deadline from argument: $2"
			deadlineFromArgument="$2"
			shift
		;;
		--language)
			log_message "Setting language from argument: $2"
			languageFromArgument="${2}"
			shift
		;;
		--defer)
			log_message "Deferral from command line argument: $2 minutes"
			forceDeferralMinutes="$2"
			forceDeferral=$((forceDeferralMinutes*60))
			reset_deferral_profile
			shift
		;;
		--print-configuration|--print)
			printConfigMode=1
		;;
		*)
			log_message "ERROR: Unknown Argument ${1}"
			exit 255
		;;
	esac
	shift
done

# Path to mobileconfig payload
managedConfig="/Library/Managed Preferences/com.secondsonconsulting.renew.plist"
localConfig="/Library/Preferences/com.secondsonconsulting.renew.plist"

# Prioritization of Configuration files: Custom (provided at command line), Managed (mdm config profile), Local (plist in /Library/Preferences)
if [ -n "$customConfig" ]; then
	renewConfig="$customConfig"
elif [ -f "$managedConfig" ]; then
    renewConfig="$managedConfig"
else
    renewConfig="$localConfig"
fi

# Exit if there is no mobileconfig payload
if [ ! -f "$renewConfig" ]; then
	log_message "Configuration profile not found: $renewConfig"
	exit 0
fi

if [ "$printConfigMode" = 1 ]; then
	log_message "Printing Renew configuration and exiting."
	"$pBuddy" -c "Print" "$renewConfig"
	exit 0
fi

# Ensure the user deferral file exists with valid entries
# If any of these commands fail, reset and rebuild
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

# This function validates whether a preference option exists in the configuration file or not
# If the required preference value doesn't exist, exit
function validate_required_argument()
{

if ! "$pBuddy" -c "Print $1" "$renewConfig" >/dev/null 2>&1 ;then
	log_message "ERROR: Required Argument missing: $1" 
	exit 2
fi

}

#################################
#	Process Required Arguments	#
#################################

# Perform validation of Required Arguments. Script exits if required arguments are missing.
validate_required_argument ":RequiredArguments:UptimeThreshold"
validate_required_argument ":RequiredArguments:MaximumDeferrals"
validate_required_argument ":RequiredArguments:DeferralDuration"
validate_required_argument ":RequiredArguments:NotificationThreshold"

# Setting variables based on mobileconfig profile - RequiredArguments
uptimeThreshold=$("$pBuddy" -c "Print :RequiredArguments:UptimeThreshold" "$renewConfig")
maximumDeferrals=$("$pBuddy" -c "Print :RequiredArguments:MaximumDeferrals" "$renewConfig")
deferralDuration=$("$pBuddy" -c "Print :RequiredArguments:DeferralDuration" "$renewConfig")
notificationThreshold=$("$pBuddy" -c "Print :RequiredArguments:NotificationThreshold" "$renewConfig")

# Check if there is a deferral count already, and set it to 0 or current value.
currentDeferralCount=$("$pBuddy" -c "Print :CurrentDeferralCount" "$userDeferralProfile" 2>/dev/null)

# Check if there is a value for an active deferral
activeDeferral=$("$pBuddy" -c "Print :ActiveDeferral" "$userDeferralProfile" 2>/dev/null)

# Set value for how many notifications have been completed
notificationCount=$("$pBuddy" -c "Print :NotificationCount" "$userDeferralProfile")

# Do math to determine remaining deferrals
deferralsRemaining=$((maximumDeferrals-currentDeferralCount))

# Setting arrays based on mobileconfig profile - OptionalArguments
# If no argument is given in the config file, set the script default

# Initialize arrays
typeset -a defaultDialogAdditionalOptions=()
typeset -a defaultDialogAggressiveOptions=()
typeset -a defaultDialogNormalOptions=()
typeset -a defaultDialogNotificationOptions=()
typeset -a defaultSubtitleOptions=()
typeset -a dialogAdditionalOptions=()
typeset -a dialogNormalOptions=()
typeset -a dialogAggressiveOptions=()
typeset -a dialogNotificationOptions=()
defaultSecretQuitKey="]"
defaultNotificationIcon=""

#########################
#	Language Support	#
#########################

# Language Support starts here.
# Get an array containing all selected languages
languagesArray=( $(defaults read .GlobalPreferences AppleLanguages ) )

# Array entry 1 is a parenthesis and entry 2 is the language. Grab just the first two characters of the 2nd entry in the array
languageChoice=${languagesArray[2]:1:2}

debug_message "Language identified: $languageChoice"

# Configure language from argument
if [ -n "$languageFromArgument" ]; then
	log_message "Automatic language detection found $languageChoice. Changing to language from argument: $languageFromArgument"
	languageChoice="$languageFromArgument"
fi

#To add additional language support, create a case statement for the 2 letter language prefix
#For example: "en" for english or "es" for espaniol
#Then enter the desired text for those strings.

case "$languageChoice" in
	fr)
		#Define script default messaging FRENCH
		defaultDialogTitle="Veuillez redemarrer"
		defaultDialogNormalMessage="Afin de garder votre système sain et sécurisé, il doit être redémarré.  \n**Veuillez enregistrer votre travail** et redemarrer dès que possible."
		defaultDialogAggroMessage="**Veuillez enregistrer votre travail et redémarrer**"
		defaultDialogNotificationMessage="Afin de garder votre système sain et sécurisé, il doit être redémarré.  \nVeuillez enregistrer votre travail et redémarrer dès que possible."
		defaultRestartButtonText="OK, Redémarrez maintenant je suis prêt"
		defaultDeferralButtonText="Pas maintenant, rappelle-moi plus tard..."
		defaultNoDeferralsRemainingButtonText="Aucun report restant"
		defaultDeferralMessage="Reports restants jusqu'au redémarrage requis:  "
   ;;
   es)
		#Define script default messaging ESPANIOL
		defaultDialogTitle="Por favor reinicie"
		defaultDialogNormalMessage="Para mantener su sistema seguro y funcionando, necesitamos que reinicie.  \n**Por favor guarda tus archivos** y reinicia lo antes posible."
		defaultDialogAggroMessage="**Guarde su trabajo y reinicie por favor**"
		defaultDialogNotificationMessage="Para mantener su sistema seguro y funcionando, necesitamos que reinicie.  \nPor favor guarda tus archivos ."
		defaultRestartButtonText="OK vale, reinicie ahora, estoy listo"
		defaultDeferralButtonText="Ahora no, recuérdamelo mas tarde"
		defaultNoDeferralsRemainingButtonText="No deferrals remaining"
		defaultDeferralMessage="Deferrals remaining until required restart: "
  ;;
   it)
		#Define script default messaging ITALIANO
		defaultDialogTitle="Per favore riavvia"
		defaultDialogNormalMessage="Per mantenere il tuo sistema sicuro & performante, necessitiamo un riavvio.  \n**Per favore salva i tuoi lavori** e riavvia il prima possibile."
		defaultDialogAggroMessage="**Salva i tuoi lavori e gentilmente riavvia**"
		defaultDialogNotificationMessage="Per mantenere il tuo sistema sicuro & performante, necessitiamo un riavvio.  \nPer favore salva i tuoi lavori e riavvia il prima possibile."
		defaultRestartButtonText="OK, Riavvia ora, sono pronto"
		defaultDeferralButtonText="Not ora ricordamelo più’ tardi"
		defaultNoDeferralsRemainingButtonText="No deferrals remaining"
		defaultDeferralMessage="Deferrals remaining until required restart: "
   ;;
   de)
		#Define script default messaging DEUTSCH
		defaultDialogTitle="Bitte führe einen Neustart durch"
		defaultDialogNormalMessage="Um die Stabilität und Sicherheit deines Systems zu gewährleisten, ist ein Neustart erforderlich. \n**Bitte speichere deine Arbeit ab ** und starte deinen Computer sobald wie möglich neu."
		defaultDialogAggroMessage="**Bitte speichere deine Arbeit ab und starte neu**"
		defaultDialogNotificationMessage="Um die Stabilität und Sicherheit deines Systems zu gewährleisten, ist ein Neustart erforderlich. \nBitte speichere deine Arbeit ab und starte deinen Computer sobald wie möglich neu. "
		defaultRestartButtonText="OK, ich bin fertig, bitte neustarten"
		defaultDeferralButtonText="Nicht jetzt, erinnere mich später"
		defaultNoDeferralsRemainingButtonText="Keine weitere Aufschiebung möglich"
		defaultDeferralMessage="Deferrals remaining until required restart: "
   ;;
   nb)
		#Define script default messaging NORSK
		defaultDialogTitle="Vennligst restart din Mac"
		defaultDialogNormalMessage="For å holde systemet ditt ved like og sikkert, må det startes på nytt.  \n**Vennligst lagre arbeidet ditt** og start på nytt så snart som mulig."
		defaultDialogAggroMessage="**Vennligst lagre arbeidet ditt og start på nytt**"
		defaultDialogNotificationMessage="For å holde systemet ditt ved like og sikkert, må det startes på nytt.  \nVennligst lagre arbeidet ditt og start på nytt så snart som mulig."
		defaultRestartButtonText="OK, start på nytt nå."
		defaultDeferralButtonText="Ikke nå, minne meg på det senere..."
		defaultNoDeferralsRemainingButtonText="Ikke mulig å utsette"
		defaultDeferralMessage="Antall mulige utsettelser før påkrevd omstart: "
    ;;
	nl)
		defaultDialogTitle="Opnieuw opstarten a.u.b."
		defaultDialogNormalMessage="Om uw systeem gezond en veilig te houden moet het opnieuw worden opgestart.  \n **Sla uw werk op** en start zo snel mogelijk opnieuw op."
		defaultDialogAggroMessage="**Sla uw werk op en start opnieuw op**"
		defaultDialogNotificationMessage="Om uw systeem gezond en veilig te houden moet het opnieuw worden opgestart.  \nSla uw werk op en start zo snel mogelijk opnieuw op."
		defaultRestartButtonText="OK, herstart nu ik klaar ben".
		defaultDeferralButtonText="Niet nu, herinner me er later aan..."
		defaultNoDeferralsRemainingButtonText="Geen uitstel meer".
		defaultDeferralMessage="Resterende uitstellen tot vereiste herstart: "
	;;
	*)
		##English is the default and fallback language

		#Define script default messaging ENGLISH
		defaultDialogTitle="Please Restart"
		defaultDialogNormalMessage="In order to keep your system healthy and secure it needs to be restarted.  \n**Please save your work** and restart as soon as possible."
		defaultDialogAggroMessage="**Please save your work and restart**"
		defaultDialogNotificationMessage="In order to keep your system healthy and secure it needs to be restarted.  \nPlease save your work and restart as soon as possible."
		defaultRestartButtonText="OK, Restart Now I am Ready"
		defaultDeferralButtonText="Not now, remind me later..."
		defaultNoDeferralsRemainingButtonText="No deferrals remaining"
		defaultDeferralMessage="Deferrals remaining until required restart: "
    ;;
esac

#################################
#	Process Optional Arguments	#
#################################

##Icon setup and Dark Mode Detection
#Test whether DarkMode is enabled, and set darkMode variable accordingly
$(defaults read -g AppleInterfaceStyle  > /dev/null 2>&1 | grep -q "Dark" ) && darkMode="enabled" || darkMode="disabled"

##Make sure $dialogIcon is an empty value, then the logic is:
#if an icon is defined, but no dark mode is defined, use it whether dark mode is enabled or not
#if an icon is defined AND a dark mode icon is defined, then use the appropriate one
#If no icon is defined, set to the script default value
dialogIcon=''

#If a MessageIcon is defined in the configuration profile, set our variable to use it.
if "$pBuddy" -c "Print :OptionalArguments:MessageIcon" "$renewConfig" >/dev/null 2>&1 ; then
	dialogIcon=$("$pBuddy" -c "Print :OptionalArguments:MessageIcon" "$renewConfig")
fi

#If Dark mode is enabled and a MessageIconDarkMode is defined in the configuration profile, set our variable to use it.
if [ "$darkMode" = "enabled" ] && "$pBuddy" -c "Print :OptionalArguments:MessageIconDarkMode" "$renewConfig" >/dev/null 2>&1 ; then
	dialogIcon=$("$pBuddy" -c "Print :OptionalArguments:MessageIconDarkMode" "$renewConfig")
fi

if [ -z "$dialogIcon" ]; then
	dialogIcon="SF=restart.circle color1=pink color2=blue"
fi

#Now do the same thing for a Banner image. We need some extra tidbits to just not include the --bannerimage flag at all if it isn't defined in the config
#Define the banner image variable as empty
bannerImage=''

#If there is a banner icon defined in the configuration file, set it.
if "$pBuddy" -c "Print :OptionalArguments:BannerImage" "$renewConfig" >/dev/null 2>&1 ; then
	bannerImage=$("$pBuddy" -c "Print :OptionalArguments:BannerImage" "$renewConfig")
fi

#If Dark mode is enabled and a BannerImageDarkMode is defined in the configuration profile, set our variable to use it.
if [ "$darkMode" = "enabled" ] && "$pBuddy" -c "Print :OptionalArguments:BannerImageDarkMode" "$renewConfig" >/dev/null 2>&1 ; then
	bannerImage=$("$pBuddy" -c "Print :OptionalArguments:BannerImageDarkMode" "$renewConfig")
fi

#Now do the same thing for a notification icon. We need some extra tidbits to just not include the --icon flag at all if it isn't defined in the config
#Define the notification icon variable as empty
notificationIcon=''

#If there is a banner icon defined in the configuration file, set it.
if "$pBuddy" -c "Print :OptionalArguments:NotificationIcon" "$renewConfig" >/dev/null 2>&1 ; then
	notificationIcon=$("$pBuddy" -c "Print :OptionalArguments:NotificationIcon" "$renewConfig")
fi

#If Dark mode is enabled and a NotificationIconDarkMode is defined in the configuration profile, set our variable to use it.
if [ "$darkMode" = "enabled" ] && "$pBuddy" -c "Print :OptionalArguments:NotificationIconDarkMode" "$renewConfig" >/dev/null 2>&1 ; then
	notificationIcon=$("$pBuddy" -c "Print :OptionalArguments:NotificationIconDarkMode" "$renewConfig")
fi

#Now do the logic to set the variables that will actually be used
#This is tedious code that could be simplified with a function, but i couldn't get my brain around it
#How do you set a variable to have the name of a argument you pass to a function? Need someone smarter than me to clue me in on that one.
# - `eval`... the answer is eval... but I'm not putting in the effort to do that here right now. Irony being that eval is used unnecessarily in this script already.

if "$pBuddy" -c "Print :OptionalArguments:NormalMessage" "$renewConfig" >/dev/null 2>&1 ; then
	dialogNormalMessage=$("$pBuddy" -c "Print :OptionalArguments:NormalMessage" "$renewConfig")
else
	dialogNormalMessage="$defaultDialogNormalMessage"
fi

# If ShowDeferralCount is active, adjust the dialogMessage
if [[ $("$pBuddy" -c "Print :OptionalArguments:ShowDeferralCount" "$renewConfig" 2>&1) = 'true' ]] ; then
	dialogNormalMessage="$dialogNormalMessage \n\n$defaultDeferralMessage $deferralsRemaining"
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
	dialogAdditionalOptionsString=$("$pBuddy" -c "Print :OptionalArguments:AdditionalDialogOptions" "$renewConfig")
	dialogAdditionalOptions=()
	# This is how we split a single variable value (as read from our profile) into multiple entries in an array
	eval 'for argument in '$dialogAdditionalOptionsString'; do dialogAdditionalOptions+=$argument; done'
else
	dialogAdditionalOptions+=($defaultDialogAdditionalOptions)
fi

if "$pBuddy" -c "Print :OptionalArguments:AdditionalAggressiveOptions" "$renewConfig" >/dev/null 2>&1 ; then
	dialogAggressiveOptionsString=$("$pBuddy" -c "Print :OptionalArguments:AdditionalAggressiveOptions" "$renewConfig")
	# This is how we split a single variable value (as read from our profile) into multiple entries in an array
	eval 'for argument in '$dialogAggressiveOptionsString'; do dialogAggressiveOptions+=$argument; done'

else
	dialogAggressiveOptions+="$defaultDialogAggressiveOptions"
fi

if "$pBuddy" -c "Print :OptionalArguments:AdditionalNormalOptions" "$renewConfig" >/dev/null 2>&1 ; then
	dialogNormalOptionsString=$("$pBuddy" -c "Print :OptionalArguments:AdditionalNormalOptions" "$renewConfig")
	# This is how we split a single variable value (as read from our profile) into multiple entries in an array
	eval 'for argument in '$dialogNormalOptionsString'; do dialogNormalOptions+=$argument; done'
else
	dialogNormalOptions+="$defaultDialogNormalOptions"
fi

if "$pBuddy" -c "Print :OptionalArguments:AdditionalNotificationOptions" "$renewConfig" >/dev/null 2>&1 ; then
	dialogNotificationOptions=$("$pBuddy" -c "Print :OptionalArguments:AdditionalNotificationOptions" "$renewConfig")
else
	dialogNotificationOptions="$defaultDialogNotificationOptions"
fi

if "$pBuddy" -c "Print :OptionalArguments:NotificationSubtitle" "$renewConfig" >/dev/null 2>&1 ; then
	subtitleOptions=$("$pBuddy" -c "Print :OptionalArguments:NotificationSubtitle" "$renewConfig")
else
	subtitleOptions="$defaultSubtitleOptions"
fi

if "$pBuddy" -c "Print :OptionalArguments:SecretQuitKey" "$renewConfig" >/dev/null 2>&1 ; then
	secretQuitKey=$("$pBuddy" -c "Print :OptionalArguments:SecretQuitKey" "$renewConfig")
else
	secretQuitKey="$defaultSecretQuitKey"
fi

# Set deadline from configuration profile
if [ -n "$deadlineFromArgument" ]; then
	deadline="$deadlineFromArgument"
elif [ -z "$deadline" ] && "$pBuddy" -c "Print :OptionalArguments:Deadline" "$renewConfig" >/dev/null 2>&1 ; then
	# If we're using a test mode, set deadline to a very high value. Otherwise, set it to the configuration value
	if [ "$forceNormal" = 1 ] || [ "$forceNotification" = 1 ] || [ "$forceAggro" = 1 ] ; then
		log_message "Setting deadline to 999 for testing"
		deadline=999
	else
		deadline=$("$pBuddy" -c "Print :OptionalArguments:Deadline" "$renewConfig")
		log_message "Deadline set to: $deadline"
	fi
else
	deadline=''
fi

# Set notification button options. If option is false, unset them
notificationButtonOptions=(
	--button1action "osascript -e 'tell app \"loginwindow\" to «event aevtrrst»'"
)
if "$pBuddy" -c "Print :OptionalArguments:NotificationActionEnabled" "$renewConfig" >/dev/null 2>&1 ; then
	notificationActionEnabled=$("$pBuddy" -c "Print :OptionalArguments:NotificationActionEnabled" "$renewConfig")
	if ! "${notificationActionEnabled}"; then
		notificationButtonOptions=()
	fi
fi

if [ "$dryRun" = 1 ]; then
	notificationButtonOptions=()
fi

function add_final_dialog_options(){

	# function to swap one token in one variable
	swap_token() {
		# $1 is the name of the variable we want to process
		# $2 is the token we're looking to swap out
		# $3 is the variable we want to swap in place of the token
		local variableToSwap=$1 token=$2 value=$3
		eval "$variableToSwap=\"\${$variableToSwap//\{$token\}/$value}\""
	}

	# List of variables to swap our tokens
	tokenSwapVarsList=(
	dialogAggroMessage
	dialogNormalMessage
	dialogNotificationMessage
	dialogTitle
	subtitleOptions
	dialogNoDeferralsRemainingButtonText
	dialogDeferralButtonText
	dialogRestartButtonText
	)

	# Swap in the token contents for each variable in our list
	for varSwap in "${tokenSwapVarsList[@]}"; do
		swap_token "$varSwap" uptime "$uptime_days"
		swap_token "$varSwap" deferralcount "$currentDeferralCount"
		swap_token "$varSwap" deferralsremaining "$deferralsRemaining"
	done

	# If BannerImage has a value, add it to the additional options array. Do this here, so that these options aren't added to notifications.
	if [ -n "$bannerImage" ]; then
		dialogAdditionalOptions+=("--bannerimage" "$bannerImage")
	fi

	if [ -n "$notificationIcon" ]; then
		dialogNotificationOptions+=("--icon" "$notificationIcon")
	fi

	if [ -n "$subtitleOptions" ]; then
		dialogNotificationOptions+=("--subtitle" "$subtitleOptions")
	fi
	
}

#################
#	Run Modes	#
#################

# Define what happens when Aggressive mode is engaged
function exec_aggro_mode()
{

log_message "Executing aggressive mode"

# go aggro
	check_assertions
	# shellcheck disable=SC2068

	"$dialogPath" \
	--title "$dialogTitle" \
	--button1text "$dialogNoDeferralsRemainingButtonText" \
	--button1disabled \
	--infobuttontext "$dialogRestartButtonText" \
	--icon "$dialogIcon" \
	--messagealignment centre \
	--centericon \
	--messagealignment center \
	--quitkey "$secretQuitKey" \
	${dialogAdditionalOptions[@]} \
	${dialogAggressiveOptions[@]} \
	--message "$dialogAggroMessage" \
	
	# Set exit code based on user input
	dialogExitCode=$?
	
}

# Define what happens when  Normal mode is engaged
function exec_normal_mode()
{

log_message "Executing normal mode"


# go normal
	check_assertions
	# shellcheck disable=SC2068

	"$dialogPath" \
	--title "$dialogTitle" \
	--infobuttontext "$dialogRestartButtonText" \
	--button1text "$dialogDeferralButtonText" \
	--centericon \
	--icon "$dialogIcon" \
	--messagealignment centre \
	--quitkey "$secretQuitKey" \
	${dialogAdditionalOptions[@]} \
	${dialogNormalOptions[@]} \
	--message "$dialogNormalMessage" \

	# Set exit code based on user input
	dialogExitCode=$?

}

# Define what happens when Notification mode is engaged
function exec_notification_mode()
{
log_message "Executing notification mode"

# go notification
	check_assertions
	# shellcheck disable=SC2068

	"$dialogPath" \
	--notification \
	--title "$dialogTitle" \
	"${notificationButtonOptions[@]}" \
	--message "$dialogNotificationMessage" \
	${dialogAdditionalOptions[@]} \
	${dialogNotificationOptions[@]} \

	((notificationCount=notificationCount+1))
	"$pBuddy" -c "Set :NotificationCount $notificationCount" "$userDeferralProfile"
	
	exec_deferral
	
	exit 0
}

# This function adds to the deferral count and sets an active deferral time
function exec_deferral()
{
	if [ "$dryRun" = 1 ]; then
		log_message "Skipping deferral due to dry-run option"
		return 0
	fi
	log_message "Executing deferral process."
	((currentDeferralCount=currentDeferralCount+1))
	log_message "New current deferral count: $currentDeferralCount"
	"$pBuddy" -c "Set :CurrentDeferralCount $currentDeferralCount" "$userDeferralProfile"
	log_message "New defer until value: $deferUntil"
	"$pBuddy" -c "Set :ActiveDeferral $deferUntil" "$userDeferralProfile"
	log_message "New human readabale deferral date: $humanReadableDeferDate"
	"$pBuddy" -c "Set :HumanReadableDeferDate $humanReadableDeferDate" "$userDeferralProfile"
}

function exec_restart()
{
# If the --dry-run flag is given as a script argument for testing, then the reboot button doesn't actually reboot
if [ "$dryRun" = 1 ]; then
	log_message "DRY-RUN: Restart would happen here"
	exit 0
fi

log_message "Executing restart"

# This is the restart command. Thank you Dan Snelson: https://snelson.us/2022/07/log-out-restart-shut-down/

osascript -e 'tell app "loginwindow" to «event aevtrrst»'

}

# By default, we wnat to ignore some specific app assertions (caffeinate, Amphetamine, obs). These aren't actual indicators of what we're looking for.
assertionsToIgnore=()

# If the admin has set any items in the config add them to assertionsToIgnore
count=0
until ! "$pBuddy" -c "Print :OptionalArguments:IgnoreAssertions:$count" $renewConfig > /dev/null 2>&1; do
    assertionsToIgnore+=$("$pBuddy" -c "Print :OptionalArguments:IgnoreAssertions:$count" $renewConfig)
    count=$(( count + 1 ))
done

# Default Ignore List
assertionsToIgnore+="obs"
assertionsToIgnore+="OBS"
assertionsToIgnore+="zoom.us"
assertionsToIgnore+="Amphetamine"
assertionsToIgnore+="caffeinate"

function process_user_selection()
{
	# User has made a selection. Now we process it.
	debug_message "DIALOG EXIT CODE: $dialogExitCode."

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

}

function check_assertions()
{
	check_user_idle

	## Thank you @Pico for the commands to check for the screen being awake and unlocked
	# Check if the screen is asleep. Exit quietly without a deferral if it s not awake.
	if [[ "$(osascript -l 'JavaScript' -e 'ObjC.import("CoreGraphics"); $.CGDisplayIsActive($.CGMainDisplayID())')" == '1' ]]; then
		debug_message "Screen is awake"
	else
		log_message "Screen is asleep. Exiting without event or deferral."
		exit 0
	fi

	# Check if the screen is locked. Exit quietly without a deferral if it s not unlocked.
	if [[ "$(/usr/libexec/PlistBuddy -c "Print :IOConsoleUsers:0:CGSSessionScreenIsLocked" /dev/stdin <<< "$(ioreg -ac IORegistryEntry -k IOConsoleUsers -d 1)" 2> /dev/null)" != 'true' ]]; then
		debug_message "Screen is unlocked"
	else
		log_message "Screen is locked. Exiting without event or deferral."
		exit 0
	fi

	# Check for active screen assertions. If an application is preventing the screen from sleeping, we don't notify. It typically means user is in a video meeting or watching a video.
	checkForAssertion=$(pmset -g | grep "display sleep prevented by"| sed 's/.*(\(.*\))/\1/' | sed 's/display sleep prevented by //'| sed 's/,//g')

	for i in "${assertionsToIgnore[@]}"; do
		checkForAssertion=$(echo "$checkForAssertion" | sed "s/$i//g" | xargs )
	done
		
	if [ -n "$checkForAssertion" ]; then
		log_message "Display sleep assertion(s) identified: $checkForAssertion ... Exiting."
		exit 0
	else
		debug_message "No assertions stopping us from notifying."
	fi

}

function check_user_idle(){
	systemIdleTime=$(/usr/sbin/ioreg -c IOHIDSystem | /usr/bin/awk '/HIDIdleTime/ {print int($NF/1000000000); exit}')
	if [ "$systemIdleTime" -gt 3600 ]; then
		log_message "System has been idle for $(( systemIdleTime / 60 )) minutes. Exiting"
		exit 0
	fi
}

#################
#	The Maths	#
#################
### Big thanks to Pico on the Mac Admins slack for the logic on the time variables.
# Determine current Unix epoch time
current_unix_time="$(date '+%s')"

# This reports the unix epoch time that the kernel was booted
boot_unix_time="$(sysctl -n kern.boottime | awk -F 'sec = |, usec' '{ print $2; exit }')"

# Get uptime in seconds by doing maths
uptime_seconds="$(( current_unix_time - boot_unix_time ))"

# I'm spelling out the math in multiple steps because i'm kind of a dummy. This could be one unreadable command, but i prefer this.
uptime_minutes="$(( uptime_seconds / 60 ))"
uptime_hours="$(( uptime_minutes / 60 ))"
uptime_days="$(( uptime_hours / 24 ))"

debug_message "Uptime values are: $uptime_days days = $uptime_hours hours = $uptime_minutes minutes = $uptime_seconds seconds"

log_message "Uptime Days: $uptime_days"
log_message "Uptime Seconds: $uptime_seconds"

deferUntilSeconds=$((deferralDuration * 60 * 60 - 300))
deferUntil=$((current_unix_time+deferUntilSeconds))

debug_message "Defer Until: $deferUntil which is $(date -j -f %s $deferUntil)"
humanReadableDeferDate=$(date -j -f %s $deferUntil)

add_final_dialog_options

##################################################################
#
# This section processes disabled RequiredArguments
#
##################################################################

# If the maximum deferrals is disabled, set it to an absurd value
# This sets a practically infinite number of deferrals
if [ "$maximumDeferrals" = '-1' ];then
	maximumDeferrals='9999999999999'

fi

# If the notification threshold is disabled, set it to an absurd value
# This enables Notification Only mode
if [ "$notificationThreshold" = '-1' ];then
	notificationThreshold='9999999999999'
fi

#############################
#	Configure for Testing	#
#############################

# If dryRun is enabled, set uptime days to a value that is sure to trip your policy
if [ "$dryRun" = 1 ]; then
	activeDeferral=0
fi

# Check if we're forcing aggro for testing
if [ "$forceAggro" = 1 ]; then
	uptime_days=$(( uptimeThreshold+1 ))
	currentDeferralCount=$(( maximumDeferrals+1 ))
	activeDeferral=0
	notificationCount=$((notificationThreshold+1))
	log_message "FORCE-AGGRO: Setting uptime_days to $uptime_days value for testing purposes."
fi

# Check if we're forcing normal for testing
if [ "$forceNormal" = 1 ]; then
	uptime_days=$(( uptimeThreshold+1 ))
	activeDeferral=0
	notificationCount=$((notificationThreshold+1))
	currentDeferralCount=0
	log_message "FORCE-NORMAL: Setting uptime_days to $uptime_days value for testing purposes."
fi

# Check if we're forcing notification for testing
if [ "$forceNotification" = 1 ]; then
	activeDeferral=0
	log_message "FORCE-NOTIFICATION: Setting activeDeferral to $activeDeferral for testing purposes."
	exec_notification_mode
fi

# Check if we're forcing a deferral
if [ -n "$forceDeferralMinutes" ]; then
	deferUntilSeconds="$forceDeferral"
	echo $current_unix_time
	deferUntil=$((current_unix_time+deferUntilSeconds))
	humanReadableDeferDate=$(date -j -f %s $deferUntil)
	exec_deferral
	exit 0
fi

#############################################
#	Primary Script Behavior Starts Here	#
#############################################
log_message "Executing Uptime Logic"

# Are we in a deferral time range? If so, exit quietly.
if [ $activeDeferral -ge $current_unix_time ]; then
	log_message "A deferral is active. Exiting."
	exit 0
fi

# Is a Deadline set? If so, check and run logic.
if [ -n "$deadline" ] && [ "$uptime_days" -ge "$deadline" ]; then
	debug_message "Deadline is past"
	exec_aggro_mode
	process_user_selection
	exit 0
fi

# First check if the uptime necessitates action. If not, reset all deferrals and exit 0.
if [ "$uptime_days" -ge "$uptimeThreshold" ]; then
	# First check if the user has received the desired number of notifications, and if not execute notification mode.
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
	process_user_selection
else
	# No enforcement needed, so we set deferrals to zero
	log_message "Device does not need to be restarted."
	reset_deferral_profile
fi

exit 0
