#!/bin/bash

############ consolidate_fastqgz.sh ########################

CASDIRLIST=$1
READTYPE=$2

for LANEDIR in $(cat $CASDIRLIST); do
  echo "****** Post-processing $LANEDIR .."

  ## consolidate demultiplexed fastq files
  echo "****** Consolidating fastq files .."
  for SAMPLEDIR in $LANEDIR/Project_*/Sample_* ; do
    [[ ! -d $SAMPLEDIR ]] && continue
    if [[ ! -e $SAMPLEDIR.R1.fastq.gz ]]; then
      gunzip -c $SAMPLEDIR/*_L00*_R1_*.fastq.gz | pigz -c -p 5 > $SAMPLEDIR.R1.fastq.gz
    fi
    if [[ $READTYPE == 'paired' && ! -e $SAMPLEDIR.R2.fastq.gz ]]; then
      gunzip -c $SAMPLEDIR/*_L00*_R2_*.fastq.gz | pigz -c -p 5 > $SAMPLEDIR.R2.fastq.gz    
    fi
  done

  ## consolidate undetermined barcode fastq files
  for SAMPLEDIR in $LANEDIR/Undetermined_indices/Sample_lane* ; do
    [[ ! -d $SAMPLEDIR ]] && continue
    if [[ ! -e $SAMPLEDIR.R1.fastq.gz ]]; then
      gunzip -c $SAMPLEDIR/lane*_Undetermined_L00*_R1_*.fastq.gz | pigz -c -p 5 > $SAMPLEDIR.Undetermined.R1.fastq.gz
    fi
    if [[ $READTYPE == 'paired' && ! -e $SAMPLEDIR.R2.fastq.gz ]]; then
      gunzip -c $SAMPLEDIR/lane*_Undetermined_L00*_R2_*.fastq.gz | pigz -c -p 5 > $SAMPLEDIR.Undetermined.R2.fastq.gz
    fi
  done

  ## create Undetermined_indices_ranks.txt file
  if [[ ! -e $LANEDIR/Undetermined_indices/Undetermined_indices_ranked.txt ]]; then
    instrument=`gunzip -c $LANEDIR/Undetermined_indices/Sample_*.R1.fastq.gz | head -1 | awk 'BEGIN { FS = ":" } {print $1}'`
    gunzip -c $LANEDIR/Undetermined_indices/Sample_*.R1.fastq.gz | grep "$instrument" | awk '{print $2}' | awk 'BEGIN { FS = ":" } {print $4}' | sort  | uniq -c | sort -nr > $LANEDIR/Undetermined_indices/Undetermined_indices_ranked.txt 
  fi
 
  #remove individual fastq files
  echo -e "****** Removing individual R1 fastq volumes .. "
  rm -f $LANEDIR/Project_*/Sample_*/*L00*_R1_*.fastq.gz
  rm -f $LANEDIR/Undetermined_indices/Sample_lane*/lane*_Undetermined_L00*_R1_*.fastq.gz

  if [ "$READTYPE" = 'paired' ]; then
    echo -e "****** Removing individual R2 fastq volumes .. "
    rm -f $LANEDIR/Project_*/Sample_*/*L00*_R2_*.fastq.gz
    rm -f $LANEDIR/Undetermined_indices/Sample_lane*/lane*_Undetermined_L00*_R2_*.fastq.gz
  fi
  echo "****** Post-processing $LANEDIR done."

done


