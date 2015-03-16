<?php

require_once("config.php");
require_once("common_lib.php");

$query = isset($_GET["query"])?$_GET["query"]:$query;
$stpos = isset($_GET["stpos"])?$_GET["stpos"]:$stpos;
$stype = isset($_GET["stype"])?$_GET["stype"]:$stype;


#sanity tests
#chmod($bzcmd, 0755);
if(count($installedlanguages)==0) {
	printerror("Warning, no language found in folder $datapath");
}
if(strlen(shell_exec("$perlcmd --help 2>&1"))==0) {
	printerror("Cannot find Perl runtime in '$perlcmd'");
}
if(strlen(shell_exec("$bzcmd --help 2>&1"))==0) {
	printerror("Cannot find bzcat command in '$bzcmd'");
}



read_template("template.htm");


$abort = 0;
$query=urldecode($query);
$originalsearch=$query;

get_query();

if (count($query_arr) > 0) {
	$exact=scan_titles($originalsearch);
    get_results();
    boolean();
}


print print_template("header");

if (count($query_arr) > 0) {
#    if ($rescount==1) {
#    	#return single match
#
#    }
#    elsif ($rescount>0) {
    if ($rescount>0) {
    	if($exact) {
			foreach($exact as &$match) {$match=makelink(substr($match,0,strpos($match,'#')));}
    		$exactmatch = "Exact match".((count($match)>1)?"es":"").": ".join(" | ",$exact);
    	}

        print print_template("results_header");
        print print_results();
        print print_template("results_footer");
    } else {
        print print_template("no_results");
    }
} else {
    print print_template("empty_query");
}


print print_template("footer");

?>