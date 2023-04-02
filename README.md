# check librenms alerts

This is a librenms alert check script for nagios.

The script queries the devices, rules and alarms via the librenms api, and then produces standard nagios output based on these and the arguments.

## INSTALL
```bash
$ wget -O /usr/local/bin/check_librenms_alerts.pl https://raw.githubusercontent.com/neszt/check-librenms-alerts/master/check_librenms_alerts.pl
$ chmod +x /usr/local/bin/check_librenms_alerts.pl
```
