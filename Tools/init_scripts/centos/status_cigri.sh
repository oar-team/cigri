#! /bin/sh
# pl 2007-07-05

killall -0 AlmightyCigri.pl 2>/dev/null
if [ "$?" -eq 0 ] ; then
	echo "Running"
else
	echo "Not running"
fi


