<?php

require_once("config.php");
require_once("common_lib.php");

$name = isset($_GET["name"])?$_GET["name"]:"";


$fmt="png";
if(strrpos($name,".")) {$fmt=strtolower(substr($name,strrpos($name,".")+1));}

#print "$imgpath/$name - $fmt";

$filename="$imgpath/$name";

if(!file_exists($filename)) {str_replace("/$lang/","/",$filename);}
if(!file_exists($filename)) {print "Cannot find image $name\n";}

$tag = fopen($filename, 'rb');
header("Content-type: image/$fmt");
fpassthru($tag);

?>

