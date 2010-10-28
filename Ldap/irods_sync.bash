#!/bin/bash

# Quickly written script to synchronize cigri users into an irods
# server and deploy irods environment into users homes
# usage:
# ./irods_sync.bash [-f] [user]

CIGRI_GROUP=cigri-user
CIGRI_CONFIGFILE=/etc/cigri.conf
IRODS_ADMIN_HOST=quath.ujf-grenoble.fr
IRODS_ADMIN_USER=irods
IRODS_ADMIN_PATH=/applis/ciment/stow/x86_64/iRODS-2.4.1/clients/icommands/bin
IRODS_DEFAULT_HOST=quath.ujf-grenoble.fr
IRODS_DEFAULT_ZONE=cigri
IRODS_DEFAULT_PORT=1247
IRODS_INIT_CMD="/applis/ciment/stow/x86_64/iRODS-2.4.1/clients/icommands/bin/iinit"
PASSWD_BACKUP_FILE=~cigri/irods_passwords
IGNORE_CLUSTERS="browalle.ujf-grenoble.fr|cmserver.e-ima.ujf-grenoble.fr|p2chpd-cluster.univ-lyon1.fr|psmn-cluster.ens-lyon.fr|healthphy.ujf-grenoble.fr|zephir.mirage.ujf-grenoble.fr|edel.imag.fr|genepi.imag.fr"

touch $PASSWD_BACKUP_FILE
chmod 600 $PASSWD_BACKUP_FILE

# Load the cigri MySQL variables
CONF=`mktemp`
sed "s/ = /=/" /etc/cigri.conf > $CONF
. $CONF
rm -f $CONF

# Get the cluster list
OPTS="-B -h $DATABASE_HOST -u $DATABASE_USER_NAME -p$DATABASE_USER_PASSWORD -D $DATABASE_NAME --skip-column-names" 
CLUSTERS=`mysql $OPTS -e "select clusterName from clusters where clusterName not in (select clusterBlackListClusterName from clusterBlackList, events where eventState=\"ToFIX\" and clusterBlackListEventId=eventId and eventClass= \"CLUSTER\")" |awk '{print $1}'|egrep -v "$IGNORE_CLUSTERS"`

# Get the users of the cigri group
if [ "$1" != "" -a "$1" != "-f" ]
then
  USERS=$1
else
  USERS=`getent group $CIGRI_GROUP |cut -f 4 -d:|sed "s/,/ /g"`
fi

# Get the force option
if [ "$1" = "-f" -o "$2" = "-f" ]
then
  FORCE=1
else
  FORCE=0
fi

for user in $USERS
do
    echo "Checking $user"

    # Get or create user password
    password=`egrep "^$user:" $PASSWD_BACKUP_FILE |awk -F: '{print $2}'` 
    if [ "$password" = "" ]
    then
      echo "    generating password for $user"
      password=`mkpasswd $RANDOM`
      echo "$user:$password" >> $PASSWD_BACKUP_FILE
    else
      echo "    password for $user found into $PASSWD_BACKUP_FILE"
    fi

    # Check if the user is already into irods
    ssh $IRODS_ADMIN_USER@$IRODS_ADMIN_HOST "$IRODS_ADMIN_PATH/iadmin lu $user" |grep "No rows found" >/dev/null
    if [ $? -eq 0 ]
    then

      # Create an irods account
      echo "    Creating $user into IRODS..."
      ssh $IRODS_ADMIN_USER@$IRODS_ADMIN_HOST "$IRODS_ADMIN_PATH/iadmin mkuser $user rodsuser" || exit 1
      ssh $IRODS_ADMIN_USER@$IRODS_ADMIN_HOST "$IRODS_ADMIN_PATH/iadmin moduser $user password $password" || exit 1
    else
      echo "    IRODS user $user already exists."
    fi

    # Check users irods environments on the clusters
    for cluster in $CLUSTERS
    do
        # Check if the user already has an irods environment
        ALREADY=`ssh $cluster "sudo -H -u $user bash -c '[ -f ~/.irods/.irodsEnv ] && echo 1 || echo 0'"`
        if [ \( $? -eq 0 -a "$ALREADY" = "0" \) -o "$FORCE" = "1" ]
        then
          # Create an irods environment file
          echo "    Creating $cluster:~$user/.irods/.irodsEnv"
          ssh $cluster "sudo -H -u $user bash -c 'mkdir -p ~/.irods;chmod 700 ~/.irods'"
          ssh $cluster "sudo -H -u $user bash -c 'echo -e \"irodsHost $IRODS_DEFAULT_HOST\nirodsPort $IRODS_DEFAULT_PORT\nirodsUserName $user\nirodsZone $IRODS_DEFAULT_ZONE\" > ~/.irods/.irodsEnv'"
        fi

        # Check if the user already has an irods password file
        ALREADY=`ssh $cluster "sudo -H -u $user bash -c '[ -f ~/.irods/.irodsA ] && echo 1 || echo 0'"`
        if [ \( $? -eq 0 -a "$ALREADY" = "0" \) -o "$FORCE" = "1" ]
        then
          # Init irods password 
          echo "    Creating $cluster:~$user/.irods/.irodsA"
          ssh $cluster "sudo -H -u $user bash -c '$IRODS_INIT_CMD $password'"
        fi
    done
done
