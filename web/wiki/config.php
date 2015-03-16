<?php

require_once("localconfig.php");
require_once("utf8.php");

$datapath=$config[$conf]{"datapath"};
$perlcmd=$config[$conf]{"perlcmd"};
$bzcmd=$config[$conf]{"bzcmd"};
$parserpath=$config[$conf]{"parserpath"};


$installedlanguages=array();
foreach(glob("$datapath/*",GLOB_ONLYDIR) as $dir) {$installedlanguages[]=substr($dir,strrpos($dir,"/")+1);}

if (get_magic_quotes_gpc()) {$_GET = array_map('stripslashes', $_GET);}
$windowtitle="Wikipedia";
if(defined($_GET["debug"])) {$bDebug=true;}
if($bDebug) {error_reporting(E_ALL);} else {error_reporting(E_ERROR);}
$lang=$installedlanguages[0];
if(isset($_GET["lang"])) {foreach($installedlanguages as $l) {if($l == $_GET["lang"]) {$lang=$_GET["lang"];}}}

$imgpath="$datapath/$lang/img";

$DBFileTemplate="$datapath/$lang/bz2/rec%05d*";
$searchurlpattern="search.php?query=%s&lang=$lang";
$articleurlpattern="article.php?a=%s&lang=$lang";


if(count($installedlanguages)>1) {
	$selectbox="<select name='lang'>";
	foreach($installedlanguages as $l) {
		$selectbox.="<option value='$l'";
		if($l==$lang) {$selectbox.=" selected";}
		$selectbox.=">$l</option>";
	}
	$selectbox.="</select>";
}

$redirectstring="<li>redirect <a href=";


/**
 *           RiSearch PHP
 *
 * web search engine, version 0.2
 * (c) Sergej Tarasov, 2000-2004
 *
 * Homepage: http://risearch.org/
 * email: risearch@risearch.org
 */


#===================================================================
#
#         Set variables below
#
#===================================================================

# Directory where yours html files are located
# In most cases you may use path relative to the location of script
# Or use absolute path
# Type "./" for the current directory
$base_dir = ".";

# Base URL of your site
$base_url = "http://risearch.com/";
$indexseparator="#";

# site size
# 1 - Tiny    ~1Mb
# 2 - Medium  ~10Mb
# 3 - Big     ~50Mb
# 4 - Large   >100Mb
$site_size = 4;


# Path to index database files
$HASH      = "$datapath/$lang/db/0_hash";
$HASHWORDS = "$datapath/$lang/db/0_hashwords";
$FINFO     = "$datapath/$lang/db/0_finfo";
$SITEWORDS = "$datapath/$lang/db/0_sitewords";
$WORD_IND  = "$datapath/$lang/db/0_word_ind";

#===================================================================
#
#         These variables are used by spider
#
#===================================================================

# Starting URL (used by spider)
$start_url = array(
"http://risearch.com",
);

# Spider will index only files from these servers
$allow_url = array(
"http://risearch.com",
);

#===================================================================
#
#     All other variables are optional. Script should work fine
#  with default settings.
#     These variables controls the indexing process.
#
#===================================================================

# File extensions to index
# Add "NONE" if you want to index files without extensions
$file_ext = "html htm shtml txt pl php shtm";

# List of directories, which should not be indexed
$no_index_dir = "img image temp tmp html_docs";

# List of files, which should not be indexed
$no_index_files = 'robots.txt';

#minimum word length to index
$min_length = 3;

# Index or not numbers (set   $numbers = ""   if you don't want to index numbers)
# You may add here other non-letter characters, which you want to index
$numbers = '0-9';

# Parts of documents, which should not be indexed
# Uncomment and edit, if you want to use this feature
$use_selective_indexing = "NO";
$no_index_strings = array(
    "<!-- No index start 1 -->" => "<!-- No index end 1 -->",
    "<!-- No index start 2 -->" => "<!-- No index end 2 -->",
);


# Cut default filenames from URL ("YES" or "NO")
$cut_default_filenames = "YES";
$default_filenames = "index.htm index.html default.htm";

# Convert URL to lower case ("YES" or "NO")
$url_to_lower_case = 'NO';

# Indexing scheme
# Whole word - 1
# Beginning of the word - 2
# Every substring - 3
$INDEXING_SCHEME = 1;

# Translate escape chars (like &Egrave; or &#255;) ("YES" or "NO")
$use_esc = "YES";

# Index META tags ("YES" or "NO")
$use_META = "NO";


# List of stopwords ("YES" or "NO")
$use_stop_words = "YES";
$stop_words = "and any are but can had has have her here him his
how its not our out per she some than that the their them then there
these they was were what you";



#===================================================================
#
#     These variables controls the script output.
#
#===================================================================

# Number of results per page
$res_num = 25;

# Define length of page description in output
# and use META description ("YES") or first "n" characters of page ("NO")
$descr_size = 256;
$use_META_descr = "NO";


#===================================================================
#
#            --- end of configuration ---
#
# Please do not edit below this line unless you know what you do
#
#===================================================================


$HASHSIZE = 300001;

#===================================================================

