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
IRODS_DEFAULT_HOST=ciment-icat.ujf-grenoble.fr
IRODS_DEFAULT_ZONE=cigri
IRODS_DEFAULT_PORT=1247
IRODS_INIT_CMD="/applis/ciment/stow/x86_64/iRODS-2.4.1/clients/icommands/bin/iinit"
PASSWD_BACKUP_FILE=~cigri/irods_passwords
IGNORE_CLUSTERS="browalle.ujf-grenoble.fr|cmserver.e-ima.ujf-grenoble.fr|p2chpd-cluster.univ-lyon1.fr|psmn-cluster.ens-lyon.fr|healthphy.ujf-grenoble.fr|zephir.mirage.ujf-grenoble.fr|edel.imag.fr"
ADD_HOSTS="killeen.ujf-grenoble.fr"
DEFAULT_QUOTA=500000000000
SSH_COMMAND="ssh -o BatchMode=yes"

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
CLUSTERS="$CLUSTERS $ADD_HOSTS"

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
    $SSH_COMMAND $IRODS_ADMIN_USER@$IRODS_ADMIN_HOST "$IRODS_ADMIN_PATH/iadmin lu $user" |grep "No rows found" >/dev/null
    if [ $? -eq 0 ]
    then

      # Create an irods account
      echo "    Creating $user into IRODS..."
      $SSH_COMMAND $IRODS_ADMIN_USER@$IRODS_ADMIN_HOST "$IRODS_ADMIN_PATH/iadmin mkuser $user rodsuser" || exit 1
      $SSH_COMMAND $IRODS_ADMIN_USER@$IRODS_ADMIN_HOST "$IRODS_ADMIN_PATH/iadmin moduser $user password $password" || exit 1
      $SSH_COMMAND $IRODS_ADMIN_USER@$IRODS_ADMIN_HOST "$IRODS_ADMIN_PATH/iadmin atg cigri $user" || exit 1
    else
      echo "    IRODS user $user already exists."
    fi

      # Set quota for the newly created user
      echo "    Setting intial irods quota for $user..."
      $SSH_COMMAND $IRODS_ADMIN_USER@$IRODS_ADMIN_HOST "$IRODS_ADMIN_PATH/iadmin suq $user total $DEFAULT_QUOTA" || exit 1

    # Check users irods environments on the clusters
    for cluster in $CLUSTERS
    do
        # Get the remote username
        echo "    Getting remote login name for $user on $cluster..."
        remote_user=`mysql $OPTS -e "select userLogin from users where userGridName=\"$user\" and userClusterName=\"$cluster\""`
        if [ "$remote_user" = "" ]
        then
          remote_user=$user
        fi 
               
        # Check if the user already has an irods environment
        echo "    Checking $remote_user on $cluster..."
        ALREADY=`$SSH_COMMAND $cluster "sudo -H -u $remote_user bash -c '[ -f ~/.irods/.irodsEnv ] && echo 1 || echo 0'"`
        if [ $? -eq 0  -a \( "$ALREADY" = "0" -o "$FORCE" = "1" \) ]
        then
          # Create an irods environment file
          echo "    Creating $cluster:~$remote_user/.irods/.irodsEnv"
          $SSH_COMMAND $cluster "sudo -H -u $remote_user bash -c 'mkdir -p ~/.irods;chmod 700 ~/.irods'"
          $SSH_COMMAND $cluster "sudo -H -u $remote_user bash -c 'echo -e \"irodsHost $IRODS_DEFAULT_HOST\nirodsPort $IRODS_DEFAULT_PORT\nirodsUserName $user\nirodsZone $IRODS_DEFAULT_ZONE\" > ~/.irods/.irodsEnv'"
        fi

        # Check if the user already has an irods password file
        ALREADY=`$SSH_COMMAND $cluster "sudo -H -u $remote_user bash -c '[ -f ~/.irods/.irodsA ] && echo 1 || echo 0'"`
        if [ $? -eq 0 -a \( "$ALREADY" = "0" -o "$FORCE" = "1" \) ]
        then
          # Init irods password 
          echo "    Creating $cluster:~$remote_user/.irods/.irodsA"
          $SSH_COMMAND $cluster "sudo -H -u $remote_user bash -c '$IRODS_INIT_CMD $password'"
        fi
    done
done
