<?php
if ($_SESSION['adminauth'] == true) {
	$link = dbconnect();
	if (isset($_GET['option']) && $_GET['option'] == 'chpass') {
		$message = '';
		if (isset($_GET['pass1']) && isset($_GET['pass2'])) {
			if ($_GET['pass1'] == $_GET['pass2']) {
				if (strlen($_GET['pass1']) > 15) {
					$message = "<p>Password must be &lt; 15 characters</p>";
				}
				else {
					// Record new pass
					$login = addslashes($_GET['login']);
					$pass = addslashes(crypt($_GET['pass1'],17));
					$query = <<<EOF
UPDATE
	webusers
SET
	pass = '$pass'
WHERE
	login = '$login'
EOF;
					mysql_query($query,$link);
					if (mysql_affected_rows($link) == 1) {
						$message = "<p>Password changed</p>";
					} else {
						$message = "<p>Database error: Password not changed</p>";
					}
				}
			}
			else {
				$message = "<p>Passwords don't match</p>";
			}
		}
		cigri_register_menu_item($menu,$currentarray,"auschpass","Change password","index.php?submenu=users&option=chpass&login=".$login,3,true);
		$smarty->assign('login',$_GET['login']);
		$smarty->assign('MESSAGE',$message);
		$smarty->assign('contenttemplate',"cigri/chpass.tpl");
	}
	else {
		$selectnames[] = "login";
		$query = <<<EOF
SELECT
	COUNT(login)
FROM
	webusers
EOF;

		list($res,$nb) = sqlquery($query,$link);
		$nbitems = $res[0][0];
		// Do all the stuff to set page parameters before display
		cigri_set_page_params($page,$step,$nbitems,$maxpages,$minindex,$maxindex,$smarty,$_GET,"index.php");

		// New query with page limits
        	$query = <<<EOF
SELECT
	login
FROM
	webusers
	
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
			$res[$i][0] = htmlentities($res[$i][0]) ;
		}
		$smarty->assign('eventarray',$res);
		$smarty->assign('contenttemplate',"cigri/users.tpl");
	}
	mysql_close($link);
}
else {
	$smarty->assign('contenttemplate',"error.tpl");
}
		       
?>