function prepare_string($str) {
    $str = preg_replace ("/^\s+|\s+$/", "", $str);
    $str = preg_replace ("/\s+/", "|", $str);
    $str = preg_replace ("/\./", "\\\.", $str);
    $str = "(".$str.")";
    return $str;
}

function prepare_string_dir($str) {
    $str = preg_replace ("/(\S+)/", "/\\1$", $str);
    $str = preg_replace ("/^\s+|\s+$/", "", $str);
    $str = preg_replace ("/\s+/", "|", $str);
    $str = preg_replace ("/\./", "\\\.", $str);
    $str = "(".$str.")";
    return $str;
}

if (preg_match("/NONE/",$file_ext) ) {
    $file_ext = preg_replace ("/NONE/", "", $file_ext);
    $file_ext = prepare_string($file_ext);
    $file_ext = '(\.'.$file_ext.'|/[^.]+|/)($|\?)';
} else {
    $file_ext = prepare_string($file_ext);
    $file_ext = '(\.'.$file_ext.'|/)($|\?)';
}

$no_index_dir = prepare_string_dir($no_index_dir);

$no_index_files = prepare_string($no_index_files);

$default_filenames = prepare_string($default_filenames);
$default_filenames = '/'.$default_filenames.'$';

#===================================================================

    $stop_words = preg_replace("/\s+/s"," ",$stop_words);
    $pos = 0;
    do  {
        $new_pos = strpos($stop_words," ",$pos);
        if ($new_pos === FALSE) {
            $word = substr($stop_words,$pos);
            $stop_words_array[$word] = 1;
            break;
        };
        $word = substr($stop_words,$pos,$new_pos-$pos);
        $stop_words_array[$word] = 1;
        $pos = $new_pos+1;
    } while (1>0);

#===================================================================


    $html_esc = array(
        "&Agrave;" => chr(192),
        "&Aacute;" => chr(193),
        "&Acirc;" => chr(194),
        "&Atilde;" => chr(195),
        "&Auml;" => chr(196),
        "&Aring;" => chr(197),
        "&AElig;" => chr(198),
        "&Ccedil;" => chr(199),
        "&Egrave;" => chr(200),
        "&Eacute;" => chr(201),
        "&Eirc;" => chr(202),
        "&Euml;" => chr(203),
        "&Igrave;" => chr(204),
        "&Iacute;" => chr(205),
        "&Icirc;" => chr(206),
        "&Iuml;" => chr(207),
        "&ETH;" => chr(208),
        "&Ntilde;" => chr(209),
        "&Ograve;" => chr(210),
        "&Oacute;" => chr(211),
        "&Ocirc;" => chr(212),
        "&Otilde;" => chr(213),
        "&Ouml;" => chr(214),
        "&times;" => chr(215),
        "&Oslash;" => chr(216),
        "&Ugrave;" => chr(217),
        "&Uacute;" => chr(218),
        "&Ucirc;" => chr(219),
        "&Uuml;" => chr(220),
        "&Yacute;" => chr(221),
        "&THORN;" => chr(222),
        "&szlig;" => chr(223),
        "&agrave;" => chr(224),
        "&aacute;" => chr(225),
        "&acirc;" => chr(226),
        "&atilde;" => chr(227),
        "&auml;" => chr(228),
        "&aring;" => chr(229),
        "&aelig;" => chr(230),
        "&ccedil;" => chr(231),
        "&egrave;" => chr(232),
        "&eacute;" => chr(233),
        "&ecirc;" => chr(234),
        "&euml;" => chr(235),
        "&igrave;" => chr(236),
        "&iacute;" => chr(237),
        "&icirc;" => chr(238),
        "&iuml;" => chr(239),
        "&eth;" => chr(240),
        "&ntilde;" => chr(241),
        "&ograve;" => chr(242),
        "&oacute;" => chr(243),
        "&ocirc;" => chr(244),
        "&otilde;" => chr(245),
        "&ouml;" => chr(246),
        "&divide;" => chr(247),
        "&oslash;" => chr(248),
        "&ugrave;" => chr(249),
        "&uacute;" => chr(250),
        "&ucirc;" => chr(251),
        "&uuml;" => chr(252),
        "&yacute;" => chr(253),
        "&thorn;" => chr(254),
        "&yuml;" => chr(255),
        "&nbsp;" => " ",
        "&amp;" => " ",
        "&quote;" => " ",
    );

#=====================================================================
#
#    Function esc2char($str)
#    Last modified: 16.04.2004 18:22
#
#=====================================================================

function esc2char($str) {

    global $html_esc;

    $esc = $str[0];
    $char = "";

    if (preg_match ("/&[a-zA-Z]*;/", $esc)) {
        if (isset ($html_esc[$esc])) {
            $char = $html_esc[$esc];
        } else {
            $char = " ";
        }
    } elseif (preg_match ("/&#([0-9]*);/", $esc, $matches)) {
    	$char = chr($matches[1]);
    } elseif (preg_match ("/&#x([0-9a-fA-F]*);/", $esc, $matches)) {
    	$char = chr(hexdec($matches[1]));
    }
    return $char;
}
#=====================================================================




?>