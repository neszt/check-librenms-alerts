# check librenms alerts

This is a librenms alert check script for nagios.

The script queries the devices, rules and alarms via the librenms api, and then produces standard nagios output based on these and the arguments.

## INSTALL
```bash
$ wget -O /usr/local/bin/check_librenms_alerts.pl https://raw.githubusercontent.com/neszt/check-librenms-alerts/master/check_librenms_alerts.pl
$ chmod +x /usr/local/bin/check_librenms_alerts.pl
```

## USAGE
```
Usage: check_librenms_alerts.pl [OPTIONS...]

-h      librenms host (mandarory, eg.: https://librenms.org or http://librenms.org or librenms.org; defaults to https if not specified)
-s      skip ssl check (optional)
-t      token (mandatory, your api token - https://docs.librenms.org/API/#tokens)
-d      device_id filter (optional, comma separated device_ids, use negative ids to skip)
-r      rule_id filter (optional, comma separated rules_ids, use 'a' for all and negative ids to skip; default 'a')
-a      dump all data (optional, for debuging purposes)
-v      verbose level (0=none, 1=count info, 2=detailed info; default 1)
```
