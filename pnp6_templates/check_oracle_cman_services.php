<?php

#
# Pnp template for check_oracle_cman
# By Yannick Charton (tontonitch-pro@yahoo.fr)
#

#
# Performance data sample
#
# 'cmgw001_established'=377c 'cmgw001_refused'=0c 'cmgw001_current'=3;204.80;243.20;0;256 
# 'cmgw000_established'=593c 'cmgw000_refused'=0c 'cmgw000_current'=4;204.80;243.20;0;256 
# 'cmon_established'=282c 'cmon_refused'=0c 'cmon_current'=1;8.00;9.50;0;10
#

#
# Define some colors ..
#

$_WARNRULE  = '#FFFF00';
$_CRITRULE  = '#FF0000';
$_MAXRULE   = '#000000';
$_LINE      = '#000000';

#
# Define some variables ..
#
$for_check_command="check_oracle_cman.pl";

#
# Initial Logic ...
#

$last_handler="";
$num_graph_current=-1;
$num_current_global=0;
foreach($this->DS as $KEY => $VAL){
    $maximum  = "";
    $minimum  = "";
    $critical = "";
    $warning  = "";

    # Define the labels
    list($handler_name, $label) = preg_split("/_/", $VAL['NAME'], 2);
    if ($handler_name != $last_handler) {
        $num_graph_current += 2;
        $num_current_global += 2;
        $last_handler = $handler_name;
    }
    $label_c = rrd::cut($label, 20);

    # CMAN Connection Statistics
    if( preg_match('/current|max/', $label) == 1 ) {
        if(!isset($ds_name[$num_graph_current])){
            $ds_name[$num_graph_current] = "CMAN - Current connection statistics";
            $opt[$num_graph_current] = '--vertical-label "connections" -X0 --title "Current connection statistics - handler '.$handler_name.'" --rigid --lower=0';
            $opt[$num_graph_current] .= ' --watermark="Template for '.$for_check_command.' by Yannick Charton"';
            $def[$num_graph_current] = "";
        }
        $def[$num_graph_current] .= rrd::def     ("var$KEY", $VAL['RRDFILE'], $VAL['DS'], "AVERAGE");
        if (preg_match('/current/', $label)) {
            $def[$num_graph_current] .= rrd::area   ("var$KEY", '#8470FF', $label_c );
            $def[$num_graph_current] .= rrd::line1   ("var$KEY", '#696969');
            $def[$num_graph_current] .= rrd::gprint  ("var$KEY", array("LAST","MAX","AVERAGE"), "%8.1lf");
            if ($VAL['MAX'] != "")   {
                $maximum = $VAL['MAX'];
                $def[$num_graph_current] .= rrd::hrule( $maximum, "#003300", "Maximum at $maximum\\n" );
            }
            if ($VAL['WARN'] != "")   {
                $warning = $VAL['WARN'];
                $def[$num_graph_current] .= rrd::hrule( $warning, "#ffff00", "Warning at $warning\\n" );
            }
            if ($VAL['CRIT'] != "")   {
                $critical = $VAL['CRIT'];
                $def[$num_graph_current] .= rrd::hrule( $critical, "#ff0000", "Critical at $critical\\n" );
            }
        }
    } elseif(preg_match('/established|refused/', $label) == 1 ) {
        if(!isset($ds_name[$num_current_global])){
            $ds_name[$num_current_global] = "CMAN - Global connection statistics";
            $opt[$num_current_global] = '--vertical-label "connections/s" -X0 --alt-y-grid --title "Global connection statistics - handler '.$handler_name.'" --rigid --lower=0';
            $opt[$num_current_global] .= ' --watermark="Template for '.$for_check_command.' by Yannick Charton"';
            $def[$num_current_global] = "";
        }
        $def[$num_current_global] .= rrd::def     ("var$KEY", $VAL['RRDFILE'], $VAL['DS'], "AVERAGE");
        if (preg_match('/established/', $label)) {
            $def[$num_current_global] .= rrd::area    ("var$KEY", '#8FBC8F', $label_c );
            $def[$num_current_global] .= rrd::gprint  ("var$KEY", array("LAST","MAX","AVERAGE"), "%5.3lf c/s");
        }elseif (preg_match('/refused/', $label)) {
            $def[$num_current_global] .= rrd::area    ("var$KEY", '#DC143C', $label_c, 'STACK' );
            $def[$num_current_global] .= rrd::gprint  ("var$KEY", array("LAST","MAX","AVERAGE"), "%5.3lf c/s");
        }
    }
}

?>

