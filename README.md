# Renew
## Overview
Renew is a shell script for macOS meant to be run on regular intervals to encourage users to restart their computers on a regular basis. Notifications can become progressively more aggressive if the user chooses to defer their restart beyond the configured threshold.

## Dependencies
Swift Dialog v.2.0 or newer https://github.com/bartreardon/swiftDialog
A configuration profile (either locally installed mobileconfig or delivered via MDM)
A means to initiate the script (typically a LaunchAgent)

## Thank you!
This project is made possible by the awesome folks on the MacAdmins slack for their support and community projects.

It should be obvious to anyone familiar with [Nudge](https://github.com/macadmins/nudge) that this project is heavily influenced by it. Thank you Erik Gomez for all of your work on that tool and providing your hard work to the community for free.

A huge thanks to Bart Reardon for creating and maintaining [Swift Dialog](https://github.com/bartreardon/swiftDialog). Without this tool, Renew would not have been possible.

A resounding shoutout to all of the members of the MacAdmins community for their guidance and education on all things macOS, especially the gurus in the #scripting channel for their endless patience and assistance as we worked to increase our scripting knowledge. @pico @scriptingosx @Brock Walters and many more I'm probably forgetting. Thank you for your patient guidance on all things macOS.

## How it works
Renew is meant to be run on regular intervals throughout the day. It was designed to be used with a LaunchAgent which runs every 30 minutes, and an example LaunchAgent is provided.
When Renew is run, it checks the current uptime of the macOS device against the configuration profile to determine if the uptime is out of compliance.

If the device has been restarted within the configured acceptable timeframe, the script exits quietly.

If the device has an uptime which exceeds the configured uptime threshold, then they will be notified via the macOS Notification Center that they need to restart their computer as soon as they are able.

If the user ignores the notifications beyhond the configured notification threshold, then a more prominent SwiftDialog window will appear informing the user that they have X deferrals remaining before they will be required to restart.

If the user ignores the deferral Swift Dialog windows beyond the threshold, Renew enters "Aggressive" mode and the user has no more deferral options and will be presented only with a button consenting to a restart.

Renew will never initiate a restart of a workstation without the user clicking the button to consent to it. Actions are taken dependent upon Swift Dialog exit codes, and exit code 3 is used to initiate a reboot (aka the Information Button). All other exit codes either immediately exit Renew.

## Configuration Details
The behavior of the Renew script is dependent upon values entered into the configuration file. 
The profile domain is <com.secondsonconsulting.renew> 
Renew will run with default english language messaging if provided with only the required arguments keys, and can be customized by including any or all of the optional arguments keys.
### Required Arguments
#### MaximumDeferrals \<integer\>
This is the maximum number of deferrals a user receives before Renew enters "Aggressive" mode. 
#### UptimeThreshold <integer>
