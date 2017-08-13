#!/usr/bin/perl -w
# nagios: -epn

# ------------------------------------------------------------------------
#
# Program: check_oracle_cman
# Version: 1.1
# Author:  Yannick Charton - tontonitch-pro@yahoo.fr
# License: GPLv3
# Copyright (c) 2009-2017 Yannick Charton

# COPYRIGHT:
# This software and the additional scripts provided with this software are
# Copyright (c) 2009-2012 Yannick Charton (tontonitch-pro@yahoo.fr)
# (Except where explicitly superseded by other copyright notices)
#
# LICENSE:
# This work is made available to you under the terms of version 3 of
# the GNU General Public License. A copy of that license should have
# been provided with this software. 
# If not, see <http://www.gnu.org/licenses/>.
#
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# Nagios and the Nagios logo are registered trademarks of Ethan Galstad.
# ------------------------------------------------------------------------

# ------------------------------------------------------------------------
# CMAN - Possible error messages:
# 'TNS-04077: WARNING: No password set for the Oracle Connection Manager instance.'
# 'TNS-04011: Oracle Connection Manager instance not yet started.'
# 'TNS-04049: Specified connections do not exist'
# ------------------------------------------------------------------------

# ------------------------------------------------------------------------
# History:
# 03/08/2017 v1.1 Now uses sudo for CMAN 12.2 compatibility, to avoid the
#                 message TNS-12546: TNS:permission denied
# 11/03/2011 v1.0 Added "services" mode
# 05/01/2011 v0.1 Initial release
# ------------------------------------------------------------------------

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin";
use lib "$FindBin::Bin/lib";

use Data::Dumper;
  $Data::Dumper::Sortkeys = 1;
use Getopt::Long qw(:config no_ignore_case no_ignore_case_always bundling_override);
use utils qw(%ERRORS $TIMEOUT); # gather variables from utils.pm

# ========================================================================
# VARIABLES
# ========================================================================

# ------------------------------------------------------------------------
# global variable definitions
# ------------------------------------------------------------------------
use vars qw($PROGNAME $REVISION $CONTACT);
#use vars qw($PROGNAME $REVISION $CONTACT $TIMEOUT %ERRORS);
$PROGNAME       = $0;
$REVISION       = '1.1';
$CONTACT        = 'tontonitch-pro@yahoo.fr';
#$TIMEOUT        = 10;
#%ERRORS         = ('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);

# ------------------------------------------------------------------------
# Other global variables
# ------------------------------------------------------------------------
my %ghOptions = ();

# ========================================================================
# FUNCTION DECLARATIONS
# ========================================================================
sub check_options();

# ========================================================================
# MAIN
# ========================================================================

# Get command line options and adapt default values in %ghOptions
check_options();

# Just in case of problems, let's not hang Nagios
$SIG{'ALRM'} = sub {
        print "UNKNOWN - Plugin Timed out\n";
        exit $ERRORS{"UNKNOWN"};
};
alarm($TIMEOUT);

