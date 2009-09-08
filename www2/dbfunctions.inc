<?php

require "config.inc";
require($SMARTY_DIR.'Smarty.class.php');

function dbconnect() {
    global $DB_HOST,$DB_USER,$DB_PASSWORD,$DB_DATABASE;
    $link = mysql_connect($DB_HOST, $DB_USER, $DB_PASSWORD)
        or die("Connection failed ($DB_HOST,$DB_USER) " . mysql_error());
    mysql_select_db("$DB_DATABASE",$link) or die( "Connection failed ($DB_DATABASE) " . mysql_error());
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
