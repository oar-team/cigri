#!/bin/bash

export CIGRIDIR=/var/lib/cigri/svn/cigri/branches/gsoc2009-scheduler
./Almighty/AlmightyCigri.pl|spc -c /etc/supercat/spcrc-cigri
