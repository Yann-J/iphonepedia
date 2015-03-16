use Digest::MD5 qw(md5_hex);
# Based on Wiki2Static 0.61
###############################
# 
# Copyright (C) 2004, Alfio Puglisi <puglisi@arcetri.astro.it>,
#                     Erik Zachte (epzachte at chello.nl),
#                     Markus Baumeister (markus at spampit.retsiemuab.de)
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.



($title,$bzfilepattern,$idx,$articleurlpattern,$bzcatcmd) = @ARGV or die "Usage: $0 Title bzFilePattern idx linkpattern\nExample: $0 \"Paris\" /private/var/root/Data/rec%05d* 10 wiki.php?a=%s\n";

$imgsupport=1;
$mediaprefix="http://upload.wikimedia.org/wikipedia/commons/thumb";
$imgsize=120;
if($articleurlpattern =~ m/\blang\=([\w\-]*)\b/i) {$lang=$1;}

if($idx =~s/\-(\d*)$//) {$offset=$1;}
$bzcatcmd=$bzcatcmd || "bzcat";

$bzfile=sprintf($bzfilepattern,$idx);
$content=`$bzcatcmd $bzfile`;

$rootpath=$bzfile;
$rootpath=~s|/bz2/.*$||;

unless($content) {die "Could not read file '$bzfile'\n";}

#print "Looking into $bzfile for article '$title'\n";

$text="";

$start = index($content,"<title>$title</title>",$offset);
if($start>0) {
$end=index($content,"</text>",$start);
if($end>0) {$text=substr($content,$start,$end-$start);}
else {
$bzfile=sprintf($bzfilepattern,++$idx);
$content2=`$bzcatcmd $bzfile`;
$end=index($content2,"</text>");
if($end>0) {$text=substr($content,$start).substr($content2,0,$end);}
}
}
else {
die "Cannot find $title in file $bzfile\n";
}

$text =~ s|^.*?<text [^>]*>||s;
#$text =~ s|</text>.*||s;

#print "Found article: $text\n";

$wiki_language = "en";
$include_toc = 6;
$maxlinks=2000;

$wikiserver="http://$wiki_language.wikipedia.org";

%Wikiarray = (
"numberofarticles" => "500,000",
"currentyear" => "2005",
"currentmonthname" => "April",
"currentday" => "21",
"stub" => "",
"writer-stub" => "",
);

$allowedlinkns{"wikipedia"}=1;
#$allowedlinkns{"category"}=1;
$allowedlinkns{"image"}=1;

#%htmltagstoclean = ("gallery" => 0);

$MainPageName = "Main Page";
$MainPagePath = "/" . GetFileName($MainPageName);

@list_seps = ( "\#", "\:", "\*");
#@list_seps = ( "\#", "\:", "\*", " ");

$list_open{"\*"} = "<ul><li>";
$list_continue{"\*"} = "</li><li>";
$list_close{"\*"} = "</li></ul>";

$list_open{"\:"} = "<dl><dd>";
$list_continue{"\:"} = "</dd><dd>";
$list_close{"\:"} = "</dd></dl>";

$list_open{"\#"} = "<ol><li>";
$list_continue{"\#"} = "</li><li>";
$list_close{"\#"} = "</li></ol>";

$list_open{" "} = "<pre>";
$list_continue{" "} = "";
$list_close{" "} = "</pre>";

@templatestoprint = ("e","er",",","[XIV]+e s(iècle)?");
@templatestosubstitute = ("Citation","formatnum\\:(\\d+)");
@templatestolink = ("main","see also","Article détaillé");
@infoboxtemplates = ("infobox","communefra");


$html=WikiToHTML($title,$text,"",1);

print $html;


sub WikiToHTML {
my ($title, $text, $namespace, $do_toc, $do_html, $redir_from) = @_;
my ($page, $title_spaces, $heading, $sep, $protocol);
my ($line, $n, $item, $html_lists, $diff, $opened, $gone_on, $splitted, $want_toc, @TOC);
my ($tex_start, $tex_end, $math);
my ($variable, $original_var, $params, $p, $counter, @params, $replace, $recursive_replace, $parname, $parvalue);
my ($start_nowiki, $end_nowiki, @nowiki, $fragment);
#	return $text if ($level > 5)

$text=RemoveHTMLentities($text);

# Remove <nowiki> segments, saving them
@nowiki = ();
$start_nowiki = "<nowiki>";
$end_nowiki = "</nowiki>";
while ($text =~ m/${start_nowiki}.*?${end_nowiki}/is)
{
$text =~ s/${start_nowiki}(.*?)${end_nowiki}/$nowiki_replacement/;
push @nowiki, $1;
}

$text = RemoveHTMLcomments($text);
#$text =~ s/&amp;((#\d+)|(\w+));/&$1;/mg;	 # likely double html encoding. must be done before linking

foreach $tag (keys %htmltagstoclean) {
	if($htmltagstoclean{$tag}==0) {$text =~ s|\</?$tag[^\>]\>||gm;}
	if($htmltagstoclean{$tag}==1) {$text =~ s|\<$tag[^\>]\>(.*?)\</$tag\>|$1|gm;}
}

#Gallery
while($text =~ s#\<gallery\>(.*?)\<\/gallery\>#"[[".join("]] [[",split(/[\n]/,$1))."]]"#ems) {
# "[[".join("]] [[",split(/[\|\n]/,$1))."]]"
}

# Convert TeX math notation

$tex_start = "<math>";
$tex_end = "</math>";
#	while( $text =~ m|${tex_start}(.*?)${tex_end}|so)
#	 {
#	 $math = $1;
#	 $math =~ s|\\r\\n||g;
#	 $replacement = &ConvertTex($math);
#	 $text =~ s|${tex_start}.*?${tex_end}|$replacement|s;
#	 }


# {{Templates}}
# To be done after TeX conversion, otherwise we pick up {{}}s from it!
# But before everything else, because there's wiki markup inside
# This regexp avoids matching nested variables, so they will be interpreted in the right order
$Wikiarray{pagename} = $title;
$templates_max = 100;
$templates_num = 0;
while( $text =~ m#\{\{([^\{]*?)\}\}#mo)
{
	($variable = $1) =~ s/[\r\n]+//gms;
	$replace = "";
 	
	$original_var = $variable;
	# remove "|" and remember parameters
	if (scalar($variable =~ s/(.*?)\|(.*)$/$1/s) >0)
	{
	$params = $2;
	}
	else
	{
	$params = "";
	}

	my $count = 0;

	@params = ();

	while ($params =~ /(\[\[|\]\]|\|)/gc) {
		$count += { "[[" => 1, "]]" => -1, "|" => 0 }->{$1};

		if ($1 eq "|" && $count == 0) {
			my $param = substr $params, 0, pos($params) - 1, '';
			push @params, $param;

			substr($params, 0, 1) = '';
			pos $params = 0;
		}
	}

	push @params, $params if $params =~ /\S/;


	## Put underscore instead of spaces for filename
	# $variable =~ s/\s/_/g;


	# we don't handle localurl
	if ($variable =~ m/localurl/i)
	{
		$replace = "";
	}
	else
	{
		$replace = $Wikiarray{lc $variable};
		if ($replace eq "")
		{
			#print STDERR "Wikiarray for $variable was empty \n";
			## match msg:, Template;, etc.
			$msg = $variable;
			$replace = GetMsgValue($msg, @params);
			$templates_num = $templates_num+1;
			$replace = "" if ($templates_num > $templates_max);
		}
	}
	
	# Do parameter substitution, if necessary
	if ($params ne "")
	{
		$counter =0;
		foreach $p (@params)
		{
			$counter = $counter+1;
			if ($p =~ m/\=/s)
			{
				($parname, $parvalue) = split("=", $p, 2);
			}
			else
			{
				$parname = $counter;
				$parvalue = $p;
			}
			$parname =~ s/^\s+//;
			$parname =~ s/\s+$//;
			$parvalue =~ s/^\s+//;
			$parvalue =~ s/\s+$//;
			$parname =~ s/\?/\\\?/g;
			$parname =~ s/\s/_/g;

		#	 $replace =~ s/\Q\{\{\{${parname}\}\}\}/$parvalue/isg;
			$replace =~ s/\{\{\{\Q${parname}\E\}\}\}/$parvalue/isg;
		#	 $replace =~ s/\{\{\{$counter\}\}\}/$parvalue/sg;

		#	 $replace =~ s/({{[^}]+){{\Q${parname}\E}}/$1$parvalue/isg;
		}
	}

	$text =~ s#\{\{[^\{]*?\}\}#$replace#m;

}

# Now redo links conversion for the links inserted by {{}} parameters

my $desperation = 0;
while ($text =~ /\[\[([^\[\]]*)\]\]/) {
	$text =~ s/\[\[([^\[\]]*)\]\]/ProcessLink($1)/e;
	#print "link: $1 --> ".ProcessLink($1)."\n";
}

## Newlines
$nextline = "\n";
#	$text =~ s|\r\n\r\n|\n<p>\n|go;	 # Double newline = paragraph
$text =~ s|\r\n|\n|go;	 # Single newline
$text =~ s|\n\n+|\n<p>\n|go;

# Wiki tables
while ( scalar($text =~ m/({\|.*?\|})/so) )
{
	my $table, $table_params, $search, $subst;
	# Get table markup
	$table =$1;

	print "Table found in $title \n" if $debug>0;
	# Find table paramters. Add a <tr> (generates a double <tr><tr> sometimes)
	$subst = "<table ";
	$table =~  s/\{\|(.*)/${subst} $1 \><tr>/m;

	## Close table
	$subst = "</td></tr></table>";
	$table =~ s/\|\}/${subst}/g;
	## handle "||" putting back to newline+"|"
	$subst = "\n|";
	$table =~ s/\|\|/$subst/mg;

	## repeat for  "!!"
	$subst = "\n!";
	$table =~ s/\!\!/$subst/mg;

	## Convert <tr>
	$subst = "</td></tr><tr";
	$table =~ s/\|\-(.*)/$subst $1 \>/mg;
	## Except for the first..
	$table =~ s|(\<table.*?\>\s*)\<\/td\>\<\/tr\>|$1|s;

	## remove double <tr><tr> sometimes found after <table>
	$table =~ s/\<tr\>\s*(\<tr)/$1/g;
	## Now the caption
	$subst = "<caption ";
	$subst2 = "</caption>";
	$table =~ s/\|\+(.*?)\|(.*)/${subst} $1\>$2${subst2}/m;
	$table =~ s/\|\+(.*)/${subst}\>$1${subst2}/m;
	## Now all the TDs
	$subst = "</td><td ";
	$table =~ s/^\|(.*?)\|(.*)/${subst} $1\>$2/mg;
	$table =~ s/^\|(.*)/${subst}\>$1/mg;

	## Except the first on each row...
	$table =~ s|(\<tr[^\>]*?\>\s*)\<\/td\>|$1|sg;

	## Repeat for THs
	$subst = "</th><th ";
	$table =~ s/^\!(.*?)\|(.*)/${subst} $1\>$2/mg;
	$table =~ s/^\!(.*)/${subst}\>$1/mg;

	## Except the first on each row...
	$table =~ s|(\<tr[^\>]*?\>\s*)\<\/th\>|$1|sg;

	## Now put the table back inside the text

	$table = &RemoveHTMLentities($table);
	$text =~ s/\{\|.*?\|\}/$table/s;
}

#references Should be done after template renderings, but before list compilations...
$nref=1;
while($text =~ s|\<ref\>(.+?)\</ref\>|<sup class=\"reference\" id=\"ref-$nref\"><a href=\"#note-$nref\">[$nref]</a></sup>|sm) {
	push @references,"<li id=\"note-$nref\"><b><a href=\"#ref-$nref\">^</a></b>$1</li>";
	$nref++;
}

if(@references) {$references="<ol class=\"references\">".join("\n", @references)."</ol>";}
$text =~ s|\<references\s*/\>|$references|i;

# Random wiki markup

#	$nextline = "\r\n";
#	$text =~ s|\\r\\n\\r\\n|<p>$nextline|go;	 # Double newline = paragraph
#	$text =~ s|\\r\\n|$nextline|go;	 # Single newline
#	$text =~ s|\\n\\n|$nextline|go;
#	$text =~ s|^\s(.*?)$|<pre>$1</pre>|sg;	 # Initial space (with text inside) = monospaced format (now handled as list)
$text =~ s|^-----*|<hr>|mgo;	 # Four+ dashes = horizontal line
$text =~ s|'''(.*?)'''|<strong>$1</strong>|g;	 # Three quotes = strong
$text =~ s|''(.*?)''|<em>$1</em>|g;	 # Two quotes = emphatize
#	$text =~ s|\\'\\'\\'(.*?)\\'\\'\\'|<strong>$1</strong>|g;	 # Three quotes = strong


# handle lists and TOC by splitting into individual lines
# Use an external flag to split only one time, if needed
$splitted=0;
$want_toc=0;
@lines=();
@TOC=();
# Check if we have any kind of list
if ( $text =~ m/^([\#\:\* ]+)/mgo)
{
# Split the text into individual lines
if ($splitted == 0)
{
@lines = split(/\n/, $text);
$splitted=1;
}

# Work on a line-by-line basis

%previous=("#",0,":",0,"*",0," ",0);
foreach $line (@lines)
{
$line =~ s/^\s+$//;
# Count the leading list markers on each line
#(including non-list lines, they could be the closing ones!)
if ($line =~ s/^([\#\:\*]+|\s)//m)
{
$current = $1;
}
else
{
$current = "";
}

%this_one=("#"=>0, ":"=>0, "*"=>0, " "=>0);
if ($current ne "")
{
$allofthem=0;
foreach $n (0 .. length($current)-1)
{
$item = substr( $current, $n, 1);
$this_one{$item} ++;
$allofthem++;
}
$this_one{" "} = 1 if $this_one{" "} > 1;	 # Leading-space monospaced format "list" has only one level
$this_one{" "} = 0 if $allofthem>1;	 # And must also be alone
}

# Now we can compare with the previous line and see
# what we must open, close or carry on.
$html_lists = "";
$opened=0;
foreach $item (@list_seps)
{
$diff = $this_one{$item} - $previous{$item};
if ($diff >0)
{
$html_lists .= $list_open{$item} x $diff;
$opened++;
}
if ($diff <0)
{
$html_lists .= $list_close{$item} x (-$diff);
}
}

# When carrying on lists, a bit of care must be employed
$gone_on=0;
foreach $item (@list_seps)
{
$diff = $this_one{$item} - $previous{$item};
if (($diff<=0) && ($this_one{$item} >0) && ($opened==0) && ($gone_on==0))
{
$html_lists .= $list_continue{$item};
$gone_on++;
}
}

# Replace leading list markers with HTML tags
if ($html_lists ne "")
{
$line = $html_lists.$line;
}

# Save this line status to compare it with the next one.
%previous = %this_one;
}
}

# See if we need to close any remaining list
$closure="";
foreach $item (@list_seps)
{
if ($this_one{$item} >0)
{
$closure .= $list_close{$item} x $this_one{$item};
}
}

# Check for the TOC
if ((!($text =~ m/__NOTOC__/mio)) && ( $text =~ m/==+/mg) && ($include_toc>0) && ($title ne $MainPageRecord))
{
if ($splitted == 0)
{
# Split the text into individual lines
@lines = split(/\n/, $text);
$splitted=1;
}

foreach $line (@lines)
{
if ($line =~ m/(==+)\s*(.*?)\s*==+/m)
{
$level = length($1);
$name = &HTMLLinksToText($2);

push @TOC, $level.":".$name;
$want_toc++;
}
}
}
# Rebuild the page if needed

if ($splitted)
{
$text = join("\n", @lines);
}

## Insert the list closure (if any) at the end of the article
$text .= $closure;


# If a TOC is wanted, place it
if (($want_toc >= $include_toc) && ($do_toc) && @TOC)
{
$TOC_html = <<END_STARTTOC;
<p><table id="toc" class="toc"><tbody><tr><td>
<div id="toctitle"><h2>Contents</h2></div><ul>

END_STARTTOC

$first_level=substr($TOC[0], 0, 1);

@counter=();
foreach $TOCitem (@TOC)
{
# Get the TOC item properties
$level = substr($TOCitem, 0, 1) - $first_level;
$name = substr($TOCitem, 2);

# Open and close DIVs as necessary
$level = 0 if $level<0;

# Count items and subitems, build an index number, and save the html string
$counter[$level]++;
@counter=@counter[0..$level];
if ($level == 0)
{
	$number = $counter[0];
}
else
{
	$number = join(".", @counter);
}

if($level > $previous_level) {
	$TOC_html .= "<ul>";
}
if($level < $previous_level) {
	$TOC_html .= "</ul>";
}
$TOC_html .="<li class='toclevel-".($level+1)."'><a href='#$name'><span class='tocnumber'>$number</span>&nbsp;<span class='toctext'>$name</span></a></li>";
$previous_level=$level;
}
# End TOC
$TOC_html .= "</ul></td></tr></tbody></table>";

# Place the TOC just before the first heading
$text =~ s/(==+)/${TOC_html}$1/;
}

# Remove __NOTOC__ command, if present
$text =~ s/__NOTOC__//mg;
# Remove other random commands
$text =~ s/__NOEDITSECTION__//mg;
# Headings (in reverse order, otherwise it does not work!)
# Convert to <H>, and make anchors too.
#
# This substitution must be made AFTER the TOC has been generated and placed in the page
for ( $i=6; $i >= 2; $i--)
{
$heading = "=" x $i;
while ( $text =~ m|${heading}\s*(.*?)\s*${heading}|m )
{
$header = $1;
$anchor_name = &HTMLLinksToText($header);
$text =~ s|${heading}\s*.*?\s*${heading}|<a href='#TOP' class='toplink'>[TOP]</a><a name=\"${anchor_name}\"></a><h${i}>${header}</h${i}>|m;
}
}
# External links and [External links]
# Do not change the order of substitutions
$sep = "\<\,\;\.\:"; 	 ## List of separators that can happen at the end of an URL without being included in it.
$external_reference_counter=1;
foreach $protocol ( qw(http https ftp gopher news mailto))
{
while ( $text =~ s|\[(${protocol}\:\S+)\s*\]|<A HREF=\"$1\" class="external">\[${external_reference_counter}\]</A>|mg)
{
$external_reference_counter++;
}
$text =~ s|\[(${protocol}\:\S+)\s+(.*?)\]|<A HREF=\"$1\" class="external">$2</A>|mg;
#$text =~ s|([^\"])(${protocol}\:\S+)([${sep}]*)\b|$1<A HREF=\"$2\" class="external">$2</A>$3|mg;
}

# unicode -> html character codes &#nnnn;
if ($wiki_language ne "en")
{
$entry =~ s/([\x80-\xFF]+)/&UnicodeToHtml($1)/ge ;
}

# Put back <nowiki> segments
# Possible change:
# 	$text =~ s|${nowiki_replacement}|shift(@nowiki)|es;
while ($text =~ m/$nowiki_replacement/)
{
$fragment = shift @nowiki;
$text =~ s/${nowiki_replacement}/$fragment/;
}

if ($do_html)
{
$title_spaces = $title;
$title_spaces =~ tr/_/ /;
if ($redir_from) {
$redir_from = qq( <small>(redirected from <b>$redir_from</b>)</small>);
}

$article_link = "http://${wiki_language}.wikipedia.org/wiki/${title}";
if ($edit_article_link>0)
{
$article_link = "http://${wiki_language}.wikipedia.org/w/wiki.phtml?title=${title}&amp;action=edit";
}

$alphabetical_index = "";
#	 $alphabetical_index = " | <a href=\"../../abc.html\">Alphabetical index</a>" if $wiki_language eq "en";

$page = <<ENDHTMLPAGE;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html lang="en"><head><title>$title_spaces</title><meta http-equiv="Content-type" content="text/html; charset=${WikiCharset}">
<link rel="stylesheet" href="../../wikistatic.css"></head>
<body bgcolor='#FFFFFF'>
<div id=topbar><table width='98%' border=0><tr><td><a href="${MainPagePath}" title="${MainPageName}">${MainPageName}</a> | <b><a href="${article_link}" title="${title_spaces}">See live article</a></b>${alphabetical_index}</td>
<td align=right nowrap><form name=search class=inline method=get action="/search/"><input name=q size=19><input type=submit value=Search></form></td></tr></table></div>
<div id=article><h1>$title_spaces$redir_from</h1>$text</div><br><div id=footer><table border=0><tr><td>
<small>This article is from <a href="http://www.wikipedia.org/">Wikipedia</a>. All text is available under the terms of the <a href="../../g/gn/gnu_free_documentation_license.html">GNU Free Documentation License</a>.</small></td></tr></table></div></body></html>
ENDHTMLPAGE


}	 # Fine di if ($do_html)
else
{
$page = $text;
}
$page;
}

sub ProcessLink
{
my($original_link) = @_;
my($linkname, $linkappereance, $linkhref, $sep, $namespace);
my($medianame, $realmediapath, $diskmediapath, $href, $is_image, $mediafile, $fileprefix);


#$sep = ".,;:!?\"\$";
#$colon = ($original_link =~ m/:/);
#$original_link =~ s/[${sep}]+$//g;	 # remove separators at the end

#$original_link =~ s/(\&[^;]+)$/$1\;/g;	 # put back ";" if part of an HTML entity
$original_link =~ s/^\s+//g;	 # trim
$original_link =~ s/\s+$//g;	 # trim

$linkname = $original_link;
$linkappereance = $original_link;

# Watch out for pipes (they change link appereance, and would also break regexps if left in the link)
if ($linkname =~ m/^\s*(.*?)\|(.*)/o)
{
$linkname = $1;
$linkappereance = $2;
# If empty, use the first part and remove the parenthesis, if present
if ($2 eq "")
{
$linkappereance = $linkname;
$linkappereance =~ s/\(.*?\)//o;
}
}
$linkhref = "";

# Deal with namespaces:
if ($linkname =~ m/^([\w\-]+):/oi) {
	$namespace=$1;
	unless($allowedlinkns{lc $namespace}) {return "";}
	#$linkname =~ s/^.*://;
	#$linkappereance =~ s/^.*://;
}

#deal with images
if($namespace =~ m/^image$/i) {
	return ProcessImage($original_link);
}

# Watch out for anchors
if ($linkname =~ /^\#/)
{
	# An anchor translates into a link directly in this page
	$href = "<A HREF=\"".$linkname."\" class='internal' title=\"\">$linkappereance</A>";
}
else
{
	$linkhref = &GetFileName($linkname);
	$href = "<A HREF=\"${linkhref}\" title=\"${linkname}\">$linkappereance</A>";
}

return $href;
}

########################
# HTMLLinksToText
#
# Converts any links inside the text to their
# pure appereance, without HREFS and formatting

sub HTMLLinksToText
{
my ($text) = @_;

$text =~ s/\<A HREF.*?\>(.*?)\<\/A\>/$1/sig;

$text;
}

sub RemoveHTMLcomments {
my ($text) = @_;
my ($comment_start, $comment_end);
$comment_start = "<!--";
$comment_end = "-->";
$text =~ s/\Q$comment_start\E(.*?)\Q$comment_end\E//msg;
$text;
}

sub RemoveHTMLentities {
my ($text) = @_;
my (%entities, $key, $subst);
%entities =  (	"&amp;"	 =>	"&",
"&ndash;"	=>	"-",
"&mdash;"	=>	"-",
"&nbsp;"	=>	" ",
"&lt;"	 =>	"<",
"&gt;"	 =>	">",
"&quote;"	=>	"\"",
"&quot;"	=>	"\'"
 );
foreach $key (keys %entities)
{
$subst = $entities{$key};
$text =~ s/$key/$subst/g;
}
$text;
}

sub GetFileName {
	my ($linkname) = @_;
	return sprintf($articleurlpattern,MakeUrl(urlencode($linkname)));
}

sub GetMsgValue {
	my ($msg,@params) = @_;
	my ($res, $nvalues);
	
	foreach $tmpl (@templatestoprint) 	 {if($msg =~ /^$tmpl$/i) {return $msg;}}
	foreach $tmpl (@templatestosubstitute)	 {if($msg =~ /^$tmpl$/i) {
							if($1 ) {return $1;}
							else {return join(" ",@params);}
						}}
	foreach $tmpl (@templatestolink) 	 {if($msg =~ /^$tmpl$/i) {
							if($1 ) {return ProcessLink($1);}
							else {return join(" ",map(ProcessLink($_),@params));}
						}}
						
	if($msg =~ /^cite(\s.*)?$/i)  {
		$url="";$title="";
		#print "cite: $msg @params";
		foreach $arg (@params) {
			#print "Argument: $arg\n";
			if($arg =~ /^\s*url\s*=\s*(.*?)\s*$/) {$url=$1;}
			if($arg =~ /^\s*title\s*=\s*(.*?)\s*$/) {$title=$1;}
		}
		if($url) {return ProcessCite($url,$title);}
	}
	
	if($msg =~ /^reflist$/i) {
		return "<references/>";
	}

	$nvalues=0;
	foreach $opt (@params) {
		if($opt =~ /\s*(.+)\s*\=\s*(.+)\s*$/) {
			$res.="<tr bgcolor=\"#ffec8b\"><th>".ucfirst($1)."</th></tr><tr><td>$2</td></tr>";
			$nvalues++;
		}
	}
	if($nvalues>5) {
		return "<table class=\"infobox\" style=\"margin: 0px 0px 0.5em 1em; width: 250px; float: right; font-size: 90%;\"><tbody>$res</tbody></table>";
	}

	return "";
}


sub urlencode {
	my ($url)=@_;
	$url =~ s/([^A-Za-z0-9])/sprintf("%%%02X", ord($1))/seg;;
	return $url;
}


sub ProcessCite {
	my ($url,$title)=@_;
	$title=$title or $url;
	return "<a href='$url' class='external'>$title</a>";
}

sub MakeUrl {
	my ($url) = @_;
	$url =~ s/\s/\_/g;
	return $url;
}

sub ProcessImage {
    my ($original_link) = @_;
    my ($htmlpath, $html, $count, @options);
    my ($thumb, $width, $divclass, $divsize, $imagesize, $enlargelink, $htmlpath, $html);
    my ($nopipe);
    
    $linksize_divisor=1.4;
    
	# Otherwise, get the options
	# remove pipes within links since they will mess up options splitting
	$nopipe="NOPIPEHERE";
	while( $original_link =~ s/(\[\[[^\]]*?)\|([^\]]*?\]\])/$1$nopipe$2/gs)
	{   # nothing to do, only replacing is important
	}
	@options =  split(/\|/, $original_link);

	# Remove first and last field (image filename and display name)
	$imagename = shift @options;
	$imagename =~ s/^image\://i;
	$linkappereance = pop @options;
	# put any pipes back into the linkappearance. They might be within further links
	$linkappereance =~ s/$nopipe/\|/gos;

	$divclass = "thumb";
	$thumb=0;
	$width=$imgsize;
	foreach $option (@options)
	    {
	    $thumb = 1                          if $option eq "thumb" || $option eq "thumbnail" || $option eq "right" || $option eq "left";
	    $divclass = "thumb tright"          if $option eq "right";
	    $divclass = "thumb tleft"           if $option eq "left";
	    $divclass = "floatnone"             if $option eq "none";
	    $width=int($1/$linksize_divisor)    if $option =~ m|(\d+)\s*px|oi;
	    }           

	if ($linkappereance =~ m|(\d+)\s*px|oi) {
		$width=int($1/$linksize_divisor);
		$linkappereance="";
	}

	# Check for "none" override
	if (($thumb == 1) && ($divclass eq "floatnone"))
	    {
	    $divclass = "thumbnail-none";
	    }

	# Force thumbnail size
	if (($thumb == 1) && ($width==0))
	    {
	    $width = 96;
	    }

	$enlargelink ="";
	$caption = "";

	$htmlpath=GetImageRef($imagename);

	if($htmlpath) {
		if ($thumb == 1)
		{
			$enlargelink = "<a href=\"".$htmlpath."\" class=\"internal\" title=\"Enlarge\">";
			$enlargelink .= "<img borders=\"0\" src=\"res/magnify-clip.png\" width=\"15\" height=\"11\" align=\"right\" alt=\"Enlarge\"></a>";

			$caption = $linkappereance;
			$html="<div class=\"$divclass\"><div class=\"thumbinner\" style=\"width: ${width}px;\"><a class=\"image\" href=\"$htmlpath\" ><img class=\"thumbimage\" width=\"$width\" border=\"0\" src=\"$htmlpath\" /></a><div class=\"thumbcaption\">$caption</div></div></div>";
		}
		else {
			$html="<a class=\"image\" href=\"$htmlpath\" ><img width=\"$width\" border=\"0\" src=\"$htmlpath\" /></a>";
		}
	}
    
	return $html;
}

sub GetMediaPath {
    my ($medianame) = @_;
    my ($md5, $path, $fileprefix);

    $medianame=GetMediaName($medianame);

    $md5 = md5_hex($medianame);

    $fileprefix = substr($md5,0,1)."/".substr($md5,0,2);
    
    return $fileprefix;
}

sub GetMediaName {
    my ($medianame) = @_;

    # First-capitalize Unpack %xx hex-encoded characters, and convert resulting spaces in "_"
    $medianame = ucfirst $medianame;
    $medianame =~ s/%(..)/pack("c",hex($1))/ge;
    $medianame =~ s/\s/_/g;
    
    # Remove <> signs, on some systems we cannot write files with them
    $medianame =~ s/\>/_/g;
    $medianame =~ s/\</_/g;
    # replace remaining unicase (if there are errors in the media names)
    #$medianame =~ s/[^\p{Latin}\p{NP}]/_/g;

    #print "$medianame -";  
    #use Encode 'from_to';
    #from_to($medianame,"utf-8","iso-8859-15");
    #$medianame = pack("C*",unpack("U*", $medianame));
    
    return $medianame;
}

sub GetImageRef {
	my ($name) = @_;
	my ($path, $fullpath, $ref);
	
	$path=GetMediaPath($name);
	$fullpath=$path."/".GetDiskName($name);
	
	if(-e "$rootpath/img/$fullpath" || -e "$rootpath/../img/$fullpath") {
		$ref="image.php?name=$fullpath&lang=$lang";
	}
	else {
		#$name=GetMediaName($name);
		#$ref="$mediaprefix/".GetMediaPath($name)."/$name/${imgsize}px-$name";
	}
	
	return $ref;
}

sub GetDiskName {
	my ($title)=@_;
	#$title =~ s/\.(\w+)$//;
	#$ext=$1;
    
    # Build a suitable filename for the title
    $filetitle = lc $title;

    # Remove non-plain ASCII letters
    $filetitle = PlainAscii($filetitle);
    
    # Remove any other character outside the 0-9a-z range
    $filetitle =~ s/[^a-z0-9\s\_\.]+/_/go;
    
    # Now remove whitespace
    $filetitle =~ s/\s+/_/go;

    $filetitle =~ s/\.svg$/.png/i;

    return $filetitle;
	
	#return md5_hex($name).".$ext";
}

sub PlainAscii {
         my ($string) = @_;

        $string =~ tr/ÀÁÂÃÅàáâãå/a/;
        $string =~ s/Ä|ä/ae/go;
        $string =~ tr/Çç/c/;
        $string =~ tr/ÈÉÊËèéêë/e/;
        $string =~ tr/ÌÍÎÏìíîï/i/;
        $string =~ tr/Ð/d/;
        $string =~ tr/Ññ/n/;
        $string =~ tr/ÒÓÔÕØðòóôõø/o/;
        $string =~ s/Ö|ö/oe/go;
        $string =~ tr/ÙÚÛùúû/u/;
        $string =~ s/Ü|ü/ue/go;
        $string =~ tr/Ýýÿ/y/;
        $string =~ s/ß/ss/go;
        $string =~ s/æ|Æ/ae/go;
         return $string;
}
