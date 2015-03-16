# IMPORTANT!!!! do NOT use the default windows sort command, it's way too slow. Use the Cygwin version
$sortcmd="sort";

#imgsupport:
#0 for no image,
#1 for download and resize image,
#2 for image links (not supported yet)
$imgsupport = 1;


#sortmethod: 
#1 for external sort command (preferred if you have the GNU sort),
#2 for an in-place mergesort !!very slow!! don't use...
#3 for an insertion sort
$sortmethod=1;

use Encode;

if(! `$sortcmd --help`) {print "Could not find correct external sort. Falling back on internal algorithm.\n"; $sortmethod=3;}

$rootpath=$ARGV[0] or die "$0: Offline wikipedia search index generator.\nUsage: $0 RootPath\n\nbzip splits will be created in RootPath/bz2 and index files in RootPath/db\nDumpFile is optional if the big archive is already split\n\n";
$skipfirst = $ARGV[1];
$skipfirst ||= 0;

%allowedexts = (
	"jpg" => 1,
	"jpeg" => 1,
	"png" => 1,
	"svg" => 1, #svg is converted to png at download time
	"gif" => 1,
);

$archivepath="$rootpath/bz2";
$indexpath="$rootpath/db";
$imgpath="$rootpath/img";
@Titles=();

if($imgsupport>0) {
	mkdir "$imgpath";
	use Digest::MD5 qw(md5_hex);
	use HTTP::Request;
	use LWP::UserAgent;
	$ua = new LWP::UserAgent;
	$ua->agent("iPhonePedia");
}
$thumbmediaprefix="http://upload.wikimedia.org/wikipedia/%s/thumb";
$fullmediaprefix="http://upload.wikimedia.org/wikipedia/%s";
$imgsize=120;

print "\n";
print "== Root path: $rootpath\n";
print "== Archives path: $archivepath\n";
print "== Index path: $indexpath\n";
print "\n";

$starttime=time;

$pattern="*.xml.bz2";

$indexfile="Index.dat";
$forcearchivescan=true;

$bzip2recovercmd="bzip2recover";
$bzcatcmd="bzcat";

#List of namespaces to ignore, identified by their language-independent index. 0 = ignore, 1=include
%namespaces=(
      -2 => 0, #Media
      -1 => 0, #Special
      1 => 0, #Talk
      2 => 0, #User
      3 => 0, #User talk
      4 => 0, #Wikipedia
      5 => 0, #Wikipedia talk
      6 => 0, #Image
      7 => 0, #Image talk
      8 => 0, #MediaWiki
      9 => 0, #MediaWiki talk
      10 => 0, #>Template
      11 => 0, #>Template talk
      12 => 0, #>Help
      13 => 0, #>Help talk
      14 => 0, #>Category
      15 => 0, #>Category talk
      100 => 0, #Portail
      101 => 0, #Discussion Portail
      102 => 0, #Projet
      103 => 0, #Discussion Projet
      104 => 0, #Référence
      105 => 0, #Discussion Référence
);


#unzip and scan archives if needed
open OUTFILE,">$indexfile";
@list = glob("$archivepath/$pattern");

if(@list == 0) {
	die "Could not find any archive. Please make sure either the wikipedia dump or the splitted files are in $archivepath\n";
}
	
if(@list == 1) {
	print "Only one archive found. Splitting.\n";
		
	$bigfile=$list[0];
	print `$bzip2recovercmd $bigfile`;
	@list = glob("$archivepath/$pattern");
	if(@list > 1) {
		print "Success!\n";
		#`rm $bigfile`;
	}
}

$archivetime=int((time - $starttime)/60);

$imagecount=0;
$failedimagecount=0;
$foundimagecount=0;

$allfiles=@list;
	
