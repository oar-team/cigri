<?php
if ($_SESSION['auth']) {
	$smarty->assign('contenttemplate',"account/stats/stats.tpl");
}
?>
