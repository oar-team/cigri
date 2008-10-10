<?php
$step=$_GET['step'];
$page=$_GET['page'];
if ($_SESSION['adminauth'] == true) {
	$link = dbconnect();
	$message = '';
	if (isset($_GET['eventid'])) {
		// Fix this event
		$eventid = $_GET['eventid'];
		$query = <<<EOF
UPDATE
	events
SET
	eventState = 'FIXED'
WHERE
	eventId = $eventid
EOF;
		mysql_query($query,$link);
		if (mysql_affected_rows($link) == 1) {
			$message = 'Event #'.$eventid.' fixed.';
		} else {
			$message = 'Error: event #'.$eventid.' could not be fixed.';
		}
	}

	// {{{ Events query

	// if no order is specified, set to default
	if (!isset($_GET['orderby'])) {
        	$_GET['orderby'] = "e.eventState";
	        $_GET['sort'] = "ASC";
	}

	$selectnames[] = "e.eventId";
	$selectnames[] = "e.eventType";
	$selectnames[] = "e.eventState";
	$selectnames[] = "e.eventClusterName";
	$selectnames[] = "e.eventDate";
	cigri_order_by($_GET,$selectnames,'index.php',$orderby,$orderarray,$orderimgs,$smarty,"../");
	$query = <<<EOF
SELECT
        COUNT(e.eventId)
FROM
        events e
EOF;
	list($res,$nb) = sqlquery($query,$link);
	$nbitems = $res[0][0];
	// Do all the stuff to set page parameters before display
	cigri_set_page_params($page,$step,$nbitems,$maxpages,$minindex,$maxindex,$smarty,$_GET,"index.php");

	// New query with page limits
	$query = <<<EOF
SELECT
        e.eventId, e.eventType, e.eventState, e.eventClusterName, e.eventDate
FROM
        events e

EOF;
	$query .= $orderby;
	$query .= <<<EOF
 LIMIT
        $minindex,$step
EOF;


	unset($res);
	list($res,$nb) = sqlquery($query,$link);
	// display parameters
	for($i = 0; $i < $nb;$i++) {
	        $res[$i][1] = htmlentities($res[$i][1]);
        	$res[$i][2] = htmlentities($res[$i][2]);
	        $res[$i][3] = htmlentities($res[$i][3]);
        	$res[$i][4] = htmlentities($res[$i][4]);
		if ($res[$i][2] == 'ToFIX') {
			$getstring = '';
			foreach ($_GET as $key => $value) {
				$getstring .= rawurlencode($key)."=".rawurlencode($value)."&";
			}
								
			$res[$i][5] = '<a href="index.php?'.$getstring.'eventid='.$res[$i][0].'">Fix&nbsp;event</a>';
		} else {
			$res[$i][5] = '';
		}
	}
	$smarty->assign('eventarray',$res);
	// }}}

	$smarty->assign('MESSAGE',$message);
	$smarty->assign('contenttemplate',"cigri/events.tpl");
	mysql_close($link);
}
else {
	$smarty->assign('contenttemplate',"error.tpl");
}
		       
?>
