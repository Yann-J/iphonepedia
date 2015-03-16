<?php
$stpos = 0;
$stype = "AND";
$query = "";

/**
 *           RiSearch PHP
 *
 * web search engine, version 0.2
 * (c) Sergej Tarasov, 2000-2004
 *
 * Homepage: http://risearch.org/
 * email: risearch@risearch.org
 */

require_once("config.php");



#=====================================================================
#
#    Function risearch_hash($key)
#    Last modified: 16.04.2004 17:54
#
#=====================================================================

function risearch_hash($key) {
    $chars = str_split($key);
    for($i=0;$i<count($chars);$i++) {
        $chars2[$i] = ord($chars[$i]);
    }

    $h = hexdec("00000000");
    $f = hexdec("0F000000");

    for($i=0;$i<count($chars);$i++) {
		$h = ($h << 4) + $chars2[$i];
        if ($g = $h & $f) { $h ^= $g >> 24; };
        $h &= ~$g;
    }

    return $h;

}
#=====================================================================
#
#    Function getmicrotime()
#    Last modified: 16.04.2004 17:54
#
#=====================================================================

function getmicrotime(){
    list($usec, $sec) = explode(" ",microtime());
    return ((float)$usec + (float)$sec);
}
#=====================================================================
#
#    Function get_META_info($html)
#    Last modified: 07.05.2005 0:03
#
#=====================================================================

function get_META_info($html) {

    preg_match("/<\s*[Mm][Ee][Tt][Aa]\s*[Nn][Aa][Mm][Ee]=\"?[Kk][Ee][Yy][Ww][Oo][Rr][Dd][Ss]\"?\s*[Cc][Oo][Nn][Tt][Ee][Nn][Tt]=\"?([^\"]*)\"?\s*\/?>/s",$html,$matches);
    $res[0] = @$matches[1];
    preg_match("/<\s*[Mm][Ee][Tt][Aa]\s*[Nn][Aa][Mm][Ee]=\"?[Dd][Ee][Ss][Cc][Rr][Ii][Pp][Tt][Ii][Oo][Nn]\"?\s*[Cc][Oo][Nn][Tt][Ee][Nn][Tt]=\"?([^\"]*)\"?\s*\/?>/s",$html,$matches);
    $res[1] = @$matches[1];

    return $res;
}
#=====================================================================
#
#    Function index_file($html_text,$url)
#    Last modified: 15.07.2004 11:35
#
#=====================================================================

function index_file($textindex,$url) {

    global $cfn, $kbcount, $descr_size, $min_length, $stop_words_array, $use_esc;
    global $use_selective_indexing, $no_index_strings;
    global $use_META, $use_META_descr;
    global $fp_FINFO;
    global $words;
    global $numbers;

    $cfn++;
    $size = strlen($textindex);
    $kbcount += intval($size/1024);
    #print "$cfn -> $url; totalsize -> $kbcount kb<BR>\n";


    $title = "";
    $keywords = "";
    $description = "";

    $textindex = preg_replace("/[^a-zA-Zà-ÿÀ-ß$numbers -]/"," ",$textindex);
    $textindex = preg_replace("/\s+/s"," ",$textindex);
    $textindex = strtolower($textindex);

    $words_temp = array();

    $pos = 0;
    do  {
        $new_pos = strpos($textindex," ",$pos);
        if ($new_pos === FALSE) {
            $word = substr($textindex,$pos);
            $words_temp[$word] = 1;
            break;
        };
        $word = substr($textindex,$pos,$new_pos-$pos);
        $words_temp[$word] = 1;
        $pos = $new_pos+1;
    } while (1>0);



    $pos = ftell($fp_FINFO);
    $pos = pack("N",$pos);
    fwrite($fp_FINFO, "$url\x0A");

    foreach($words_temp as $word => $val) {
        if (strlen($word) < $min_length) { continue; }
        if (array_key_exists($word,$stop_words_array)) { continue; }
        @$words[$word] .= $pos;

        #print "$word => ".$words[$word]."\n";
    }


    unset($words_temp);
    unset($words_temp2);

}
#=====================================================================
#
#    Function build_hash()
#    Last modified: 16.04.2004 17:54
#
#=====================================================================

