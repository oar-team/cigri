#! /bin/sh
# pl 2007-07-05

killall AlmightyCigri.pl 2>/dev/null

sleep 2

killall -0 AlmightyCigri.pl 2>/dev/null
if [ "$?" -ne 0 ] ; then
	exit 0
else
	exit 1
fi

