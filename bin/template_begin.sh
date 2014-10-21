############### template_begin.sh ##################### 

STARTTIME=$(date +%s)
echo "Illumina run: $RUN"

echo -e "\nLoading software modules needed by job"
module load hpc/rsync-3.0.7
module load centos6/perl5mods
module load centos6/perl-5.8.8 

#module load bio/CASAVA-1.8.2
export PATH=$PATH:/n/home_rc/cwill/sw/bcl2fastq/bin/bin
export PERL5LIB=$PERL5LIB:/n/home_rc/cwill/sw/bcl2fastq/bin/lib/bcl2fastq-1.8.3/perl

#clean analysis directory
echo "Clean analysis directory..."
if [[ $CLEAN == 1 ]]; then 
  rm -rf $ANALYSIS_IN_PROGRESS_DIR/$RUN_OUT
fi
mkdir -p $ANALYSIS_IN_PROGRESS_DIR/$RUN_OUT

#Initialize records in database; set status to "RUNNING"
php $CASROOT/bin/DBinit.php -r $RUN -j $SLURM_JOB_ID -s $STORE -d $PRIMARY_DATA_DIR/$RUN 

#Build BCL conversion command
echo -e "Building Bcl conversion command .. \n"
dos2unix -kq $PRIMARY_DATA_DIR/$RUN/SampleSheet.csv
php $CASROOT/bin/buildBclCommand.php \
                            -i $PRIMARY_DATA_DIR/$RUN \
                            -o $ANALYSIS_IN_PROGRESS_DIR/$RUN_OUT \
                            -l "$LANES" -f $FILTER -t "$TILES" \
                            -b $IGNORE_NOBCL \
                            -g $IGNORE_NOCONTROL \
                            -m $MISMATCHES \
                            -c $LOGDIR/bcl_commands.sh \
                            -d $CASDIRLIST 
chmod u+x $LOGDIR/bcl_commands.sh

#run casava
echo -e "\nRunning bcl commands .. "
$LOGDIR/bcl_commands.sh

echo -e "Running make commands .. "
$CASROOT/bin/runmake.sh $ANALYSIS_IN_PROGRESS_DIR/$RUN_OUT $CASDIRLIST $NTHREADS

#continue pipeline (copy to finished_dir, consolidate intemediate fastq files, run fastqc and md5sum if requested...)
. $CASROOT/bin/template_postprocess.sh

#indicate that casava finished for this run.
touch $PRIMARY_DATA_DIR/$RUN/casava_finished.txt

#log runtime
TIME=$(($(date +%s) - STARTTIME))
NLANES_PROCESSED=$(echo $LANES | wc -w)
echo "$RUN_OUT $TIME $NLANES_PROCESSED $NTHREADS" >> $CASROOT/cron/times.txt
