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
OPTS="-h $DATABASE_HOST -u $DATABASE_USER_NAME -p$DATABASE_USER_PASSWORD -D $DATABASE_NAME --skip-column-names" 
echo $OPTS
mysql $OPTS -e "select * from clusters"


# Get the users of the cigri group
USERS=`getent group $CIGRI_GROUP |cut -f 4 -d:|sed "s/,/ /g"`
for user in $USERS
do
  echo $user
done

# To be continued...
