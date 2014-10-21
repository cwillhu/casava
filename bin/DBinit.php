<?php
$topdir = getenv('MINILIMS');  #this variable is set in casava.config
require_once("$topdir/GlobalConfig.php");
require_once("$topdir/datamodel/Utils.php");
require_once("$topdir/plugins/Illumina/Illumina_RunInfoFile.php");
require_once("$topdir/plugins/Illumina/SampleSheet.php");

$run       = "";
$rundir    = "";
$jobID     = "";
$store     = "";  #set to 1 to store data, 0 otherwise

$options = getopt("r:d:c:j:s:");

if (isset($options["r"])) { $run        = $options["r"]; }
if (isset($options["d"])) { $rundir     = $options["d"]; }
if (isset($options["j"])) { $jobID      = $options["j"]; }
if (isset($options["s"])) { $store      = $options["s"]; }

if ($run == "" || $rundir == "" || $jobID == "" || $store == "") {
  print "DBinit Error: All input parameters must be set.\n";
  print "Parameters:\n";
  print " run: $run\n rundir: $rundir\n jobID: $jobID\n store: $store\n"; 
  exit(1);
}

$table   = new Table('semantic_data');

#Get list of any existing analysis instances for this run
$out1  = PGQuery($table,"*:Illumina_BclConversion_Analysis:Illumina_Run:$run","",array("Illumina_BclConversion_Analysis"),0);
$old_analnames = $out1->getTypeNameArray('Illumina_BclConversion_Analysis');

#Get name for current analysis instance
$curaname="";
if (count($old_analnames) == 0){ #if no analysis objects exist, get name for a new one
  $curaname = Type::getNewTypeName($table,"Illumina_BclConversion_Analysis");
} elseif (count($old_analnames) == 1){ #if there is one analysis obj, set to current
  $curaname = $old_analnames[0];
} elseif (count($old_analnames) > 1){ #if there are many old analyses, delete all but one
  $curaname = $old_analnames[0];
  for($i=1;$i<count($old_analnames);$i++) {
    $tmpinst = new TypeInstance("Illumina_BclConversion_Analysis",$old_analnames[$i]);
    $tmpinst->delete($table);
  }
}

#set run properties
$runinst = new TypeInstance("Illumina_Run",$run);  #local Illumina_Run object; may already exist in database
$runinst->fetch($table);
$runinst->setPropertyValue("Illumina_BclConversion_Analysis",$curaname);

#set analysis obj properties
$analinst = new TypeInstance("Illumina_BclConversion_Analysis",$curaname); #local instance
$analinst->setPropertyValue("Illumina_Run",$run);
$analinst->setPropertyValue("Status","RUNNING");
$analinst->setPropertyValue("Launch_Timestamp",date('M d Y H:i:s'));
$analinst->setPropertyValue("Job_ID",$jobID);
$analinst->setPropertyValue("Status","RUNNING");

#Add links to/from Submission objects and Run, Analysis objects
$unique_subIDs = getSubIDs("$rundir/SampleSheet.csv");
foreach($unique_subIDs as $subID) {
  $subinst = new TypeInstance("Submission",$subID);
  $subinst->fetch($table);
  print $subinst->printValues();

  $subinst->addPropertyValue("Illumina_Run",$run);
  $runinst->addPropertyValue("Submission",$subID);
  $analinst->addPropertyValue("Submission",$subID);

  if ($store) { $subinst->store($table); }
}

if ($store) { 
  $analinst->store($table); 
  $runinst->store($table); 
}
exit(0);

function getSubIDs($SSfile) { #get Submission IDs from SampleSheet file                  
  print "Extracting Submission IDs from $SSfile\n";
  $filestr = file_get_contents($SSfile);
  $lines = explode("\n", $filestr);
  $subIDs= array();
  for($i=1;$i<count($lines);$i++) {  #skip header line..  
    $fields = explode(",", $lines[$i]);
    if (count($fields) > 6) {
      $subIDs[$i-1] = $fields[5];
    }
  }
  return(array_unique($subIDs));
}