# Go through the different modes
if ($ghOptions{'mode'} eq "version") {
    my $cman_version = "";
    my $command = "show version";
    ($ghOptions{'instance'}) and $command .= " -c $ghOptions{'instance'}";
    ($ghOptions{'password'}) and $command .= " -p $ghOptions{'password'}";
    ($ghOptions{'verbose'}) and print "execute: sudo -u oracle ORACLE_HOME=$ghOptions{'environment'} $ghOptions{'cman_binary'} $command\n";
    my @result = `sudo -u oracle ORACLE_HOME=$ghOptions{'environment'} $ghOptions{'cman_binary'} $command`;
    chomp(@result);
    ($ghOptions{'verbose'}) and print "result:\n".Dumper(\@result);
    foreach my $line (@result) {
        if (($line =~ /^TNS-/) && ! ($line =~ /^TNS-04077/)) {
            print "WARNING - $line\n";
            exit $ERRORS{"WARNING"};
        }
        elsif($line =~ /^CMAN for /i) {
            $cman_version = "$line";
        }
    }
    if($cman_version) {
        print "Ok - $cman_version\n";
    }else{
        print "Warning - Cannot find the version\n";
        exit $ERRORS{"WARNING"};
    }
}elsif ($ghOptions{'mode'} eq "connections") {
    my $number_of_connections = 0;
    my $command = "show connections";
    ($ghOptions{'instance'}) and $command .= " -c $ghOptions{'instance'}";
    ($ghOptions{'password'}) and $command .= " -p $ghOptions{'password'}";
    ($ghOptions{'verbose'}) and print "execute: sudo -u oracle ORACLE_HOME=$ghOptions{'environment'} $ghOptions{'cman_binary'} $command\n";
    my @result = `sudo -u oracle ORACLE_HOME=$ghOptions{'environment'} $ghOptions{'cman_binary'} $command`;
    chomp(@result);
    ($ghOptions{'verbose'}) and print "result:\n".Dumper(\@result);
    foreach my $line (@result) {
        if (($line =~ /^TNS-/) && ! ($line =~ /^TNS-04077/) && ! ($line =~ /^TNS-04049/)) {
            print "WARNING - $line\n";
            exit $ERRORS{"WARNING"};
        }
        elsif ($line =~ /^TNS-04049/) {
            $number_of_connections = 0;
        }
        elsif ($line =~ /^Number of connections: /) {
            if ($line =~ m/(\d+)/) {
                 $number_of_connections = $1;
            }
        }
    }
    print "Ok - Number of connections: $number_of_connections | 'current_connexions'=$number_of_connections\n";
}elsif ($ghOptions{'mode'} eq "gateways") {
    my $current_gateway_id = -1;
    my @gateway_state;
    my @nb_active_connections;
    my @peak_active_connections;
    my @total_connections;
    my @total_connections_refus;
    my $command = "show gateways";
    ($ghOptions{'instance'}) and $command .= " -c $ghOptions{'instance'}";
    ($ghOptions{'password'}) and $command .= " -p $ghOptions{'password'}";
    ($ghOptions{'verbose'}) and print "execute: sudo -u oracle ORACLE_HOME=$ghOptions{'environment'} $ghOptions{'cman_binary'} $command\n";
    my @result = `sudo -u oracle ORACLE_HOME=$ghOptions{'environment'} $ghOptions{'cman_binary'} $command`;
    chomp(@result);
    ($ghOptions{'verbose'}) and print "result:\n".Dumper(\@result);
    foreach my $line (@result) {
        if (($line =~ /^TNS-/) && ! ($line =~ /^TNS-04077/)) {
            print "WARNING - $line\n";
            exit $ERRORS{"WARNING"};
        }
        elsif($line =~ /^Gateway ID/) {
            $current_gateway_id++;
        }
        elsif ($line =~ /^Gateway state/) {
            if ($line =~ m/^Gateway state\s*(\w+)/) {
                 $gateway_state[$current_gateway_id] = $1;
            }
        }
        elsif ($line =~ /^Number of active connections/) {
            if ($line =~ m/^Number of active connections\s*(\d+)/) {
                 $nb_active_connections[$current_gateway_id] = $1;
            }
        }
        elsif ($line =~ /^Peak active connections/) {
            if ($line =~ m/^Peak active connections\s*(\d+)/) {
                 $peak_active_connections[$current_gateway_id] = $1;
            }
        }
        elsif ($line =~ /^Total connections refused/) {
            if ($line =~ m/^Total connections refused\s*(\d+)/) {
                 $total_connections_refus[$current_gateway_id] = $1;
            }
        }
        elsif ($line =~ /^Total connections/) {
            if ($line =~ m/^Total connections\s*(\d+)/) {
                 $total_connections[$current_gateway_id] = $1;
            }
        }
    }
    if($current_gateway_id > -1) {
        my $nb_gateways = $current_gateway_id + 1;
        my $bad_state_found = 0;
        my $info = "$nb_gateways gateway(s), ";
        for (my $i=0; $i<$nb_gateways;$i++) {
            $info .= "$i:$gateway_state[$i] ";
            unless ($gateway_state[$i] eq "READY") {
                $bad_state_found++;
            }
        }
        my $perfstat = "";
        for (my $i=0; $i<$nb_gateways;$i++) {
            $perfstat .= "'${i}_nb_active_connections'=$nb_active_connections[$i] ";
            $perfstat .= "'${i}_peak_active_connections'=$peak_active_connections[$i] ";
            $perfstat .= "'${i}_total_connections'=$total_connections[$i]c ";
            $perfstat .= "'${i}_total_connections_refus'=$total_connections_refus[$i]c ";
        }
        if ($bad_state_found == 0) {
            print "Ok - $info| $perfstat\n";
        } else {
            print "Warning - $info| $perfstat\n";
        }
    }else{
        print "Warning - Problem while searching for the gateway statistics\n";
        exit $ERRORS{"WARNING"};
    }
}elsif($ghOptions{'mode'} eq "services") {
    my $current_handler_id = -1;
    my @handler_name;
    my @connections_established;
    my @connections_refused;
    my @connections_current;
    my @connections_max;
    my @connections_state;
    my $command = "show services";
    ($ghOptions{'instance'}) and $command .= " -c $ghOptions{'instance'}";
    ($ghOptions{'password'}) and $command .= " -p $ghOptions{'password'}";
    ($ghOptions{'verbose'}) and print "execute: sudo -u oracle ORACLE_HOME=$ghOptions{'environment'} $ghOptions{'cman_binary'} $command\n";
    my @result = `sudo -u oracle ORACLE_HOME=$ghOptions{'environment'} $ghOptions{'cman_binary'} $command`;
    chomp(@result);
    ($ghOptions{'verbose'}) and print "result:\n".Dumper(\@result);
    foreach my $line (@result) {
        if (($line =~ /^TNS-/) && ! ($line =~ /^TNS-04077/)) {
            print "WARNING - $line\n";
            exit $ERRORS{"WARNING"};
        }
        elsif($line =~ /^\s*"cm.*" established/) {
            $current_handler_id++;
            # ex: "cmgw003" established:16 refused:0 current:1 max:256 state:ready
            if ($line =~ m/"(cm.*)"\sestablished:(\d+)\srefused:(\d+)\scurrent:(\d+)\smax:(\d+)\sstate:(\w+)$/) {
                 $handler_name[$current_handler_id] = $1;
                 $connections_established[$current_handler_id] = $2;
                 $connections_refused[$current_handler_id] = $3;
                 $connections_current[$current_handler_id] = $4;
                 $connections_max[$current_handler_id] = $5;
                 $connections_state[$current_handler_id] = $6;
            }
        }
    }
    if($current_handler_id > -1) {
        my $nb_services = $current_handler_id + 1;
        my $info = "$nb_services service(s), ";
        my $info_warn = "";
        my $info_crit = "";
        my $perfstat = "";
        
        for (my $i=0; $i<$nb_services;$i++) {
            $info .= "$handler_name[$i]:$connections_state[$i] ";
            unless ($connections_state[$i] eq "ready") {
                $info_crit = "$handler_name[$i]:$connections_state[$i] ";
            }
            my $connections_current_critical = sprintf("%.2f", $ghOptions{'critical'}/100*$connections_max[$i]);
            my $connections_current_warning = sprintf("%.2f", $ghOptions{'warning'}/100*$connections_max[$i]);
            my $connections_current_prct = sprintf("%.2f", $connections_current[$i]/$connections_max[$i]*100);
            if ($connections_current[$i] > $connections_current_critical) {
                $info_crit = "$handler_name[$i]: $connections_current[$i] connections ($connections_current_prct%, [>".$ghOptions{'critical'}."%]) ";
            } elsif ($connections_current[$i] > $connections_current_warning) {
                $info_warn = "$handler_name[$i]: $connections_current[$i] connections ($connections_current_prct%, [>".$ghOptions{'warning'}."%]) ";
            }
            # perfdata
            $perfstat .= "'$handler_name[$i]_established'=$connections_established[$i]c ";
            $perfstat .= "'$handler_name[$i]_refused'=$connections_refused[$i]c ";
            $perfstat .= "'$handler_name[$i]_current'=$connections_current[$i];$connections_current_warning;$connections_current_critical;0;$connections_max[$i] ";
        }
        if ($info_crit) {
            print "CRITICAL - ${info_crit}${info_warn}| $perfstat\n";
            exit $ERRORS{"CRITICAL"};
        } elsif ($info_warn) {
            print "WARNING - $info_warn| $perfstat\n";
            exit $ERRORS{"WARNING"};
        } else {
            print "OK - $info| $perfstat\n";
            exit $ERRORS{"OK"};
        }
    }else{
        print "WARNING - Problem while searching for the gateway statistics\n";
        exit $ERRORS{"WARNING"};
    }
}else{
    print "UNKNOWN - Unknown mode\n";
    exit $ERRORS{"UNKNOWN"};
}

