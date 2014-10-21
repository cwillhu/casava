
#Print error and exit 1
error () {
  printf "Error: %s\n" "$@"
  exit 1
} >&2


#Check var is set & print to STDOUT 
pcheck () { 
  for VAR; do
    eval "VAL=\$$VAR"
    printf '%s=%q\n' $VAR "$VAL"
    [[ $VAL != "" ]] || error "$VAR not set"
  done
}

#Check var is set 
check () { 
  for VAR; do
    eval "VAL=\$$VAR"
    [[ $VAL != "" ]] || error "$VAR not set"
  done
}

#Get runtype from input run directory
get_readtype () {
  PRIMARY_RUN_DIR=$1
  [[ -d $PRIMARY_RUN_DIR ]] || error "No such directory: $PRIMARY_RUN_DIR"
  [[ -e $PRIMARY_RUN_DIR/runParameters.xml ]] || error "runParameters.xml not found in $PRIMARY_RUN_DIR"
  BOOL=$(sed -nr 's!.*<PairEndFC>(true|false)</PairEndFC>.*!\1!p' $PRIMARY_RUN_DIR/runParameters.xml)
  case $BOOL in
    true)  READTYPE=paired;;
    false) READTYPE=single;;
  esac
  echo $READTYPE
}

#Write global variables to file
save_state () {
  {
    for VAR in $(cat $CASROOT/bin/vars.txt); do
      eval "VAL=\$$VAR"
      printf '%s=%q\n' $VAR "$VAL"
    done
  } > $1
}

#Extract Job ID from string returned by sbatch
get_jobID () {
  #example string: "Submitted batch job 3251221"
  echo $1 | sed -e 's/^.*job //' -e 's/ //g'
}

#Submit casava job to cluster
begin_job() {
  STAGE=$1 #casava, postprocess, fastqc, merge, md5sum or DBupdate
  shift
  LOGDIR=$1
  shift

  #default parameters
  PARTITION=informatics-dev
  NTASKS=1
  MEM=100
  SIZE=small
  TIME="2-0"
  PREVID=""
  MAILEND=1
  MAILFAIL=1
  MAILLIST="cwill,gmarnellos,cdaly"
#  MAILLIST="cwill"

  #read state
  . $LOGDIR/casava_state.sh

  #parse input options
  while [ $# != 0 ]; do #parse parameters
    case $1 in
      -ntasks)   NTASKS=$2; shift;;  
      -size)     SIZE=$2; shift;;  #big or small
      -mailend)  MAILEND=$2; shift;; #1 to mail at end of job, 0 otherwise
      -mailfail) MAILFAIL=$2; shift;; #1 to mail if job fails, 0 otherwise
      -maillist) MAILLIST=$2; shift;; #comma-separated list of usernames to email
      -after)    PREVID=$2; shift;;  #ID of job which must end or fail before this job is run
    esac
    shift
  done

  OUTNAME=$STAGE
  [[ $STAGE == "DBupdate" ]] && OUTNAME="DBupdate.$COMMAND"
  [[ $SIZE == "big" ]] && MEM=MaxMemPerNode


## Create slurm script                                                                      
  {
    echo '#!/bin/bash'
    echo "#SBATCH --partition=$PARTITION"
    echo "#SBATCH --ntasks-per-node=$NTASKS"
    echo "#SBATCH --nodes=1"
    echo "#SBATCH --mem=$MEM"
    echo "#SBATCH --output=$LOGDIR/$OUTNAME.%N.%j.out"
    echo "#SBATCH --error=$LOGDIR/$OUTNAME.%N.%j.err"
    echo "#SBATCH --job-name=$OUTNAME.$RUN_OUT"
    echo "#SBATCH --time=2-0"
    [[ $PREVID != "" ]] && echo "#SBATCH --dependency=afterany:$PREVID"
    [[ $MAILEND == 1 ]] && echo "#SBATCH --mail-type=END"
    [[ $MAILFAIL == 1 ]] && echo "#SBATCH --mail-type=FAIL"
    [[ $MAILEND == 1 || $MAILFAIL == 1 ]] && echo "#SBATCH --mail-user=$MAILLIST"
    echo "set -eu"
    echo ". $CASROOT/bin/utils.sh"
    cat $LOGDIR/casava_state.sh
    cat $CASROOT/bin/template_$STAGE.sh
  } > $LOGDIR/$OUTNAME.sh
  chmod u+x $LOGDIR/$OUTNAME.sh

  #Launch job 
  JOBSTR=$(sbatch $LOGDIR/$OUTNAME.sh)
  NEWID=$(get_jobID "$JOBSTR")
  echo $NEWID
}
  