function build_hash() {

    global $words;
    global $HASHSIZE, $INDEXING_SCHEME, $HASH, $HASHWORDS;


    for ($i=0; $i<$HASHSIZE; $i++) {$hash_array[$i] = "";};

    foreach($words as $word=>$value) {
        if ($INDEXING_SCHEME == 3) { $subbound = strlen($word)-3; }
        else { $subbound = 1; }
        if (strlen($word)==3) {$subbound = 1;}
        $substring_length = 4;
        if ($INDEXING_SCHEME == 1) { $substring_length = strlen($word); }

        for ($i=0; $i<$subbound; $i++){
            $hash_value = abs(risearch_hash(substr($word,$i,$substring_length)) % $HASHSIZE);
    	    $hash_array[$hash_value] .= $value;

    	    #print "WORD: $word\n";
    	    #print "KEY: $hash_value\n";
    	    #print $hash_array[$hash_value]."\n";
    	    #print "VALUE: $value\n\n\n";
    	   };

    }



    $fp_HASH = fopen ("$HASH", "wb") or die("Can't open index file!");
    $fp_HASHWORDS = fopen ("$HASHWORDS", "wb") or die("Can't open index file!");

    $zzz = pack("N", 0);
    fwrite($fp_HASHWORDS, $zzz);
    $pos_hashwords = ftell($fp_HASHWORDS);
    $to_print_hash = "";
    $to_print_hashwords = "";

    for ($i=0; $i<$HASHSIZE; $i++){
		$elt=$hash_array[$i];
        if ($elt == "") {$to_print_hash .= $zzz;};
        if ($elt != "") {
        	print "$i not empty";
            $to_print_hash .= pack("N",$pos_hashwords + strlen($to_print_hashwords));
            $to_print_hashwords .= pack("N", strlen($elt)/8).$elt;
            #print "$i\n";
            #print "$to_print_hash\n";
            #print "$to_print_hashwords\n\n\n";
        }
        if (strlen($to_print_hashwords) > 64000) {
            fwrite($fp_HASH,$to_print_hash);
            fwrite($fp_HASHWORDS,$to_print_hashwords);
            $to_print_hash = "";
            $to_print_hashwords = "";
            $pos_hashwords  = ftell($fp_HASHWORDS);
        }
    }; # for $i
    fwrite($fp_HASH,$to_print_hash);
    fwrite($fp_HASHWORDS,$to_print_hashwords);


fclose($fp_HASH);
fclose($fp_HASHWORDS);


}
#=====================================================================



#=====================================================================
#
#    Function get_query()
#    Last modified: 25.08.2005 22:04
#
#=====================================================================

function get_query() {

    global $query, $stpos, $stype, $query_arr, $wholeword, $querymode, $stop_words_array;
    global $min_length;
    global $numbers;

	$query = PlainAscii($query);
    $query_arr_dum = explode(" ",$query);

    foreach($query_arr_dum as $word) {
        if (strlen($word) < $min_length) { continue; }
        if (array_key_exists($word,$stop_words_array)) { continue; }
        $query_arr[] = $word;
    }

    for ($i=0; $i<count($query_arr); $i++) {
	    echodebug("word: $query_arr[$i]");
        $wholeword[$i] = 0;
        $querymode[$i] = 2;
/*        if (preg_match("/\!/", $query_arr[$i]))   { $wholeword[$i] = 1;} # WholeWord
        $query_arr[$i] = preg_replace("/[\! ]/","",$query_arr[$i]);
        if ($stype == "AND")     { $querymode[$i] = 2;} # AND
        if (preg_match ("/^\-/", $query_arr[$i])) { $querymode[$i] = 1;} # NOT
        if (preg_match ("/^\+/", $query_arr[$i])) { $querymode[$i] = 2;} # AND
        $query_arr[$i] = preg_replace("/^[\+\- ]/","",$query_arr[$i]);
*/    }


    if ($stpos <0) {$stpos = 0;};

}
#=====================================================================
#
#    Function get_results()
#    Last modified: 10.05.2004 18:43
#
#=====================================================================

