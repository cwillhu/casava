############### template_postprocess.sh ##################### 

check RUN_OUT RUN FASTQC LOGDIR READTYPE CLEAN PRIMARY_DATA_DIR ANALYSIS_IN_PROGRESS_DIR \
      ANALYSIS_FINISHED_DIR ANALYSIS_FINAL_DIR CASDIRLIST

module load bio/fastqc-0.10.0
module load hpc/rsync-3.0.7
module load hpc/pigz-2.1.6

#clean finished dir. Make sure dir depth is >= 3 
if [[ $CLEAN == 1 && "$(dirname $(dirname $ANALYSIS_FINISHED_DIR/$RUN_OUT))" != / ]]; then
  rm -rf $ANALYSIS_FINISHED_DIR/$RUN_OUT
fi

#copy casava output from progress_dir to finished_dir 
echo -e "\nCopying to finished_dir: $ANALYSIS_FINISHED_DIR .. "
rsync -a $ANALYSIS_IN_PROGRESS_DIR/$RUN_OUT  $ANALYSIS_FINISHED_DIR/
echo -e "Copying to finished_dir: $ANALYSIS_FINISHED_DIR done.\n"

#remove .sentinel files in finished_dir 
cd $ANALYSIS_FINISHED_DIR/$RUN_OUT
for FILE in $(find . -name .sentinel); do
  rm -f $FILE
done

#copy run info files from primary_dir to finished_dir
cd $PRIMARY_DATA_DIR/$RUN
rsync -a InterOp RunInfo.xml runParameters.xml SampleSheet.csv $ANALYSIS_FINISHED_DIR/$RUN_OUT/
chmod -R g+rwx $ANALYSIS_FINISHED_DIR/$RUN_OUT
chmod -R o+rx $ANALYSIS_FINISHED_DIR/$RUN_OUT

#consolidate fastq files
cd $ANALYSIS_FINISHED_DIR/$RUN_OUT
$CASROOT/bin/consolidate_fastqgz.sh $CASDIRLIST $READTYPE

#continue pipeline (run fastqc and md5sum if requested, copy to final directory)
. $CASROOT/bin/template_fastqc.sh


