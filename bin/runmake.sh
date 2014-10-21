############### runmake.sh ##########################################

## Usage: runmake.sh <run_directory_for_analysis> <casdirlist> <nthreads>

#!/bin/bash

RUN_DIR=$1
CASDIRLIST=$2
NTHREADS=$3

cd $RUN_DIR
for lanefolder in $(cat $CASDIRLIST); do
  cd $lanefolder
  echo -e "\nStarting lane: $lanefolder"
  nohup make -j $NTHREADS
  echo -e "\nFinished lane: $lanefolder"
  cd ..
done

######################################################################

