#!/bin/sh

PREFIX="[CIGRI/OAR LAUNCHER]"
NODEFILE=$OAR_NODEFILE
OUTPUT="env.sh"
NBCLUSTERS=1
CLEAN="false"
KILL="false"

print_usage () {
 echo "Usage: $0 [options] "
 echo "Options are:"
 echo "   -f  <nodefile>       File containing nodes, by default $OAR_NODEFILE"
 echo "   -n  integer          Number of CiGri clusters"
 echo "   -o  <outputfile>     Output file including env., by default env.sh"
 echo "   -c                   Cleanup all databases "
 echo "   -k                   Kill daemons"
 echo "   -s                   Cleanup all databases on nodes and kill daemons"
 echo "   -h                   Print this help message"
}

print_env () {
echo "#!/bin/sh"
echo
echo "export CIGRI_SERVER=$1"
shift

n=0
for server in "$@"
do
    echo "export CIGRI_CLUSTER${n}=${server}"
	let "n++"
done
}

while getopts "f:n:o:hc" options; do
  case $options in
    f ) NODEFILE=$OPTARG;;
    n ) NBCLUSTERS=$OPTARG;;
    k ) KILL="true";;
    c ) CLEAN="true";;
    s ) KILL="true";CLEAN="true";;
    o ) OUTPUT=$OPTARG;;
    h ) print_usage
         exit 0;;
    \? ) print_usage
         exit 1;;
  esac
done

if [ ! -f $NODEFILE ]
then
        echo "$PREFIX ERROR invalid nodefile" >&2
        print_usage
        exit -1
fi

if [ "$KILL" = 'true' ]
then

	if [ -z "$CIGRI_SERVER" ]
	then
    	echo "$PREFIX CIGRI_SERVER must be set" >&2
    exit 1
	fi

	echo "$PREFIX Killing OAR and CiGri daemons"
	#kill daemons
	PID=`ps aux | grep ssh | grep SSHcmd | cut -d " " -f2`
	kill -9 $PID

	ssh root@${CIGRI_SERVER} killall /usr/bin/perl
	
	if [ "$CLEAN" != 'true' ] 
	then
		echo "$PREFIX Done"
		exit 0
	fi

fi

if [ "$CLEAN" = 'true' ]
then

    if [ -z "$CIGRI_SERVER" ]
    then
        echo "$PREFIX CIGRI_SERVER must be set" >&2
    exit 1
    fi


	echo "$PREFIX Cleaning databases"
    #cleanup databases
    sort -u $NODEFILE | while read node
    do  
        ssh root@${node} "mysql -D oar < /usr/lib/oar/mysql_structure.sql"
        ssh root@${node} "mysql -D cigri < /home/cigri/CIGRI/DB/cigri_db.sql"
    done #2>/dev/null

	echo "$PREFIX Done"
	exit 0

fi


if [ $NBCLUSTERS -le 0 ]
then
        echo "$PREFIX ERROR num of clusters <= 0" >&2
        print_usage
        exit -1
fi

NBNODES=`sort -u $NODEFILE | wc -l`

let "HALF_NBNODES=$NBNODES/2"

if [ $NBCLUSTERS -gt $HALF_NBNODES ]
then
        echo "$PREFIX ERROR clusters > $HALF_NBNODES. Each cluster must have at least 2 nodes" >&2
        print_usage
        exit -1
fi



echo "-------------------------"
echo "$PREFIX Starting CiGri/OAR :"
echo "   NODEFILE = $NODEFILE "
echo "   NBNODES = $NBNODES "
echo "   NBCLUSTERS = $NBCLUSTERS "
echo "   OUTPUT = $OUTPUT"
echo "-------------------------"

let "NODESBYCLUSTER= $NBNODES / $NBCLUSTERS"

CIGRI_SERVER=$(sort -u $NODEFILE | sed '1!d')

ENV_PARAM="$CIGRI_SERVER "

LASTNODE_LINE=0

for i in `seq 1 $NBCLUSTERS`
do
	let "SERVER_LINE=$LASTNODE_LINE+1"
	let "FIRSTNODE_LINE=$SERVER_LINE+1"

	CIGRI_CLUSTER=$(sort -u $NODEFILE | sed "$SERVER_LINE!d")
	ENV_PARAM="$ENV_PARAM $CIGRI_CLUSTER"

	if [ $i -eq $NBCLUSTERS ]
	then
		let "LASTNODE_LINE=$NBNODES"
	else
		let "LASTNODE_LINE=$SERVER_LINE+$NODESBYCLUSTER-1"
	fi

	echo "$PREFIX Starting OAR server on $CIGRI_CLUSTER"
	sort -u $NODEFILE | sed -n "${FIRSTNODE_LINE},${LASTNODE_LINE}p"  | ssh -l g5k $CIGRI_CLUSTER "xargs /home/g5k/launch_OAR.sh" 

	echo "$PREFIX cluster $CIGRI_CLUSTER to CiGri"
	ssh -l g5k $CIGRI_SERVER "/home/g5k/add_cluster_in_CIGRI.sh $CIGRI_CLUSTER"

done


print_env $ENV_PARAM > $OUTPUT


(ssh g5k@$CIGRI_SERVER "(sudo -u cigri /home/cigri/CIGRI/Net/SSHcmdServer.pl)&")&

(ssh g5k@$CIGRI_SERVER "(sudo -u cigri /home/cigri/CIGRI/Almighty/AlmightyCigri.pl > cigri.log)&")&




