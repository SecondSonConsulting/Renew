# Renew

See our [wiki](https://github.com/SecondSonConsulting/Renew/wiki) for installation details and information on how the tool works. 

## Overview
Renew is a shell script for macOS meant to be run on regular intervals to encourage users to restart their computers on a regular basis. Notifications can become progressively more aggressive if the user chooses to defer their restart beyond the configured threshold.

Renew runs as the logged in user and will never restart a computer without a user's consent. 
## Why?
Regularly restarting your workstation is an important part of keeping it running healthy and secure. Application updates, MDM commands, and security software will run more efficiently when the computer is allowed to restart on a regular basis. We have found that 10-14 day restarts are ideal to keeping things working as expected.

## Dependencies
macOS 11+ is required
Swift Dialog - (v.2.0 or newer required for notification center features) https://github.com/bartreardon/swiftDialog
A configuration profile (either locally installed mobileconfig or delivered via MDM)
A means to initiate the script (typically a LaunchAgent)

Swift Dialog - (v.2.0 or newer required for notification center features) https://github.com/bartreardon/swiftDialog

A configuration profile (either locally installed mobileconfig or delivered via MDM)

A means to initiate the script (typically a LaunchAgent)

## Screenshots
### Notification Mode Default User Experience
![Renew Notification Example Image](https://github.com/SecondSonConsulting/Renew/blob/main/Example%20Screenshots/Renew-NotificationDefault.png?raw=true)
### Normal Mode Default User Experience
![Renew Normal Example Image](https://github.com/SecondSonConsulting/Renew/blob/main/Example%20Screenshots/Renew-NormalDefaultDialog.png?raw=true)
### Aggressive Mode Default User Experience
![Renew Aggressive Example Image](https://github.com/SecondSonConsulting/Renew/blob/main/Example%20Screenshots/Renew-AggressiveDefaultDialog.png?raw=true)
### Custom Fields Design Example Image
SwiftDialog allows a high degree of customization, and Renew allows you to continue to easily take advantage of that. This is an example of how you can customize the user experience to suit your branding and taste.

This example uses a banner image tailored to the window size, and the following OptionalArgument in the configuration file.

`<key>AdditionalDialogOptions</key>`

`<string>--width 300 --height 350 --messagefont size=15 --position topright --ontop --messagealignment centre</string>`
![Renew Customized Example Image](https://github.com/SecondSonConsulting/Renew/blob/main/Example%20Screenshots/Renew-CustomizedDialog.png?raw=true)

## Thank you!
This project is made possible by the awesome folks on the MacAdmins slack for their support and community projects.

A huge thanks to Bart Reardon for creating and maintaining [Swift Dialog](https://github.com/bartreardon/swiftDialog). Without this tool, Renew would not have been possible.

It should be obvious to anyone familiar with [Nudge](https://github.com/macadmins/nudge) that some of the basic concepts of Renew are influenced by it. Thank you Erik Gomez for providing your hard work to the community for free.

A resounding shoutout to all of the members of the MacAdmins community for their guidance and education on all things macOS, especially the gurus in the #scripting channel for their endless patience and assistance as we worked to increase our scripting knowledge. @pico @scriptingosx @adamcodega @Brock Walters @Josh Rickets and many more I'm probably forgetting. Thank you for your patient guidance on all things macOS.
