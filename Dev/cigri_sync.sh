
#!/bin/sh

if [ $# -ne 2 ]
then
	echo "Usage: $0 <local folder> <remote host>"
	exit -1
fi

 
rsync -auvz -e ssh \
    $1 \
    root@${2}:/home/cigri/CIGRI \
    --exclude "*svn*"  \
    --exclude "*~" 

