#!/bin/bash
set -e

CLUSTERS="
           healthphy.ujf-grenoble.fr
           r2d2.obs.ujf-grenoble.fr
	   fostino.obs.ujf-grenoble.fr
	   browalle.ujf-grenoble.fr
	   genepi.imag.fr
	 "
EXECDIRPREFIX="/home/ciment/bzizou"
WALLTIME="01:00:00"

# Args test
if [ "$1" = "" -o ! -d "$1"  ]
then
  echo "Usage: $0 <directory>"
  exit 1
fi
DIR=`basename $1`

# Generate parameters file
if [ -f $DIR/R.in ]
then
  echo "Generating the parameters file..."
  RANGE=`perl -ne 'if (/Response.*Sp.Env\[(\d+):(\d+)\]/) {print "$1 $2";}' $DIR/R.in`
  if [ "$RANGE" != "" ]
  then
    rm -f params.txt
    for i in `seq $RANGE`
    do
      echo $i >> params.txt
    done
  else
    echo "Could not find the Sp.Env range!"
    exit 2
  fi
else
  echo "$DIR/R.in file not found!"
  exit 2
fi

# Make workdir and copy the start script
echo "Copying the starting script..."
cp -f startR.sh $DIR
mkdir -p $DIR/workdir

# Sync the directory with clusters and generate JDL file
echo "DEFAULT{
   name = $DIR;
   paramFile = params.txt;
}
" > biomod.jdl
for cluster in $CLUSTERS
do
  echo "Syncing $DIR to $cluster..."
  rsync -aRz -e ssh $DIR/ $cluster: || exit 3

  echo "$cluster{
    execDir = $EXECDIRPREFIX/$DIR/workdir;
    execFile = $EXECDIRPREFIX/$DIR/startR.sh;
    walltime = $WALLTIME;
}" >> biomod.jdl

done
echo "Sync done."

# Print some infos
echo
echo "Param file generated and $DIR synchronized on the clusters."
echo "You can start the grid job with:"
echo "  gridsub -f biomod.jdl"
echo 