function get_results() {

    global $HASHSIZE, $INDEXING_SCHEME, $HASH, $HASHWORDS, $FINFO, $SITEWORDS, $WORD_IND;

    global $query_arr, $wholeword, $querymode;
    global $res, $allres, $rescount, $query_statistics;


    $fp_HASH = fopen ("$HASH", "rb") or die("No index file is found! Please run indexing script again.");
    $fp_HASHWORDS = fopen ("$HASHWORDS", "rb") or die("No index file is found! Please run indexing script again.");
    $fp_SITEWORDS = fopen ("$SITEWORDS", "rb") or die("No index file is found! Please run indexing script again.");
    $fp_WORD_IND = fopen ("$WORD_IND", "rb") or die("No index file is found! Please run indexing script again.");

for ($j=0; $j<count($query_arr); $j++) {
    $query = $query_arr[$j];
    $allres[$j] = array();

    if ($INDEXING_SCHEME == 1) {
    	$substring_length = strlen($query);
    } else {
    	$substring_length = 4;
    }
    $hash_value = abs(risearch_hash(substr($query,0,$substring_length)) % $HASHSIZE);

    fseek($fp_HASH,$hash_value*4,0);
    $dum = fread($fp_HASH,4);
    $dum = unpack("Ndum", $dum);
    fseek($fp_HASHWORDS,$dum['dum'],0);
    $dum = fread($fp_HASHWORDS,4);
    $dum1 = unpack("Ndum", $dum);

    for ($i=0; $i<$dum1['dum']; $i++) {
        $dum = fread($fp_HASHWORDS,8);
        $arr_dum = unpack("Nwordpos/Nfilepos",$dum);
        fseek($fp_SITEWORDS,$arr_dum['wordpos'],0);
        $word = fgets($fp_SITEWORDS,1024);
        $word = str_replace("/\x0A/","",$word);
        $word = str_replace("/\x0D/","",$word);

        if ( ($wholeword[$j]==1) && ($word != $query) ) {$word = "";};
        $pos = strpos($word, $query);
        if ($pos !== false) {
            fseek($fp_WORD_IND,$arr_dum['filepos'],0);
            $dum = fread($fp_WORD_IND,4);
            $dum2 = unpack("Ndum",$dum);
            $dum = fread($fp_WORD_IND,$dum2['dum']*4);
            for($k=0; $k<$dum2['dum']; $k++){
                $zzz = unpack("Ndum",substr($dum,$k*4,4));
                $allres[$j][$zzz['dum']] = 1;
            }
        }

    };


}


    for ($j=0; $j<count($query_arr); $j++) {
    	$found_number = count($allres[$j]);
        $query_statistics .= " $query_arr[$j]-$found_number\n";
    }


}
#=====================================================================
#
#    Function boolean()
#    Last modified: 10.05.2004 18:43
#
#=====================================================================

function boolean() {

    global $query_arr, $querymode, $stype;
    global $res, $allres, $rescount;

if (count($query_arr) == 1) {
    foreach ($allres[0] as $k => $v) {
        if ($k) {
            $res .= pack("N",$k);
        }
    }
    $rescount = intval(strlen($res)/4);
    unset($allres);
    return;
} else {

$min=0;
    if ($stype == "AND") {
        for ($i=0; $i<count($query_arr); $i++) {
            if ($querymode[$i] == 2) {
                $min = $i;
                break;
            }
        }
        for ($i=$min+1; $i<count($query_arr); $i++) {
            if (count($allres[$i]) < count($allres[$min]) && $querymode[$i] == 2) {
                $min = $i;
            }
        }
        for ($i=0; $i<count($query_arr); $i++) {
            if ($i == $min) {
                continue;
            }
            if ($querymode[$i] == 2) {
                foreach ($allres[$min] as $k => $v) {
                    if (array_key_exists($k,$allres[$i])) {
                    } else {
                        unset($allres[$min][$k]);
                    }
                }
            } else {
                foreach ($allres[$min] as $k => $v) {
                    if (array_key_exists($k,$allres[$i])) {
                        unset($allres[$min][$k]);
                    }
                }
            }
        }
        foreach ($allres[$min] as $k => $v) {
            if ($k) {
                $res .= pack("N",$k);
            }
        }
        $rescount = intval(strlen($res)/4);
        return;
    }


    if ($stype == "OR") {
        for ($i=0; $i<count($query_arr); $i++) {
            if ($querymode[$i] != 1) {
                $max = $i;
                break;
            }
        }
        for ($i=$max+1; $i<count($query_arr); $i++) {
            if (count($allres[$i]) > count($allres[$max]) && $querymode[$i] != 1) {
                $max = $i;
            }
        }
        for ($i=0; $i<count($query_arr); $i++) {
            if ($i == $max) {
                continue;
            }
            if ($querymode[$i] != 1) {
                foreach ($allres[$i] as $k => $v) {
                    $allres[$max][$k] = 1;
                }
            } else {
                foreach ($allres[$i] as $k => $v) {
                    if (array_key_exists($k,$allres[$max])) {
                        unset($allres[$max][$k]);
                    }
                }
            }
        }
        foreach ($allres[$max] as $k => $v) {
            if ($k) {
                $res .= pack("N",$k);
            }
        }
        $rescount = intval(strlen($res)/4);
        return;
    }

}


}
#=====================================================================
#
#    Function print_results()
#    Last modified: 16.04.2004 17:54
#
#=====================================================================

