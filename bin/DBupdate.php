<?php

### Update database with current job status

$topdir = getenv('MINILIMS');  #this variable is set in casava.config 
require_once("$topdir/GlobalConfig.php");
require_once("$topdir/datamodel/Utils.php");
require_once("$topdir/plugins/Illumina/Illumina_RunInfoFile.php");
require_once("$topdir/plugins/Illumina/SampleSheet.php");

$run         = "";
$jobID       = "";
$store       = "";

$options = getopt("r:j:s:");

if (isset($options["r"])) { $run         = $options["r"]; }
if (isset($options["j"])) { $jobID       = $options["j"]; }
if (isset($options["s"])) { $store       = $options["s"]; }

if ($run == "" || $jobID == "" || $store == "") {
  print "DBupdate Error: All input parameters must be set.\n";
  print "Parameters:\n";
  print " run: $run\n jobID: $jobID\n store: $store\n";
  exit(1);
}

$table   = new Table('semantic_data');

#Get links to Submission objs for this run
$runinst = new TypeInstance("Illumina_Run",$run);
$runinst->fetch($table);
$sub_array = $runinst->getPropertyValues("Submission");

#Update submission objects: remove "NEW" status. Not setting to another value as this submission might span multiple Illumina runs.
foreach ($sub_array as $sub) {
  print("DBupdate: submission: $sub\n");
  $subinst = new TypeInstance("Submission",$sub);
  $subinst->fetch($table);
  $subinst->deleteProperty($table,"Status");
  if ($store) { $subinst->store($table); }
}

#Get link to analysis object for this run
$anal = $runinst->getPropertyValue("Illumina_BclConversion_Analysis");
$analinst = new TypeInstance("Illumina_BclConversion_Analysis",$anal);
$analinst->fetch($table);

print("DBupdate: run: $run\n");
print("DBupdate: analysis: $anal\n");

#Update analysis obj properties
$status = get_status($jobID);
$analinst->setPropertyValue("Status",$status);
$analinst->setPropertyValue("Output_Directory","/n/ngsdata/".$run);
$analinst->setPropertyValue("Web_Link","https://software.rc.fas.harvard.edu/ngsdata/".$run);
if ($store) { $analinst->store($table); }

exit(0);

function get_status($jobID) { #get job status from output of sacct                                                                           
  $jstatus = "";
  $mystr=shell_exec("sacct --parsable2 --brief -j$jobID");
  $elems=preg_split("/\|/",$mystr);
  if (count($elems) < 4) {
    $STDERR = fopen('php://stderr', 'w+');
    fwrite($STDERR, "Error: Job $jobID not properly launched.\n");
    exit();
  }
  $jstatus=$elems[3];
  print "Status of job $jobID at ".date('M d Y H:i:s').": $jstatus\n";
  return($jstatus);
}


