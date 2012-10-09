#!/bin/bash
cigridir=`dirname "$0"`/..
database_dir=$cigridir/database

$database_dir/init_db.rb -d cigri3 -u cigri3 -p cigri3 -t psql -s $database_dir/psql_structure.sql
#sudo $cigridir/sbin/new_cluster.rb tchernobyl http://tchernobyl/oarapi-priv/ kameleon kameleon '' tchernobyl oar2_5 core 100 "cluster='tchernobyl'"
#sudo $cigridir/sbin/new_cluster.rb threemile http://threemile/oarapi-priv/ kameleon kameleon '' threemile oar2_5 core 10 "cluster='threemile'"
#sudo $cigridir/sbin/new_cluster.rb fukushima http://fukushima/oarapi-priv/ kameleon kameleon '' fukushima oar2_5 core 50 "cluster='fukushima'"
