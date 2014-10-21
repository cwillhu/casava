<?php

$topdir = getenv('MINILIMS');  #these environment variables are set in casava.config
$casroot = getenv('CASROOT');  

require_once("$topdir/GlobalConfig.php");
require_once("$topdir/datamodel/Utils.php");
require_once("$topdir/plugins/Illumina/Illumina_RunInfoFile.php");
require_once("$topdir/plugins/Illumina/SampleSheet.php");
require_once("$topdir/plugins/Illumina/SampleSheet.php");

$inputdir     = ""; 
$outputdir    = "";
$laneslist    = "";
$filter       = "";
$tiles        = "";
$cmdfile      = "";
$ignore_nobcl = "";
$ignore_nocontrol = "";
$mismatches   = "";

$options = getopt("i:o:m:l:f:t:b:c:d:r:g:"); 
if (isset($options["i"])) { $inputdir       = $options["i"]; }
if (isset($options["o"])) { $outputdir      = $options["o"]; }
if (isset($options["m"])) { $mismatches     = $options["m"]; } 
if (isset($options["l"])) { $laneslist      = $options["l"]; } 
if (isset($options["f"])) { $filter         = $options["f"]; }
if (isset($options["t"])) { $tiles          = $options["t"]; }
if (isset($options["b"])) { $ignore_nobcl   = $options["b"]; } 
if (isset($options["b"])) { $ignore_nocontrol = $options["g"]; } 
if (isset($options["c"])) { $cmdfile        = $options["c"]; } 
if (isset($options["d"])) { $folderlistfile = $options["d"]; } 

if ($inputdir == "" || $outputdir == "" || $mismatches == "" || $laneslist == "" || $filter == "" 
    || $cmdfile == "" || $ignore_nobcl == "" || $folderlistfile == "" || $casroot == "" ) {
  print "ERROR: All parameters except for tiles (-t)  must be set:\n";
  print "Parameters:\n";
  print " inputdir: $inputdir\n parentout: $outputdir\n laneslist: $laneslist\n mismatches: $mismatches\n";
  print " filter: $filter\n tile: $tiles\n cmdfile: $cmdfile\n ignore_nobcl: $ignore_nobcl\n ignore_nocontrol: $ignore_nocontrol\n";
  print " folderlistfile: $folderlistfile\n";
  exit(1);
}

require_once("$casroot/bin/casava_utils.php");

$samplesheet = "$inputdir/SampleSheet.csv";
if (!is_file($samplesheet)) {
  print "ERROR: Samplesheet file [$samplesheet] doesn't exist\n\n";
  exit(1);
}

#Read RunInfo file
$rfile = "$inputdir/RunInfo.xml";
print "Parsing RunInfo file: $rfile\n";
$rif = new Illumina_RunInfoFile($rfile);
$rif->parse();
$table = new Table('semantic_data');
$runinst = $rif->getRunInstance();
print $runinst->printValues() . "\n";

$lanenums = explode(" ", $laneslist); #lanenums contains the numbers of the lanes to be processed
$ss_filenames = split_samplesheet($samplesheet, $lanenums, $outputdir); #split samplesheet by lane, and then by index length

$cmds = "";
$casava_outputdirs = "";
foreach ($ss_filenames as $ss_filename) { 

  // Construct the bases mask
  $index_lengths = get_index_lengths("$outputdir/$ss_filename");
  $bases_mask    = "";
  $readnum       = 1;
  $indexnum      = 0;
  while ($runinst->getPropertyValue("Read $readnum Cycles") != "") {
    if ($readnum > 1) { $bases_mask .= ","; }
    $length = $runinst->getPropertyValue("Read $readnum Cycles");
    $index  = $runinst->getPropertyValue("Read $readnum Index");

    if ($index == "Y") {
      if (isset($index_lengths[$indexnum])) {
	$tmpstr1 = "I".$index_lengths[$indexnum];
	$tmpstr2 = str_repeat("N",$length-$index_lengths[$indexnum]);
      } else {
	$tmpstr1 = str_repeat("N",$length);
	$tmpstr2 = "";
      }
      $bases_mask .= $tmpstr1 . $tmpstr2;
      $indexnum++;
    } else {
      $bases_mask .= "Y";
      $bases_mask .= $length-1; 
      $bases_mask .= "N"; 
      //$bases_mask .= $length; //gm changed mask to call all read cycles in a certain dataset (Magali's)
    }
    $readnum++;
  }

  // Construct the command line.
  $params = "";
  if ($ignore_nobcl == 1) {
    $params = $params."--ignore-missing-bcl ";
  }

  if ($ignore_nocontrol == 1) {
    $params = $params."--ignore-missing-control ";
  }

  if ($filter == 0) {
    $params = $params."--with-failed-reads "; //turn off chastity filter
  }

  if ($mismatches > 0) {
    $params = $params."--mismatches $mismatches "; //specify number of mismatches
  }

  $lanenum = get_lane_num("$outputdir/$ss_filename");
  if (empty($tiles)) {
    $params = $params."--tiles s_$lanenum "; //regex for tile selection
  } else {
    $params = $params."--tiles '$tiles' ";
  }

  $index_type = implode("-",$index_lengths);
  $j = 1;
  $casava_outputdir = "BclToFastq_Lane${lanenum}_Indexlength${index_type}_Run$j";
  while (is_dir("$outputdir/$casava_outputdir")) {
    $j++;
    $casava_outputdir = "BclToFastq_Lane${lanenum}_Indexlength${index_type}_Run$j";
  }

  $cmd = "configureBclToFastq.pl \
             --ignore-missing-stats \
             --input-dir $inputdir/Data/Intensities/BaseCalls \
             --output-dir $outputdir/$casava_outputdir \
             --sample-sheet $outputdir/$ss_filename \
             --use-bases-mask \"$bases_mask\" \
             $params";    

  $cmds = $cmds . $cmd . "\n";
  $casava_outputdirs = $casava_outputdirs . $casava_outputdir . "\n";
}

file_put_contents($cmdfile,$cmds);
file_put_contents($folderlistfile,$casava_outputdirs);

