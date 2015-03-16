<?php

require_once("config.php");
require_once("common_lib.php");

$article = isset($_GET["a"])?str_replace('_',' ',$_GET["a"]):"";

read_template("template.htm");

if($article) {$windowtitle.=": $article";}
print print_template("header");

if($article) {
	echo printarticle($article);
}

print print_template("footer");

?>
