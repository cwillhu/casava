############ template_md5sum.sh ##############

#do checksums for final and finished dirs. 
if [[ $MD5SUM == 1 ]]; then
  echo "****** Calculating checksums .. "
  cd $ANALYSIS_FINAL_DIR
  find $RUN_OUT/ -type f -name *.fastq.gz -exec md5sum {} \; > $LOGDIR/md5sum.txt
  echo "****** $ANALYSIS_FINAL_DIR checksums done."
  cp $LOGDIR/md5sum.txt $RUN_OUT/.

  cd $ANALYSIS_FINISHED_DIR
  find $RUN_OUT/ -type f -name *.fastq.gz -exec md5sum {} \; > $LOGDIR/md5sum.analysis_finished.txt
  echo "****** $ANALYSIS_FINISHED_DIR checksums done."
  cp $LOGDIR/md5sum.analysis_finished.txt $RUN_OUT/.
fi

#ensure file permissions are set correctly
#echo "Setting file permissions in finished and final dirs .."
#find $ANALYSIS_FINISHED_DIR/$RUN_OUT -type d -exec chmod o+rx {} \;
#find $ANALYSIS_FINISHED_DIR/$RUN_OUT -type f -exec chmod o+r {} \;

#find $ANALYSIS_FINAL_DIR/$RUN_OUT -type d -exec chmod o+rx {} \;
#find $ANALYSIS_FINAL_DIR/$RUN_OUT -type f -exec chmod o+r {} \;