foreach $bzfile (@list) {
	next if ($bzfile eq $bigfile);
		
	if($bzfile =~ m/rec(\d+)(\w+)wiki/) {
		$idx=$1;
		$lang=$2;
		next if($idx<$skipfirst && $imgsupport);
		
		print "Exploring content of file number $idx/$allfiles\n";
		$content= `$bzcatcmd $bzfile`;
		#print "$content";

		if($idx==1) {
			#extract namespace information
			while($content =~ m|<namespace key="([\d\-]*)">(.*?)</namespace>|ig) {
				unless($namespaces{$1}==1) {
					$ignorenamespaces{lc $2}=1;
					print "Ignoring namespace $2\n";
				}
			}
		}

		while($content =~ m|<title>([^<]+)</title>|g) {
			$title=$1;
			$offset=pos($content)-length("<title>$title</title>");
			$skip=0;
			foreach $ns (keys %ignorenamespaces) {if($title =~ /^$ns\:/i) {$skip=1;}}
			next if($skip);
			
			#$title=decode("utf8", $title);
			#$title=PlainAscii($title);
				
			#print "$title#$idx\n";
				
			if($sortmethod==1) {
				print OUTFILE "$title#$idx-$offset\n";
			}
			elsif($sortmethod==2) {
				push(@Titles, "$title#$idx-$offset");
			}
			elsif($sortmethod==3) {
				print OUTFILE "$title#$idx-$offset\n";
				#InsertSorted("$title#$idx-$offset");
			}
			
		}


		if($imgsupport>0) {
			while($content =~ m/(\[|^)image\:(.*?)(\]|$)/mgi) {
				$foundimagecount++;
				$descr=$2;
				if($descr=~ m/(\d+)px/) {$width=$1;}
				else {$width=$imgsize;}
				$descr =~ s/\|.*//;
				$descr =~ s/\s+$//;
				$descr =~ s/^\s+//;
				print " $idx/$allfiles-Image:$imagecount: $descr - ";
				$returned=ProcessImage($descr,$width);
				if($returned==1) {
					print "ok\n";
					$imagecount++;
				}
				elsif($returned==2) {
					print "already downloaded\n";
				}
				else {
					print "failed\n";
					#$failedimg{$descr}=1;
					$failedimagecount++;
				}
			}
		}
	}
}



if(keys %failedimg) {
	open FAILED, ">Failed.dat";
	foreach $img (keys %failedimg) {print FAILED "$img\n";}
	close FAILED;
}

$exploretime=int((time - $starttime)/60);

if($imgsupport) {
	print "== Image stats:\n";
	print "  Detected  : $foundimagecount\n";
	print "  Downloaded: $imagecount\n";
	print "  Failed    : $failedimagecount\n";
}

print "== Sorting\n";

if($sortmethod==1) {
	close OUTFILE;
	print `$sortcmd -f -o \"$indexfile\" \"$indexfile\"`;
	#other options -t \'#\' -k 1,1 
}
elsif($sortmethod==2) {
	merge_sort(\@Titles, 0, scalar(@Titles)-1);
	foreach $elt (@Titles) {
		print OUTFILE "$elt\n";
	}
	close OUTFILE;
}
elsif($sortmethod==3) {
	close OUTFILE;
	open OUTFILE,"<$indexfile";
	while(<OUTFILE>) {
		chomp;
		InsertSorted("$_");
	}
	close OUTFILE;
	open OUTFILE,">$indexfile";
	foreach $elt (@Titles) {
		print OUTFILE "$elt\n";
	}
	close OUTFILE;
}


$sorttime=int((time - $starttime)/60);

# Path to index database files
$HASH      = "${indexpath}/0_hash";
$HASHWORDS = "${indexpath}/0_hashwords";
$FINFO     = "${indexpath}/0_finfo";
$SITEWORDS = "${indexpath}/0_sitewords";
$WORD_IND  = "${indexpath}/0_word_ind";



#minimum word length to index
$min_length = 3;

# Index or not numbers (set   $numbers = ""   if you don't want to index numbers)
# You may add here other non-letter characters, which you want to index
$numbers = '0-9';

# Indexing scheme
# Whole word - 1
# Beginning of the word - 2
# Every substring - 3
$INDEXING_SCHEME = 1;

# List of stopwords
$stop_words = "and any are but can had has have her here him his how its not our out per she some than that the their them then there these they was were what you";


$HASHSIZE = 300001;


@stop_words=split(/\s+/,$stop_words);
foreach $stopword (@stop_words) {$stop_words_array{$stopword}=1; }


print "== Start indexing\n";


#DEFINE CONSTANTS
$cfn = 0;
$cwn = 0;

if(! -d "db") {
	mkdir("db",0755) or die("Can't create directory DB!!!");
	print "== Directory 'db' has been created\n";
}



