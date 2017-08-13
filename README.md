
# check_oracle_cman
Oracle Connection Manager plugin for Nagios/Icinga

## Table of contents
- [Description](#description)
- [Installation](#installation)
- [Integration in your monitoring system](#integration-in-your-monitoring-system)
  * [NSClient++](#nsclient++)
  * [Icinga2](#icinga2)
- [Usage](#usage)

## Description
Plugin for monitoring Oracle Connection Manager

The following can be checked/monitored:
 * "version"     : returns the version of the installed CMAN
 * "connections" : returns the number of current connections through CMAN
 * "gateways"    : returns the state of each gateway and connection statistics per gateway
 * "services"    : returns the state of each service

## Installation
This plugin can be used in 2 ways:
 * from the monitoring server, connecting to the cmon service running on the cman server
 * from the cman server itself

I would recommend the second way, especially when using the icinga2 agent, as 
 * you would not have to open any special firewall rules for remote connections to the cmon service
 * you would not have to enable cman remote management

Some sudo settings need to be configured. Add a file /etc/sudoers.d/check_oracle_cman containing:
```
Defaults:icinga   !requiretty
icinga ALL=(oracle) NOPASSWD:SETENV: /u01/app/oracle/product/12.2.0/client_1/bin/cmctl
```

## Integration in your monitoring system

### NSClient++
Example:
```
; Script to check external scripts and/or internal aliases.
CheckExternalScripts.dll
[...]
[External Scripts]
[...]
check_oracle_cman=perl scripts\check_oracle_cman.pl --mode="$ARG1$" --environment="C:\oracle\client11g"
[...]
```

### Icinga2
 * Create a CheckCommand object named "oracle_cman" based on the content of the file icinga2_command_oracle_cman.cfg
 * Create a service using this CheckCommand, to be executed on the client side.

## Usage

```
  Usage: 
    
    * basic usage:
      $PROGNAME [-v] [-i <cman instance>] [-p <password>] -m <mode> [-e <oracle home>] [-b <cmctl binary>]
    
    * other usages:
      $PROGNAME [--help | -h | -?]
      $PROGNAME [--version | -V]
      $PROGNAME [--showdefaults | -D]

  General options:
    -v, --verbose
        print extra debugging information
    -h, -?, --help
        print this help message
    -V, --version
        prints version number
    -D, --showdefaults
        Print the option default values

  Plugin specific options:
    -i, --instance (optional)
        cman instance name. Should be set in case of remote admin connection (remote Cman)
    -p, --password (optional)
        administration password, in case it is set. 
    -m, --mode
        select the mode used for the check. Available modes are:
            * "version"     : returns the version of the installed CMAN
            * "connections" : returns the number of current connections through CMAN
            * "gateways"    : returns the state of each gateway and connection statistics per gateway
            * "services"    : returns the state of each service
    -w, --warning
        warning threshold for number of current connections
    -c, --critical
        critical threshold for number of current connections
    -e, --environment
        oracle home path, where the cmctl binary lives
    -b, --cmctl-binary
        path to the cmctl utility, if not in the ORACLE_HOME
```