exit $ERRORS{"OK"};


# ========================================================================
# MAIN ENDS HERE
# ========================================================================

# ========================================================================
# FUNCTIONS
# ========================================================================
# List:
# * print_usage
# * print_help
# * print_defaults
# * print_revision
# * support
# * check_options
# ========================================================================

# ------------------------------------------------------------------------
# various functions reporting plugin information & usages
# ------------------------------------------------------------------------
sub print_usage () {
  print <<EOUS;
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

EOUS
}
sub print_defaults () {
  print "\nDefault option values:\n";
  print "----------------------\n\n";
  print Dumper(\%ghOptions);
  }
sub print_help () {
  print "Copyright (c) 2009-2017 Yannick Charton\n\n";
  print "\n";
  print "Oracle Connection Manager plugin for Nagios/Icinga ($PROGNAME) v. $REVISION";
  print "\n";
  print_usage();
  support();
}
sub print_revision ($$) {
  my $commandName = shift;
  my $pluginRevision = shift;
  $pluginRevision =~ s/^\$Revision: //;
  $pluginRevision =~ s/ \$\s*$//;
  print "$commandName ($pluginRevision)\n";
  print "This nagios plugin comes with ABSOLUTELY NO WARRANTY. You may redistribute\ncopies of this plugin under the terms of the GNU General Public License version 3 (GPLv3).\n";
}
sub support () {
  my $support='Send email to tontonitch-pro@yahoo.fr if you have questions\nregarding the use of this plugin. \nPlease include version information with all correspondence (when possible,\nuse output from the -V option of the plugin itself).\n';
  $support =~ s/@/\@/g;
  $support =~ s/\\n/\n/g;
  print $support;
}