mkdir($indexpath);
open(fp_FINFO,">$FINFO") or die("Can't open index file!\n");
open(fp_SITEWORDS ,">$SITEWORDS") or die("Can't open index file!\n");
open(fp_WORD_IND,">$WORD_IND") or die("Can't open index file!\n");

binmode fp_FINFO;
binmode fp_SITEWORDS;
binmode fp_WORD_IND;

print fp_FINFO "\x0A";

scan_list("$indexfile");

if ($cfn == 0) {
    die "No files are indexed\n";
}

print "== Computing word hash\n";
    $pos_sitewords = tell(fp_SITEWORDS);
    $pos_word_ind  = tell(fp_WORD_IND);
    $to_print_sitewords = "";
    $to_print_word_ind  = "";
    foreach $word (keys %words) {
    	$value=$words{$word};
        $cwn++;
        $words_word_dum = pack("NN",$pos_sitewords+length($to_print_sitewords),
    	                        $pos_word_ind+length($to_print_word_ind));
    	$to_print_sitewords .= "$word\x0A";
    	$to_print_word_ind .= pack("N",length($value)/4).$value;
    	$words{$word} = $words_word_dum;
    	
    	
    	if (length($to_print_word_ind) > 32000) {
    	    print fp_SITEWORDS $to_print_sitewords;
    	    print fp_WORD_IND  $to_print_word_ind;
    	    $to_print_sitewords = "";
    	    $to_print_word_ind  = "";
    	    $pos_sitewords = tell(fp_SITEWORDS);
    	    $pos_word_ind  = tell(fp_WORD_IND);
    	}

    }
    print fp_SITEWORDS $to_print_sitewords;
    print fp_WORD_IND  $to_print_word_ind;

close(fp_SITEWORDS);
close(fp_WORD_IND);

$indextime=int((time - $starttime)/60);

print "== Dumping hash\n";

build_hash();

print "== $cfn entries indexed\n";


$dumptime=int((time  - $starttime)/60);



print "\n";
print "- Archive time: $archivetime\n";
print "- Explore time: $exploretime\n";
print "- Sort time:    $sorttime\n";
print "- Index time:   $indextime\n";
print "- Dump time:    $dumptime\n";



#=====================================================================
#
#    Function risearch_hash($key)
#    Last modified: 16.04.2004 17:54
#
#=====================================================================