function print_results() {

    global $FINFO, $FINFO_IND, $query, $stpos, $stype, $res_num, $res;
    global $url, $title, $size, $description, $rescount, $next_results;
    global $query_arr;
    global $searchurlpattern;

    $time1 = getmicrotime();

    $output="";

    $fp_FINFO = fopen ("$FINFO", "rb") or die("No index file is found! Please run indexing script again.");

    for ($i=$stpos; $i<$stpos+$res_num; $i++) {
        if ($i >= strlen($res)/4) {break;};
        $strpos = unpack("Npos",substr($res,$i*4,4));
        fseek($fp_FINFO,$strpos['pos'],0);
        $dum = fgets($fp_FINFO,4024);
        $url=$dum;
        for ($j=0; $j<count($query_arr); $j++) {
            $tquery = $query_arr[$j];
        }
        $sep=strpos($url,'#');
		if($sep>0) {$url=substr($url,0,$sep);}


		$url=html_entity_decode($url);
        echodebug($url);
        $output .= print_template("results");
    };  # for



    if ($rescount <= $res_num) {$next_results = ""; return $output;}


    $mhits = 20 * $res_num;
    $pos2 = $stpos - $stpos % $mhits;
    $pos1 = $pos2 - $mhits;
    $pos3 = $pos2 + $mhits;

    if ($pos1 < 0) { $prev = ""; }
    else {
        $prev = " <A HREF=".sprintf($searchurlpattern,urlencode($query))."&stpos=".$pos1;
        $prev .= ">PREV</A> \n";
    }

    if ($pos3 > $rescount) { $next = ""; }
    else {
        $next = " <A HREF=".sprintf($searchurlpattern,urlencode($query))."&stpos=".$pos3;
        $next .= ">NEXT</A> \n";
    }

    $next_results .= $prev;
    $next_results .=  " |\n";
    for ($i=$pos2; $i<$pos3; $i += $res_num) {
       if ($i >= $rescount) {break;}
       $page_number = $i/$res_num+1;
       if ( $i != $stpos ) {
           $next_results .=  "<A HREF=".sprintf($searchurlpattern,urlencode($query))."&stpos=".$i;
           $next_results .=  ">".$page_number."</A> |\n";
       } else {
           $next_results .=  $page_number." |\n";
       }
    }
    $next_results .=  $next;

	return $output;

}
#=====================================================================
#
#    Function read_template($filename)
#    Last modified: 16.04.2004 17:54
#
#=====================================================================

function read_template($filename) {

$size = filesize($filename);
$fd = @fopen ($filename, "rb") or die("Template file is not found!");
$template = fread ($fd, $size);
fclose ($fd);

global $templates;

    $count = preg_match_all("/<!-- RiSearch::([^:]+?)::start -->(.*?)<!-- RiSearch::\\1::end -->/s", $template, $matches, PREG_SET_ORDER);
    for($i=0; $i < count($matches); $i++) {
        $templates[$matches[$i][1]] = $matches[$i][2];
    }

}
#=====================================================================
#
#    Function print_template($part)
#    Last modified: 16.04.2004 17:54
#
#=====================================================================

function print_template($part) {

    global $templates;
    global $query, $search_time, $query_statistics, $stpos, $url, $title, $size, $description, $rescount, $next_results,$exactmatch,$windowtitle,$selectbox;
    $template = $templates[$part];


    $template = str_replace("%query%","$query",$template);
    $template = str_replace("%search_time%","$search_time",$template);
    $template = str_replace("%query_statistics%","$query_statistics",$template);
    $template = str_replace("%stpos%",$stpos+1,$template);
    $template = str_replace("%url%",makehref($url),$template);
    $template = str_replace("%title%",maketitle($url),$template);
    $template = str_replace("%size%","$size",$template);
    $template = str_replace("%description%","$description",$template);
    $template = str_replace("%rescount%","$rescount",$template);
    $template = str_replace("%next_results%","$next_results",$template);
    $template = str_replace("%exactmatch%","$exactmatch",$template);
    $template = str_replace("%selectbox%","$selectbox",$template);
    $template = str_replace("%windowtitle%","$windowtitle",$template);

    return $template;
}
#===================================================================

function makelink($url) {
	return "<a href='".makehref($url)."'>".maketitle($url)."</a>";
}

function makehref($url) {
	global $articleurlpattern;

	return sprintf($articleurlpattern,urlencode($url));
}

