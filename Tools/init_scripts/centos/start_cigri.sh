#! /bin/sh
# pl 2007-07-05

CIGRI_INSTALL_PATH=$(grep "INSTALL_PATH" /etc/cigri.conf  | sed -e 's/.*= *"\(.*\)"/\1/g')

cd "$CIGRI_INSTALL_PATH"

nohup ./Almighty/AlmightyCigri.pl > cigri.log 2>/dev/null &

sleep 2

killall -0 AlmightyCigri.pl 2>/dev/null

if [ "$?" -eq 0 ] ; then
	exit 0
else
	exit 1
fi

