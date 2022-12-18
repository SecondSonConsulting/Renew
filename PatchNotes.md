### Renew.sh v1.0 - Patch Notes
- First production release!
- Gently (or not so much) urge your users to restart their computers on a regular basis
- Utilize the many amazing features of [SwiftDialog](https://github.com/bartreardon/swiftDialog) to make beautiful native macOS windows and notifications with your branding and messaging of choice.
- Control the branding and operation entirely through a Mobile Configuration file
- [Profiles Manifest](https://github.com/ProfileCreator/ProfileManifests) support (which feeds into [iMazing Profile Editor](https://imazing.com/profile-editor), pending pull request on that project)
- [Installomator](https://github.com/Installomator/Installomator) support (pending pull request on that project)
- Default package includes a Launch Agent to run the script every 30 minutes
- Alternate package does not include a Launch Agent. Configure your own custom scheduling to suit your needs
- [Visit the wiki](https://github.com/SecondSonConsulting/Renew/wiki) for detailed documentation and deployment scenarios
- Default language support for 5 languages (and will add more upon submission)
- Ask questions or get community support in the #renew channel on the Mac Admins Slack

### Renew.sh v0.1.12 - Patch Notes
- Added a check to verify the script is not running as root. If run as root, the script now bails. This should prevent issues with users having their Deferrals Profile inaccessible when running as user.

### Renew.sh v0.1.11 - Patch Notes
- Fixed a bug that could affect the "restart now" button behavior in Deadline mode or --force-aggro mode
- Minor code cleanup

### Renew.sh v0.1.10 - Patch Notes
- This release, and all future releases, will now be Signed, Notarized, and Stapled with: "Developer ID Installer: Second Son Consulting Inc. (7Q6XP5698G)"
- This release, and all future releases, will include an alternate pkg which has no LaunchAgent, and no pre or post-install scripts. If you're using your own customized timing mechanism you can safely run the `Renew_v.x_NoAgent.pkg` package and not overwrite your own changes.
- Fixed dialogExitCode variable typo
- **_\*\*\*Default messaging behavior changed!_** Removed `-o` flag from dialog command, resulting in default SwiftDialog behavior that windows cannot be moved. This can be added to your `OptionalArguments` `AdditionalDialogOptions` in your configuration file if you would like your windows to be movable.
- Added additional configuration keys for:
    - AdditionalNormalOptions
    - AdditionalAggressiveOptions
    - AdditionalNotificationOptions
    - NotificationSubtitle
- Added `--defer n` testing feature, where `n` equals the number of minutes you want to set a deferral for. Script exits after processing the deferral.
- **_\*\*\*Default messaging behavior changed!_** Added `ShowDeferralCount` Optional Argument.
  - The "deferrals remaining" language is no longer included by default
  - Set this key to boolean <true/> to show the "deferrals remaining" language in Normal Mode events
- Added `Deadline` Optional Argument. Use this to set an uptime deadline of \<integer\> days and if your uptime exceeds this you get Aggressive Mode messages.
  - See [this page](https://github.com/SecondSonConsulting/Renew/wiki/Deployment-Strategies#deadline-mode) for an example and explanation on how to use this new feature.
- Added the ability to disable `MaximumDeferrals` by setting to `-1`
- Added the ability to disable `NotificationThreshold` by setting to `-1`

_See [Optional Arguments](https://github.com/SecondSonConsulting/Renew/wiki/OptionalArguments), [Required Arguments](https://github.com/SecondSonConsulting/Renew/wiki/RequiredArguments), and  [Command Line Arguments](https://github.com/SecondSonConsulting/Renew/wiki/Command-Line-Arguments) wiki pages for details on how to implement these new features._

_I've also added numerous examples to the [Deployment Strategies](https://github.com/SecondSonConsulting/Renew/wiki/Deployment-Strategies) wiki page to spark ideas on how to configure._