function maketitle($url) {
	return htmlentities($url,ENT_COMPAT,"UTF-8");
}

function DBLookup($article) {
	$matches=scan_titles($article);
	if($matches) {
		echodebug("Found ".count($matches)." matches.");

		foreach($matches as $match) {
			$db=explode("#",$match);
			if(count($matches)==1 || strcmp($article,$db[0])==0) {return $db;}
		}

		#if no exact case match but ony one match, we still return it
		if(count($matches)==1) {return $matches[0];}
	}

	return null;
}


function scan_titles($title) {
	global $FINFO;

    $fp_FINFO = fopen ($FINFO, "rb") or die("No index file is found! Please run indexing script again.");

	$low=0;
	$high=filesize($FINFO);

	echodebug("searching for '$title'");

	while(true) {
		$mid=floor(($low+$high)/2);
		fseek($fp_FINFO,$mid);

		fgets($fp_FINFO);
		$pos=ftell($fp_FINFO);

		$line=rtrim(fgets($fp_FINFO));
		#$line=explode("#",$line);

		echodebug("$line ($low-$high)");
		if(strncasecmp($line,"$title#",strlen("$title#")) < 0) {$low=ftell($fp_FINFO);  echodebug("after");}
		if(strncasecmp($line,"$title#",strlen("$title#")) > 0) {$high=$pos; echodebug("before");}
		if(strncasecmp($line,"$title#",strlen("$title#")) == 0) {
			#Don't return now because there can be reesults before (in other cases). advance low of 1 line if possible.
			fseek($fp_FINFO,$low);
			$line=rtrim(fgets($fp_FINFO));
			if(strncasecmp($line,"$title#",strlen("$title#")) == 0) {break;}
			else {$low=ftell($fp_FINFO);}
		}

		if($high-$low < 1024) {break;}
	}

	$results=array();
	fseek($fp_FINFO,$low);
	while(ftell($fp_FINFO) < $high && !feof($fp_FINFO)) {
		$line=explode("#",rtrim(fgets($fp_FINFO)));
		if(strcasecmp($line[0],$title) === 0) { echodebug("Found one! $line[0] ($line[1])"); $results[] = "$line[0]#$line[1]";}
	}

	echodebug("Found ".count($results)." matches");

	return $results;
}

function readArticle($articleTitle,$idx)
{
	global $perlcmd,$DBFileTemplate,$bzcmd,$articleurlpattern,$parserpath;
	$cmd="$perlcmd $parserpath \"$articleTitle\" \"$DBFileTemplate\" $idx \"$articleurlpattern\" \"$bzcmd\"";
	#$cmd=escapeshellcmd($cmd);

	echodebug($cmd);
	$out=shell_exec("$cmd 2>&1");
	echodebug("Command returned $out");

	return $out;
}

function echodebug($msg) {
	global $bDebug;
	if($bDebug) {echo htmlentities($msg,ENT_QUOTES,"UTF-8")."<br />";}
}

function printarticle($article) {
	global $redirectstring,$lang;

	if(strpos($article,'#')>0) {$article=substr($article,0,strpos($article,'#'));}
	$article=htmlspecialchars($article);
	echodebug("getting $article");

	$entry=DBLookup($article);

	$res="";

	if($entry) {
		$article=$entry[0];
		$idx=$entry[1];

		echodebug("found entry $article in file $idx");
		$content=readArticle($article,$idx);

		if($idx>0) {
			if(stripos($content,$redirectstring)>0) {
				$start=strpos($content,">",strlen($redirectstring));
				$end=strpos($content,"<",$start);
				$newarticle=substr($content,$start+1,$end-$start-1);

				echodebug("redirecting to $newarticle");

				$res.="<i>Redirected from $article</i><br />";
				$res.=printarticle($newarticle);
			}
			else {
				$res.="<br /><h1 class='firstHeading'>$article&nbsp;<a href='http://$lang.wikipedia.org/wiki/$article' target='_blank'><img src='res/external.png' /></a></h1><div id='bodyContent'>";
				$res.=$content;
				$res.="</div>";
			}
		}
		else {
			$res.="Sorry, could not find article '$article'.";
		}
	}
	else {$res.= "Sorry, could not find article '$article'";}

	return $res;
}

function PlainAscii($text){
		echodebug("before: $text");

		$text = utf8_strtolower($text);
		$text = utf8_deaccent($text,-1);

		echodebug("after: $text");

		return $text;
}

function printerror($str) {
	echo("$str<br />");
}

?>