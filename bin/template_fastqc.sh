############ template_fastq.sh ##############

if [[ $FASTQC == 1 || $FASTQC_FORCE == 1 ]]; then
  for CASDIR in $(cat $CASDIRLIST); do

    SAMPLEFILES=$(ls $CASDIR/Project_*/Sample_*.R*.fastq.gz)
    NUMFILES=$(echo "$SAMPLEFILES" | wc -l)

    if [[ "$NUMFILES" -le "$FASTQC_RUNLIMIT" || "$FASTQC_FORCE" == 1 ]]; then 
      echo "Running FastQC for $CASDIR ..."
      FASTQCDIR=$CASDIR/FastQC
      mkdir -p $FASTQCDIR
      for SAMPLEFILE in $SAMPLEFILES; do
        fastqc -o $FASTQCDIR -t 6 --casava --noextract --nogroup $SAMPLEFILE
      done
    fi
  done
fi

#continue pipeline ( merge and checksums if requested, and copy to final directory)
. $CASROOT/bin/template_merge.sh

