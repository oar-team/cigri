#!/bin/bash

# Intented to be used on a CIGRI host connected to an LDAP server
# on which all the clusters are also connected.
# A special group defines the cigri users that are to be automaticaly
# included into the cigri user's table

CIGRI_GROUP=cigri-user
CIGRI_CONFIGFILE=/etc/cigri.conf


# Load the cigri MySQL variables
CONF=`mktemp`
sed "s/ = /=/" /etc/cigri.conf > $CONF
. $CONF
rm -f $CONF

# Get the cluster list
OPTS="-B -h $DATABASE_HOST -u $DATABASE_USER_NAME -p$DATABASE_USER_PASSWORD -D $DATABASE_NAME --skip-column-names" 
CLUSTERS=`mysql $OPTS -e "select clusterName from clusters" |awk '{print $1}'`


# Get the users of the cigri group
USERS=`getent group $CIGRI_GROUP |cut -f 4 -d:|sed "s/,/ /g"`
for user in $USERS
do
  # If user is already in database, do nothing
  ALREADY=`mysql $OPTS -e "select * from users where userLogin='$user'"`
  if [ "$ALREADY" = "" ]
  then
    for cluster in $CLUSTERS
    do
      echo "Adding user $user to cluster $cluster."
      mysql $OPTS -e "insert into users (userGridName,userClusterName,userLogin) values ('$user','$cluster','$user');"
    done
  fi
done
