#!/usr/bin/perl -w
#
# ============================== SUMMARY =====================================
#
# Program : check_oracle_cman
# Version : 0.01
# Date    : January 05, 2011
# Author  : Yannick Charton - tontonitch-pro@yahoo.fr,
# Licence : GPL
#
# ============================================================================
# CMAN - Possible error messages:
# 'TNS-04077: WARNING: No password set for the Oracle Connection Manager instance.'
# 'TNS-04011: Oracle Connection Manager instance not yet started.'
# 'TNS-04049: Specified connections do not exist'
# ============================================================================

use strict;
use Getopt::Long;
use Data::Dumper;
use vars qw($PROGNAME);
use FindBin;
use lib "$FindBin::Bin";
use lib "$FindBin::Bin/lib";
use utils qw ($TIMEOUT %ERRORS &print_revision &support);

$PROGNAME       =   "check_oracle_cman.pl";
my $version     =   "0.01";
my $o_help      =   undef;
my $o_verbose   =   undef;
my $o_version   =   undef;
my $o_mode      =   undef;          # mode (can be "version", "connections", "gateways")
my $o_env       =   "/Oracle/product/10g";          # oracle home path
my $CMCTL       =   undef;
my %ERRORS      =   ('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);
my $TIMEOUT     =   10;

# ============================== FUNCTIONS ===================================

sub check_options {
    Getopt::Long::Configure ("bundling");
    GetOptions(
        'h'     => \$o_help,            'help'              => \$o_help,
        'v'     => \$o_verbose,         'verbose'           => \$o_verbose,
        'V'     => \$o_version,         'version'           => \$o_version,
        'm:s'   => \$o_mode,            'mode:s'            => \$o_mode,
        'e:s'   => \$o_env,             'environment:s'     => \$o_env,
    );
    if (defined($o_help))       { show_help(); exit $ERRORS{"UNKNOWN"}};
    if (defined($o_version))    { show_version(); exit $ERRORS{"UNKNOWN"}};
    # Oracle related variables
    $CMCTL              =   "$o_env/bin/cmctl";
    $ENV{'ORACLE_HOME'} =   "$o_env";
}

sub show_help {
    print <<EOT;

Oracle Connection Manager Monitor for Nagios/Icinga (check_oracle_cman) v. $version;
GPL licence, (c)2011 Yannick Charton

Usage: $0 [-v] -m <mode> [-e <oracle home>]

-v, --verbose
   print extra debugging information
-h, --help
   print this help message
-V, --version
   prints version number
-m, --mode
   select the mode used for the check. Available modes are:
    * "version"     : returns the version of the installed CMAN
    * "connections" : returns the number of current connections through CMAN
    * "gateways"    : returns the state of each gateway and connection statistics per gateway
-e, --environment
   oracle home path, where the emctl binary lives

EOT
}

sub show_version {
    print <<EOT;

Oracle Connection Manager Monitor for Nagios/Icinga (check_oracle_cman) v. $version;
GPL licence, (c)2011 Yannick Charton

EOT
}

# ================================ MAIN ======================================

check_options();

# Just in case of problems, let's not hang Nagios
$SIG{'ALRM'} = sub {
        print "UNKNOWN - Plugin Timed out\n";
        exit $ERRORS{"UNKNOWN"};
};
alarm($TIMEOUT);

# Go through the different modes
if ($o_mode eq "version") {
    my $cman_version = "";
    my $command = "show version";
    my @result = `$CMCTL $command`;
    chomp(@result);
    if ($o_verbose) {print Dumper(\@result);}
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
}elsif ($o_mode eq "connections") {
    my $number_of_connections = 0;
    my $command = "show connections";
    my @result = `$CMCTL $command`;
    chomp(@result);
    if ($o_verbose) {print Dumper(\@result);}
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
}elsif ($o_mode eq "gateways") {
    my $current_gateway_id = -1;
    my @gateway_state;
    my @nb_active_connections;
    my @peak_active_connections;
    my @total_connections;
    my @total_connections_refus;
    my $command = "show gateways";
    my @result = `$CMCTL $command`;
    chomp(@result);
    if ($o_verbose) {print Dumper(\@result);}
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
}else{
    print "UNKNOWN - Unknown mode\n";
    exit $ERRORS{"UNKNOWN"};
}

exit $ERRORS{"OK"};