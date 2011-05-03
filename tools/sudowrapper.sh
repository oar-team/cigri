#!/bin/bash
export CIGRIDIR=
CIGRIUSER=
CMD=
exec sudo -H -u $CIGRIUSER $CIGRIDIR/bin/$CMD "$@"
