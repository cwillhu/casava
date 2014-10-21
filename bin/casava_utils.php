<?php 
/**
 * casava_utils.php
 */
function split_samplesheet($samplesheet,$lanenums,$outputdir) {
  $csvstr = file_get_contents($samplesheet);
  $lines = explode("\n", $csvstr);
  $seen_index_lengths = array();
  $ss_filenames = array();

  $linenum = 0;
  foreach ($lines as $l) { #for each line of file
    if (preg_match("/^[,\s]*$/",$l)) { continue; } #line contains only commas and/or whitespace. Go to next line.
    $fields = explode(",", $l);
    if (sizeof($fields) > 7 && $linenum > 0) { # check linenum > 0 in order to skip header line
      // FCID           Flowcell ID
      // Lane           1-2 or 1-8
      // SampleID       Sample ID
      // Sample Ref     Reference sequence for the sample
      // Index          Index sequence
      // Description    
      // Control        Y/N
      // Recipe         Index lengths
      // Operator       
      // SampleProject
      if ($linenum==1) { $flowcellid = strtoupper($fields[0]); }
      $lanenum    = $fields[1];
      $sampleid   = $fields[2];
      $sampleref  = $fields[3];
      $index      = $fields[4];
      $desc       = $fields[5];
      $control    = $fields[6];
      $recipe     = $fields[7];
      $operator   = "";
      if (sizeof($fields) > 8) { $operator   = $fields[8]; }

      //$sampleproject   = "";
      //if (sizeof($fields) > 9) { $sampleproject = $fields[9]; }
      //Instead of passing along sampleproject value as above, setting all values to flowcellid. 
      //This prevents many separate output directories from being created, when different values for this parameter are present
      $sampleproject = $flowcellid;

      if (!in_array($lanenum,$lanenums)) { continue; }

      if (!isset($seen_index_types[$lanenum])) {  #initialize set of index types for this lane
	$seen_index_types[$lanenum] = array();
      }

      $indextype = $recipe;  #format: <index1_length> OR <index1_length>_<index2_length>
      if (!in_array($indextype, $seen_index_types[$lanenum])) {
        $seen_index_types[$lanenum][] = $indextype;
	$header = "FCID,Lane,SampleID,SampleRef,Index,Description,Control,Recipe,Operator,SampleProject\n";
        $ss_filename = "SampleSheet.lane$lanenum.indexlength_$indextype.csv";
	file_put_contents("$outputdir/$ss_filename", $header);
        $ss_filenames[] = $ss_filename;
      } 

      ###
      # Clip or extend index to true length, if necessary.
      ###

      $lengths = preg_split("/-|_/", $indextype);
      $rl1 = $lengths[0];  #rl is real length
      $rl2 = 0;
      if (isset($lengths[1])) { $rl2 = $lengths[1]; }

      $indices = preg_split("/-/", $index);
      $i1 = $indices[0];
      $i2 = "";
      if (isset($indices[1])) { $i2 = $indices[1]; }

      if (strlen($i1) < $rl1) {  #lengthen first index
	$i1 = $i1 . str_repeat("A", $rl1 - strlen($i1));
      } elseif (strlen($i1) > $rl1) {  #shorten first index
        $i1 = substr("$i1", 0, $rl1);
      }
      $realindex = $i1;

      if ($rl2 > 0) {
	if (strlen($i1) < $rl1) {  #lengthen second index
	  $i1 = $i1 . str_repeat("A", $rl1 - strlen($i1));
	} elseif (strlen($i1) > $rl1) {  #shorten second index
	  $i1 = substr("$i1", 0, $rl1);
	}
        $realindex = $realindex . "-" . $i2;
      }

      #write line out to file
      if ($realindex == "") {
        $new_sampleid = $sampleid . "_noindex";
      } else {
        $new_sampleid = $sampleid . "_$realindex";
      }
      $line = "$flowcellid,$lanenum,$new_sampleid,$sampleref,$realindex,$desc,$control,$recipe,$operator,$sampleproject\n";
      file_put_contents("$outputdir/SampleSheet.lane$lanenum.indexlength_$indextype.csv", $line, FILE_APPEND);

    } 
    $linenum++;
  } #foreach line in file

  return $ss_filenames;
} #function split_samplesheet 

function get_index_lengths($ss_filepath) {
  $csvstr = file_get_contents($ss_filepath);
  $lines = explode("\n", $csvstr);
  $dataline = $lines[1];
  $fields = explode(",", $dataline);
  $index_type = $fields[7];
  $index_lengths = explode("_",$index_type);
  return $index_lengths;
} #function get_index_lengths

function get_lane_num($ss_filepath) {
  $csvstr = file_get_contents($ss_filepath);
  $lines = explode("\n", $csvstr);
  $dataline = $lines[1];
  $fields = explode(",", $dataline);
  $lanenum = $fields[1];
  return $lanenum;
} #function get_lane_num


