############### template_merge.sh ##################### 

check RUN_OUT MD5SUM MERGE CLEAN LOGDIR ANALYSIS_FINISHED_DIR \
      ANALYSIS_FINAL_DIR CASDIRLIST 

#merge by sample if MERGE is 1
if [[ $MERGE == 1 ]]; then
  echo -e "\nMerging fastq.gz files by sample .."
  cd $ANALYSIS_FINISHED_DIR/$RUN_OUT
  BCLDIRS=$(tr '\n' ' ' < $CASDIRLIST)  #get list of casava directories
  PROJDIR=$(find ${BCLDIRS%% *} -maxdepth 1 -name Project_* -type d | xargs basename) #get Project directory name
  mkdir -p $PROJDIR/Samplesheets
  if [[ $MSAMPLIST != "" ]]; then
    MSAMPS=$(cat $MSAMPLIST)
  else #get list of all samples in all BCLDIRS
    MSAMPS=$(cat $CASDIRLIST | xargs -IPLACE find PLACE/$PROJDIR -mindepth 1 -maxdepth 1 -type d | xargs -n1 basename | sort | uniq)
  fi
  #find samples that are in >1 lane
  declare -A MSAMP_COUNT;
  for BCLDIR in $BCLDIRS; do
    for MSAMP in $MSAMPS; do
      if [ -f $BCLDIR/$PROJDIR/$MSAMP.R1.fastq.gz ]; then
	MSAMP_COUNT["$MSAMP"]=$(( ${MSAMP_COUNT["$MSAMP"]-0} + 1 ));
      fi
    done
  done

  #merge samples
  for BCLDIR in $BCLDIRS; do
    LANE=`echo $BCLDIR | sed -e 's/^BclToFastq_Lane//' -e 's/_Index.*$//i'` #get lane number
    for MSAMP in $MSAMPS; do
      if [[ ${MSAMP_COUNT["$MSAMP"]-0} -gt 1 ]]; then
        if [ -f $BCLDIR/$PROJDIR/$MSAMP.R1.fastq.gz ]; then
          cat $BCLDIR/$PROJDIR/$MSAMP.R1.fastq.gz >> $PROJDIR/$MSAMP.R1.fastq.gz
          rm $BCLDIR/$PROJDIR/$MSAMP.R1.fastq.gz
        fi
        if [ -f $BCLDIR/$PROJDIR/$MSAMP.R2.fastq.gz ]; then
          cat $BCLDIR/$PROJDIR/$MSAMP.R2.fastq.gz >> $PROJDIR/$MSAMP.R2.fastq.gz
          rm $BCLDIR/$PROJDIR/$MSAMP.R2.fastq.gz
        fi
        cp $BCLDIR/$PROJDIR/$MSAMP/SampleSheet.csv $PROJDIR/Samplesheets/$MSAMP.lane$LANE.SampleSheet.csv
        rm -rf $BCLDIR/$PROJDIR/$MSAMP
      fi
      if [[ $(ls $BCLDIR/$PROJDIR | wc -l) == 0 ]]; then  #if there are no more files in this directory, remove it
        rm -rf $BCLDIR/$PROJDIR    #remove by-lane fastq.gz directory
      fi
    done
  done
  echo "Merging fastq.gz files by sample done."
fi

#clean final dir. Make sure dir depth is >= 3
if [ "$CLEAN" -eq 1 ] && [ "$(dirname $(dirname $ANALYSIS_FINAL_DIR/$RUN_OUT))" != / ]; then  
  echo -e "\nCleaning $ANALYSIS_FINAL_DIR .. "
  rm -rf $ANALYSIS_FINAL_DIR/$RUN_OUT
fi

#copy to final location
echo -e "\nCopying to $ANALYSIS_FINAL_DIR .. "
rsync -a $ANALYSIS_FINISHED_DIR/$RUN_OUT  $ANALYSIS_FINAL_DIR
cd $ANALYSIS_FINAL_DIR
echo "Copying to $ANALYSIS_FINAL_DIR done." 

#continue pipeline (checksums for final and finished dirs, if requested)
. $CASROOT/bin/template_md5sum.sh


