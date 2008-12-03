#!/bin/bash
set -e

# Checks
if [ "$1" = "" ]
then
  echo "Missing parameter"
  exit 1
fi
if [ ! -f ../R.in ]
then
  echo "Missing R.in file in the parent directory!"
  exit 2
fi
PWD=`pwd`
if [ "`basename $PWD`" != "workdir" ]
then
  echo "Start script must be run from the 'workdir' directory"
  exit 3
fi


# Create output directory
mkdir -p $1

# Create an input file from the master
cp -f ../R.in $1/R.in

# Replace the species number by the current parameter
# using a perl regular expression
perl -pi -e "s/Response=(.*)\[\d+:\d+\]/Response=\$1\[$1\]/" $1/R.in

# Change the path of every files, so that R will work
# into the output subdirectory
cd ..
for file in *
do
  perl -pi -e "s%($file)%\.\.\/\.\.\/\$1%g" workdir/$1/R.in
done

# Start R
cd workdir/$1
R CMD BATCH --no-save R.in /dev/stdout