sub risearch_hash {
	my ($key)=@_;
    @chars = split(//,$key);
    for($i=0;$i<@chars;$i++) {
        $chars2[$i] = ord($chars[$i]);
    }

    $h = hex("00000000");
    $f = hex("0F000000");

    for($i=0;$i<@chars;$i++) {
		$h = ($h << 4) + $chars2[$i];
        if ($g = $h & $f) { $h ^= $g >> 24; };
        $h &= ~$g;
    }

    return $h;

}

#=====================================================================
#
#    Function index_file($html_text,$url)
#    Last modified: 15.07.2004 11:35
#
#=====================================================================

sub index_title {
	my ($textindex,$url) = @_;
	my %words_temp;


    $cfn++;

	#decode UTF8
	$textindex = decode_utf8($textindex);

	$textindex = RemoveHTMLentities($textindex);
    #$textindex =~ s/[^a-zA-Zà-ÿÀ-ß$numbers -]/ /g;
    $textindex =~ s/[^\w\d -]/ /g;
    $textindex =~ s/\s+/ /g;
    $textindex = lc($textindex);
    $textindex = PlainAscii($textindex);

	#back to binary
	$textindex = encode_utf8($textindex);
	@words_temp=split(/\s+/,$textindex);

    $pos = tell(fp_FINFO);
    $pos = pack("N",$pos);
    print fp_FINFO "$url\x0A";
    

    foreach $word (@words_temp) {
        next if (length($word) < $min_length);
        next if ($stop_words_array{$word});
        $words{$word} .= $pos;
        
        #print "$word => ".$words{$word}."\n";
    }
    
}

#=====================================================================
#
#    Function build_hash()
#    Last modified: 16.04.2004 17:54
#
#=====================================================================

sub build_hash {

    for ($i=0; $i<$HASHSIZE; $i++) {$hash_array[$i] = "";};

    foreach $word (keys %words) {
    	$value=$words{$word};
        if ($INDEXING_SCHEME == 3) { $subbound = length($word)-3; }
        else { $subbound = 1; }
        if (length($word)==3) {$subbound = 1;}
        $substring_length = 4;
        if ($INDEXING_SCHEME == 1) { $substring_length = length($word); }

        for ($i=0; $i<$subbound; $i++){
            $hash_value = abs(risearch_hash(substr($word,$i,$substring_length)) % $HASHSIZE);
    	    $hash_array[$hash_value] .= $value;
    	 }

    }

    open(fp_HASH, ">$HASH") or die("Can't open index file!");
    open(fp_HASHWORDS,">$HASHWORDS") or die("Can't open index file!");

	binmode fp_HASH;
	binmode fp_HASHWORDS;
	
    $zzz = pack("N", 0);
    print fp_HASHWORDS $zzz;
    $pos_hashwords = tell(fp_HASHWORDS);
    $to_print_hash = "";
    $to_print_hashwords = "";

    for ($i=0; $i<$HASHSIZE; $i++){
    	$elt=$hash_array[$i];
        if ($elt eq "") {$to_print_hash .= $zzz;}
        else {
            $to_print_hash .= pack("N",$pos_hashwords + length($to_print_hashwords));
            $to_print_hashwords .= pack("N", length($elt)/8).$elt;
            
        }
        if (length($to_print_hashwords) > 64000) {
            print fp_HASH $to_print_hash;
            print fp_HASHWORDS $to_print_hashwords;
            $to_print_hash = "";
            $to_print_hashwords = "";
            $pos_hashwords  = tell(fp_HASHWORDS);
        }
    }
    print fp_HASH $to_print_hash;
    print fp_HASHWORDS $to_print_hashwords;


close(fp_HASH);
close(fp_HASHWORDS);


}
#=====================================================================




#=====================================================================
#
#    Function scan_files ($dir)
#    Last modified: 05.04.2005 16:41
#
#=====================================================================

sub scan_list {
	my ($dbfile)=@_;

	print "== Scanning $dbfile\n";
	open(FILE,$dbfile) or print "Cannot open $dbfile\n";

	while(<FILE>) {
		$line=$_;
		chomp $line;
		if($line =~ /^(.*)#.*/) {
			#print "indexing entry: $line";
			index_title($1,$line);
		}
	}
	close(FILE);
}

sub RemoveHTMLentities {
    my ($text) = @_;
    my (%entities, $key, $subst);
        
    %entities =  (  "&amp;"     =>  "&",
                    "&ndash;"   =>  "-",
                    "&lt;"      =>  "<",
                    "&gt;"      =>  ">",
                    "&quote;"   =>  "\"",
                    "&quot;"    =>  "\'"
                 );
    
    foreach $key (keys %entities)
        {
        $subst = $entities{$key};
        $text =~ s/$key/$subst/g;
        }
        
    return $text;
}

sub GetMediaPath {
    my ($medianame) = @_;
    my ($md5, $path, $fileprefix);

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
    $md5 = md5_hex($medianame);

    $fileprefix = substr($md5,0,1)."/".substr($md5,0,2);
    
    return $fileprefix;
}

sub ProcessImage {
	my ($title,$width)=@_;
	my ($path, $onlinepath, $outpath, $outfile, $langpath, $ext);
	
	#reject unsupported extensions
	if($title =~ m/\.([^\.]+)$/i) {$ext=$1;}
	unless($allowedexts{$ext}==1) {return 0;}
	
	$path=GetMediaPath($title);
	$title=GetMediaName($title);
	if($width==0) {
		$onlinepath="$fullmediaprefix/$path/$title";
	}
	else {
		$onlinepath="$thumbmediaprefix/$path/$title/${width}px-$title";
	}
	
	$outpath="$imgpath/$path";
	MakeDirs($outpath);
	$outfile="$outpath/".GetDiskName($title);
	$langpath=$onlinepath;
	
	print " ($path) ";

	if(-e "$outfile") {
		return 2;
	}
	else {
		$langpath=sprintf($onlinepath,"commons");
		#print " ($langpath) ";

		#`curl \"$langpath\" -o \"$outfile\" --fail --silent`;
		if(DownloadURL($langpath,$outfile)) {
			return 1;
		}
		else {
			#retry with Commons url
			$langpath=sprintf($onlinepath,$lang);
			#print " ($langpath) ";
			#`curl \"$langpath\" -o \"$outfile\" --fail --silent`;
			if(DownloadURL($langpath,$outfile)) {return 1;}
		}
	}
	
	#image was too large for thumb creation? getting full image
	if($width>0) {return ProcessImage($title,0);}
	else {return 0;}
}

sub GetMediaName {
    my ($medianame) = @_;

    # First-capitalize Unpack %xx hex-encoded characters, and convert resulting spaces in "_"
    $medianame = ucfirst $medianame;
    $medianame = RemoveHTMLentities($medianame);
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

sub GetDiskName {
	my ($title)=@_;
	my ($filetitle);
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

sub MakeDirs {
	my ($path)=@_;
	my ($subpath);
	while($path =~ /\//g) {
		$subpath=substr($path,0,pos($path));
		unless(-d "$subpath") {mkdir($subpath);}
	}
	unless(-d "$path") {mkdir($path);}
}

sub PlainAscii {
         my ($string) = @_;

	#print "$string";

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
        

	#print " -> $string\n";
	return $string;
}

sub DownloadURL {
    my ($URL,$outfile) = @_;
    my ($req, $res);

    $req = new HTTP::Request GET => $URL;

    # Pass request to the user agent and get a response back
    $res = $ua->request($req);

    # Check the outcome of the response
    if ($res->is_success)
    {
	open OUTFILE, ">$outfile";
	binmode OUTFILE;
        print OUTFILE $res->content;
        close OUTFILE;
        return 1;
    }
    else {
        return 0;
    }
}

sub InsertSorted {
	my ($elt)=@_;
	my ($high, $low, $mid, $test, $lcelt);
	$lcelt=lc $elt;
	
	$low=0;
	$high=@Titles-1;
	
	if($high==0) {push(@Titles, $elt); return 1;}
	else {
		if(lc($Titles[$high]) lt $lcelt) {push(@Titles, $elt); return 1;}
		elsif(lc($Titles[$low]) gt $lcelt) {unshift(@Titles, $elt); return 1;}
		else {
			while($high-$low>1) {
				$mid=int(($high+$low)/2);
				$test=lc($Titles[$mid]);
				if($test le $lcelt) {$low=$mid;}
				else {$high=$mid;}
			}
		}
	}
	
	splice(@Titles, $high, 0, $elt);
	return 1;
}

# Merge sort expects 3 parameters
# A reference to an array
# A start index of where to start sorting
# An end index of where to stop sorting
sub merge_sort {
    my ($array_ref, $start_index, $end_index) = @_;
    # Only do merge sort if there's a 1 element or greater sized array. No use for empty arrays.
    if ($start_index < $end_index) {
        # Calculate the middle of the array
        my $mid_index = int(($start_index + $end_index) / 2);
        # Call the merge sort on the left half of the array
        &merge_sort($array_ref, $start_index, $mid_index);
        # Call merge sort on the right half of the array
        &merge_sort($array_ref, $mid_index+1, $end_index);
        # Merge these two arrays together since they will be in order by now
        &merge($array_ref, $start_index, $end_index);
    }
}

sub merge {
    my ($array_ref, $start_index, $end_index) = @_;
    # calculate the middle of the array
    my $right_index = int(($start_index + $end_index) / 2) + 1;
    my $max_val = $end_index;
    my $left_index = $start_index;
    # While we don't exceed the bounds of the merge keep going.
    while ($right_index <= $max_val && $left_index <= $max_val) {
        # If the current item in the right array is bigger than the current
        # item in the left array, we need to move the right item to the current
        # position in the left array and shift the left array to the right by
        # one.
        if (lc $array_ref->[$right_index] lt lc $array_ref->[$left_index]) {
            # Store the right index value that needs to be brought to the front
            my $tmp = $array_ref->[$right_index];
            # Shift the left array over by 1 to the right to make room for the
            # smaller value
            for ($i = $right_index; $i >= $left_index; $i--) {
                $array_ref->[$i] = $array_ref->[$i-1];
            }
            # Swap in the value and change where the array indexes are located
            $array_ref->[$left_index] = $tmp;
            $left_index++;
            $right_index++;
        } else {
            # If the left item is greater than the right item you don't need to
            # do any swapping since it's already keeping the sort order correct
            # just make sure that the left index doesn't catch up to the right
            # index or you're already done sorting this level!
            $left_index++;
            if ($left_index >= $right_index) { return; }
        }
    }
}