# ------------------------------------------------------------------------
# command line options processing
# ------------------------------------------------------------------------
sub check_options () {
    my %commandline = ();
    my @params = (
        #------- general options --------#
        'help|h|?',
        'verbose|v+',
        'version|V',
        'showdefaults|D',                       # print all option default values
        #--- plugin specific options ----#
        'instance|i=s',                         # cman instance name
        'password|p=s',                         # administration password
        'mode|m=s',                             # mode used for the check
        'warning|w=i',                          # warning threshold for number of current connections
        'critical|c=i',                         # critical threshold for number of current connections
        'environment|e=s',                      # ORACLE_HOME path
        'cman_binary|b=s',                      # path to the cmctl binary
        );
    
    # gathering commandline options
    if (! GetOptions(\%commandline, @params)) {
        print_help();
        exit $ERRORS{UNKNOWN};
    }
    
    #====== Configuration hashes ======#
    # Default values: general options
    %ghOptions = (
        #------- general options --------#
        'help'                      => 0,
        'verbose'                   => 0,
        'version'                   => 0,
        'showdefaults'              => 0,
        #--- plugin specific options ----#
        'instance'                  => "",
        'password'                  => "",
        'mode'                      => "",
        'warning'                   => 80,
        'critical'                  => 95,
        'environment'               => "/Oracle/product/11g",
        'cman_binary'               => "/Oracle/product/11g/bin/cmctl",
    );

    ### mandatory commandline options: mode
    # applying commandline options
    
    #------- general options --------#
    if (exists $commandline{verbose}) {
        $ghOptions{'verbose'} = $commandline{verbose};
    }
    if (exists $commandline{version}) {
        print_revision($PROGNAME, $REVISION);
        exit $ERRORS{OK};
    }
    if (exists $commandline{help}) {
        print_help();
        exit $ERRORS{OK};
    }
    if (exists $commandline{showdefaults}) {
        print_defaults();
        exit $ERRORS{OK};
    }
    
    #--- plugin specific options ----#
    if (exists $commandline{timeout}) {
        $ghOptions{'timeout'} = $commandline{timeout};
        $TIMEOUT = $ghOptions{'timeout'};
    }
    if (exists $commandline{instance}) {
        $ghOptions{'instance'} = "$commandline{instance}";
    }
    if (exists $commandline{password}) {
        $ghOptions{'password'} = "$commandline{password}";
    }
    if (exists $commandline{environment}) {
        $ghOptions{'environment'} = "$commandline{environment}";
        $ghOptions{'cman_binary'} = "$commandline{environment}/bin/cmctl";
    }
    if (exists $commandline{cman_binary}) {
        $ghOptions{'cman_binary'} = "$commandline{cman_binary}";
    }
    if (! exists $commandline{mode}) {
        print "mode not defined (-m)\n\n";
        print_help();
        exit $ERRORS{UNKNOWN};
    } else {
        if ($commandline{mode} =~ /^version$|^connections$|^gateways$|^services$/) {
            $ghOptions{'mode'} = "$commandline{mode}";
        } else {
            print "UNKNOWN - Unknown mode \"$commandline{mode}\"\n";
            exit $ERRORS{"UNKNOWN"};
        }
    }
    if (exists $commandline{warning}) {
        $ghOptions{'warning'} = "$commandline{warning}";
    }
    if (exists $commandline{critical}) {
        $ghOptions{'critical'} = "$commandline{critical}";
    }
    
    # Export to env
    $ENV{'ORACLE_HOME'} = "$ghOptions{'environment'}";
    
    # print the options in command line, and the resulting full option hash
    $ghOptions{'verbose'} and print "commandline: \n".Dumper(\%commandline)."\n";
    $ghOptions{'verbose'} and print "options: \n".Dumper(\%ghOptions)."\n";
}    

