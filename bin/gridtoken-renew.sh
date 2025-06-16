#!/usr/bin/env bash
set -e
set -o pipefail

source /etc/cigri/api-clients.conf 
API="http://$API_HOST:$API_PORT/$API_BASE"

if [ "$1" = "" ]
then
  echo "Usage: $0 <cluster_id>"
  exit
fi

echo "Getting cluster URI..."
URI=`curl --no-progress-meter "$API/clusters/$1" |jq -r .api_url`
if [ "$URI" == "null" ]
then
  echo "ERROR: Could not get uri of cluster $1!"
  exit 1
fi
echo "Getting current token..."
TOKEN=`curl --no-progress-meter "$API/tokens?cluster_id=$1" |jq -r .items[].cluster_login`
if [ "$TOKEN" == "null" -o "$TOKEN" == "" ]
then
  echo "ERROR: Could not get current token of cluster $1, check 'gridtoken -l'!"
  exit 1
fi
echo "Connecting to cluster to get a new token..."
NEW_TOKEN=`curl --no-progress-meter -H 'Accept: application/json'  -H "Authorization: $TOKEN" $URI/get_new_token |jq -r .OAR_API_TOKEN`
if [ "$NEW_TOKEN" != "null" ]
then
  echo "Setting the new token of cluster $1..."
  `dirname $0`/gridtoken -i $1 -t "$NEW_TOKEN"
else
	echo "ERROR: Could not get a new token (current token expired?)!"
fi
