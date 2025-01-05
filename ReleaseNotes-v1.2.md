v1.2 Change Log

## New Features
- New Default Behavior: Clicking the Dialog notification will initiate the restart window
    - This can be disabled in the profile with new OptionalArguments boolean key set to `false`: `NotificationActionEnabled` [#81](https://github.com/SecondSonConsulting/Renew/issues/81)
- Language support for Dutch (nl)
    - Thank you, @DevliegereM! [#90](https://github.com/SecondSonConsulting/Renew/issues/90)
- Renew can now be used with a plist file OR a mobileconfig
    - If a mobile configuration file is not found, Renew will check for a configuration file in this location: `/Library/Preferences/com.secondsonconsulting.renew.plist`
    - Thank you to @drtaru for adding this feature!
- Admins can now choose additional applications to ignore assertions.
    - Thank you, @DevliegereM! [#90](https://github.com/SecondSonConsulting/Renew/issues/90)
    - If you don't want to respect a display sleep assertion for an application, you can add that application to an `OptionalArguments:IgnoreAssertions` array in your configuration file.
    - The default assertions to ignore will still be used as well (`obs caffeinate Amphetamine`)
    - Use `pmset -g` to see what applications are using assertions as well as how to ignore them.

## Improvements
- Argument Processing rewritten
    - `--version` now prints only the script version and exits with no logs and no other output
    - Multiple arguments are now supported. It is up to the operator to ensure conflicting arguments are not passed
        - `--verbose --force-normal --dryrun` is valid
        - `--verbose --force-normal --force-notification` is invalid, and will result in undefined behavior
    - `--verbose`or `-v` enables `set -x` for verbose troubleshooting output
    - `--dryrun` argument now does not process a deferral as well as disabling Restart prompt
    - `--deadline` argument now sets the deadline to the provided value for testing
        - Example: `./Renew.sh --deadline 66` will set the deadline to 66 days uptime
    - `--print-configuration` option will print the configuration file and exit
    - `--configuration /path/to/renew.plist` allows you to specify a plist file you wish to use as the configuration for that run.
        - This is intended for use in testing, though, there's nothing stopping you from using this option with a LaunchAgent or from your management tool
        - This argument overrides any MDM profile or configuration file for that run
    - [#80](https://github.com/SecondSonConsulting/Renew/issues/80)

- Renew no longer processes deferrals/events if the system has been idle from human input for over 60 minutes
- If the same program has multiple display sleep assertions (like caffeinate running twice or more), Renew will now properly ignore them if they're on the `IgnoreAssertions` list.

## Housekeeping
- Renew is now published under the MIT open-source license
- All log messages are now also written to standard output
- Log messages are more useful in determinig what logic is being applied and why
    - [#75](https://github.com/SecondSonConsulting/Renew/issues/75)
- Debug messages now only visible in verbose mode, and not tied to `--dryrun` option