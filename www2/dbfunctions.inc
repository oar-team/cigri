<?php

$LDAP=0;
$LDAP_HOST=localhost;
$LDAP_USERS="ou=People,ou=platforms,o=ciment,dc=ujf-grenoble,dc=fr";


function dbconnect() {
    $link = mysql_connect("localhost", "cigri", "cigri")
        or die("Connection failed : " . mysql_error());
    mysql_select_db("cigri",$link) or die( "Connection failed : " . mysql_error());
    return $link;
}

function sqlquery($query,$link) {
        $nb=0;
        $result = mysql_query($query,$link);
        $return_array = array();
        if ($result) {
          while ($row = mysql_fetch_array($result)) {
                $nb= array_push($return_array, $row);
          }
          mysql_free_result($result);
          return array ($return_array, $nb);
        }
        else return array ($return_array, 0);
}

?>
