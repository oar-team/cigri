<?php
# Configuration variables for CIGRI www interface
# !!! KEEP PROTECTED:     !!!
# !!! chown root:www-data !!!
# !!! chmod 640           !!!

$DB_HOST="localhost";
$DB_DATABASE="cigri";
$DB_USER="cigri";
$DB_PASSWORD="cigri";

$LDAP=0;
$LDAP_HOST="localhost";
$LDAP_USERS="ou=People,ou=platforms,o=ciment,dc=ujf-grenoble,dc=fr";

$SMARTY_DIR="/usr/share/php/smarty/libs/";
$JPGRAPH_DIR="/usr/share/jpgraph/";

?>
