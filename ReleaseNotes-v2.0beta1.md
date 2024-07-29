v2.0 Change Log

LOOK THROUGH YOUR SHIT FROM THE OTHER NIGHT

## New Features
- New Default Behavior: Clicking the Dialog notification will initiate the restart window
    - This can be disabled in the profile with new OptionalArguments boolean key set to `false`: `NotificationActionEnabled`
    - `--dryrun` argument disables this for that run

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

## Housekeeping
- All log messages are now written to standard out
- Debug messages now only visible in verbose mode, and not tied to `--dryrun` option