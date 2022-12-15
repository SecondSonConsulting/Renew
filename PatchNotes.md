### Renew.sh v0.1.11 - Patch Notes
- Fixed a bug that could affect the "restart now" button in Deadline mode or --force-aggro mode
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
