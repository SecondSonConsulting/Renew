# Renew
## Overview
Renew is a shell script for macOS meant to be run on regular intervals to encourage users to restart their computers on a regular basis. Notifications can become progressively more aggressive if the user chooses to defer their restart beyond the configured threshold.
## Why?
Regularly restarting your workstation is an important part of keeping it running healthy and secure. Application updates, MDM commands, and security software will run more efficiently when the computer is allowed to restart on a regular basis. We have found that 10-14 day restarts are ideal to keeping things working as expected.

## Dependencies
macOS 11+ is required (Swift Dialog dependency)
Swift Dialog v.2.0 or newer https://github.com/bartreardon/swiftDialog
A configuration profile (either locally installed mobileconfig or delivered via MDM)
A means to initiate the script (typically a LaunchAgent)

## Thank you!
This project is made possible by the awesome folks on the MacAdmins slack for their support and community projects.

It should be obvious to anyone familiar with [Nudge](https://github.com/macadmins/nudge) that this project is heavily influenced by it. Thank you Erik Gomez for providing your hard work to the community for free.

A huge thanks to Bart Reardon for creating and maintaining [Swift Dialog](https://github.com/bartreardon/swiftDialog). Without this tool, Renew would not have been possible.

A resounding shoutout to all of the members of the MacAdmins community for their guidance and education on all things macOS, especially the gurus in the #scripting channel for their endless patience and assistance as we worked to increase our scripting knowledge. @pico @scriptingosx @Brock Walters @Josh Rickets and many more I'm probably forgetting. Thank you for your patient guidance on all things macOS.

## Screenshots
### Notification Mode Default User Experience
![Renew Notification Example Image](https://github.com/SecondSonConsulting/Renew/blob/main/Examples/Renew-NotificationDefault.png?raw=true)
### Normal Mode Default User Experience
![Renew Normal Example Image](https://github.com/SecondSonConsulting/Renew/blob/main/Examples/Renew-NormalDefaultDialog.png?raw=true)
### Aggressive Mode Default User Experience
![Renew Aggressive Example Image](https://github.com/SecondSonConsulting/Renew/blob/main/Examples/Renew-AggressiveDefaultDialog.png?raw=true)
### Custom Fields Ugly Example Image
This image is only to illustrate how the various options you choose affect the final messaging. Please don't subject your users to this in production.
![Renew Custom Fields Example Image](https://github.com/SecondSonConsulting/Renew/blob/main/Examples/Renew-UglyExampleImage.png?raw=true)

## How it works
Renew is meant to be run on regular intervals throughout the day. It was designed to be used with a LaunchAgent which runs every 30 minutes, and an example LaunchAgent is provided.
When Renew is run, it checks the current uptime of the macOS device against the configuration profile to determine if the uptime is out of compliance.

If the device has been restarted within the configured acceptable timeframe, the script exits quietly.

If the device has an uptime which exceeds the configured uptime threshold, then they will be notified via the macOS Notification Center that they need to restart their computer as soon as they are able. If the device is within a Deferral timeframe, the user will not be notified again until that deferral timeframe has passed.

If the user ignores the notifications beyhond the configured notification threshold, then a more prominent SwiftDialog window will appear informing the user that they have X deferrals remaining before they will be required to restart.

If the user ignores the deferral Swift Dialog windows beyond the threshold, Renew enters "Aggressive" mode and the user has no more deferral options and will be presented only with a button consenting to a restart.

Renew will never initiate a restart of a workstation without the user clicking the button to consent to it. Actions are taken dependent upon Swift Dialog exit codes, and exit code 3 is used to initiate a reboot (aka the Information Button). All other exit codes either immediately exit Renew.

## Installation Details
Renew consists of a single shell script, typically installed to </usr/local/renew.sh>
An optional LaunchAgent is also provided, it will call the script every 30 minutes at :15 and :45 
If you use our provided LaunchAgent, you  may want to also provide a Managed Background Items MDM payload to prevent the user from turing off the Login Item in macOS 13+. 
The Label to enforce is:
    com.secondsonconsulting.renew
A mobileconfig file is also required in order to dictate the user experience and script behavior.
If you plan to use the "Notifications" options you may also wish to deliver a Notifications Profile via MDM to ensure the user gets the Notification Center events.
Renew will generate its own configuration plist files located at:
    ~/Library/Preferences/com.secondsonconsulting.renew.plist
This plist can be deleted at any time to reset the user deferral counts without adversely impacting how Renew works.
**Renew should always be invoked as a currently logged in user, NOT as root.**
Installing the PKG file requires administrator access to set permissions on the script and to create the Global Launch Agent.

**A PKG installer that places the script and the LaunchAgent may also be provided, however at this time it will not be a signed package**

## Configuration Details
The behavior of the Renew script is dependent upon values entered into the configuration file. 
The profile domain is <com.secondsonconsulting.renew> 
Renew will run with default english language messaging if provided with only the required arguments keys, and can be customized by including any or all of the optional arguments keys.
Two sample mobileconfig files are provided, one with minimum options required to run and one with example options for all of the optional arguments.
### Required Arguments
#### MaximumDeferrals \<integer\>
This is the maximum number of deferrals a user receives before Renew enters "Aggressive" mode.
Please note that "Notifications" count toward the MaxmimumDeferrals amount even though the user does not interact with them.
#### UptimeThreshold \<integer\>
The number of days which a device is online prior to the Renew experience starting. Devices were last powered on fewer than UptimeThreshold days will not receive notifications.
Example: If a device is powered on October 1st, and the UptimeThreshold is set to 10 days, then the user will begin to be notified on October 11th.
#### NotificationThreshold \<integer\>
The numbe of times the user will get a macOS Notification Center event prior to the full Swift Dialog experience.
Example: If a device is is past the uptime threshold and not within a deferral timeframe, they will be first notified via a notification center event. Renew processes this as a deferral, and exits after sending the notification.
#### DeferralDuration \<integer\>
The minimum number of hours between when a user is notified that they need to restart. This is clocked in calendar time, not device uptime.
Example: A user receives a notification center event from Renew. If this value is set to 4, then the user will not receive another Renew event until that 4 hour duration has passed (regardless if the script runs again via LaunchAgent or otherwise).
### Optional Arguments
#### Title \<string\>
The Title of the Notification and Swift Dialog messages. See <--title> option of [Swift Dialog](https://github.com/)

Default value: "Please Restart"
#### AggroMessage \<string\>

Default value: "\*\*Please save your work and restart\*\*"
#### NormalMessage \<string\>

Default value: "In order to keep your system healthy and secure it needs to be restarted.  \\n\*\*Please save your work\*\* and restart as soon as possible."
#### NotificationMessage \<string\>

Default value: "In order to keep your system healthy and secure it needs to be restarted.  \nPlease save your work and restart as soon as possible."
#### NotificationIcon \<string\>
Path to an icon you would like included in the Notification Center message.
Please note: Due to limitations on how macOS works, the prominent icon of a Notification Center message will always be the Dialog.app icon. See [Swift Dialog](https://github.com/) documentation for more details.

Default value: ""
#### MessageIcon \<string\>
Path to the icon which will be used for Renew Swift Dialog windows. This can be a locally stored file, an SF Symbol, an App Bundle, or a hosted file. See [Swift Dialog](https://github.com/) documentation for details.

Default value: "SF=bolt.circle color1=pink color2=blue"
#### AdditionalDialogOptions  \<string\>
Any additional Swift Dialog options you wish to include can be provided here. This was tested primarily with --titlefont and --messagefont options, but other compatible Swift Dialog options will likely work. See [Swift Dialog](https://github.com/) documentation for options and formatting.
Default value: ""
#### SecretQuitKey  \<string\>
By default, Swift Dialog can be quit using the CMD+Q option. This is undesirable for our purposes, and so a "secret quit key" is set by default and can be changed in the configuration file. 
This must be a single character, and cannot be a capital letter or symbol requiring the shift key.
**To quit a Renew message without being required to restart, use CMD+] or CMD + your Secret Quit Key.**

Default value: "]"

## Command-Line Arguments
Typically Renew should be called just by itself, however some command line arguments have been provided in order to facilitate testing.
There are no valid combinations of command line options, only one option should be included at any time.
**Renew should always be invoked as a currently logged in user, NOT as root.**
### --reset
This argument will reset the user's deferral profile to all zeros
### --force-aggro
This argument will force a SwiftDialog window with the "Aggressive Mode" options regardless of the current uptime or deferral options.
Tip: Remember you can use the SecretQuitKey to dismiss this without having to restart during testing.
### --force-normal
This argument will force a SwiftDialog window with the "Normal Mode" options regardless of the current uptime or deferral options.
### --force-notification
This argument will force a SwiftDialog Notification Center event regardless of the current uptime or deferral options.