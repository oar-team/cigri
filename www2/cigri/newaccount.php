<?php
if ($_SESSION['adminauth'] == true) {
	$link = dbconnect();
	$message = '';
	if (isset($_GET['login']) && isset($_GET['pass1']) && isset($_GET['pass2'])) {
		if ($_GET['pass1'] == $_GET['pass2']) {
			if (strlen($_GET['login']) < 2 || strlen($_GET['login']) > 15 || strlen($_GET['pass1']) > 15) {
				$message = "<p>Login must be &gt; 3 characters and &lt; 15 characters</p><p>Password must be &lt; 15 characters</p>";
			}
			else {
				// Check if users already exists
				$login = addslashes($_GET['login']);
				$pass = addslashes(crypt($_GET['pass1'],17));
				$query = <<<EOF
SELECT
	*
FROM
	webusers
WHERE
	login = '$login'
EOF;
				
				list($res,$nb) = sqlquery($query,$link);
				if ($nb > 0) {
					$message = "<p>User ".$_GET['login']." already exists</p>";
				}
				else {
					// Record new login/pass
					$query = <<<EOF
INSERT INTO
	webusers
VALUES
	('$login','$pass')
EOF;

					mysql_query($query,$link);
					if (mysql_affected_rows($link) == 1) {
						$message = "<p>User ".$_GET['login']." created</p>";
					} else {
						$message = "<p>Database error: user not created</p>";
					}
				}
			}
		}
		else {
			$message = "<p>Passwords don't match</p>";
		}
	}
	$smarty->assign('MESSAGE',$message);
	$smarty->assign('contenttemplate',"cigri/newaccount.tpl");
	mysql_close($link);
}
else {
	$smarty->assign('contenttemplate',"error.tpl");
}
		       
?>
