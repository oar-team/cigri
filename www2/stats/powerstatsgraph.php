<?php
include("../dbfunctions.inc");
require_once("../jpgraph-1.12.2/src/jpgraph.php");
require_once("../jpgraph-1.12.2/src/jpgraph_bar.php");
require_once("../jpgraph-1.12.2/src/jpgraph_pie.php");
define('MAX_BARS',40);

function timestep($timestamp) {
	global $granularity;
	global $starttime;
	return floor(($timestamp-$starttime)/$granularity);
}

$ok = true;

if (!$_GET['bday']) {
	$ok = false;
} else {
	if (is_numeric($_GET['bday'])) $bday = $_GET['bday'];
	else $ok = false;
}
if (!$_GET['bmonth']) {
	$ok = false;
} else {
	if (is_numeric($_GET['bmonth'])) $bmonth = $_GET['bmonth'];
	else $ok = false;
}
if (!$_GET['byear']) {
	$ok = false;
} else {
	if (is_numeric($_GET['byear'])) $byear = $_GET['byear'];
	else $ok = false;
}
if (!$_GET['eday']) {
	$ok = false;
} else {
	if (is_numeric($_GET['eday'])) $eday = $_GET['eday'];
	else $ok = false;
}
if (!$_GET['emonth']) {
	$ok = false;
} else {
	if (is_numeric($_GET['emonth'])) $emonth = $_GET['emonth'];
	else $ok = false;
}
if (!$_GET['eyear']) {
	$ok = false;
} else {
	if (is_numeric($_GET['eyear'])) $eyear = $_GET['eyear'];
	else $ok = false;
}
if ($ok) {
	if ($eyear < $byear) {
		$eyear = $byear;
	}
	if ($eyear == $byear) {
		if ($emonth < $bmonth) {
			$emonth = $bmonth;
		}
		if ($emonth == $bmonth) {
			if ($eday < $bday) {
				$eday = $bday+1;
			}
		}
	}
}
if ($ok) {
	if ($bday >= 1 && $bday <= 31 && $bmonth >= 1 && $bmonth <= 12 && $byear >= 1990 && $byear <= 2100) {
		if (!checkdate($bmonth,$bday,$byear)) {
			// This can only be a bad day number
			if (checkdate($bmonth,30,$byear)) {
			       $bday = 30;
			} else {
				if (checkdate($bmonth,29,$byear)) $bday = 29;
				else $bday = 28;
			}
		}
	} else {
		$ok = false;
	}
	if ($eday >= 1 && $eday <= 31 && $emonth >= 1 && $emonth <= 12 && $eyear >= 1990 && $eyear <= 2100) {
		if (!checkdate($emonth,$eday,$eyear)) {
			// This can only be a bad day number
			if (checkdate($emonth,30,$eyear)) {
			       $eday = 30;
			} else {
				if (checkdate($emonth,29,$eyear)) $eday = 29;
				else $eday = 28;
			}
		}
	} else {
		$ok = false;
	}
}
if ($ok) {
	if ($byear == $eyear && $bmonth == $emonth && $bday == $eday) {
		if (checkdate($emonth,$eday+1,$eyear)) $eday++;
		else $bday--;
	}

	// Check graph
	$graph = new Graph(650,450,"power".$byear.$bmonth.$bday.$eyear.$emonth.$eday,720);

	$starttime = mktime(0,0,0,$bmonth,$bday,$byear);
	$stoptime = mktime(0,0,0,$emonth,$eday,$eyear);
	// Compute new granularity
	$duration = $stoptime - $starttime;
	$nbhours = ceil($duration/(3600*MAX_BARS));
	if ($nbhours <= 6) {
		$granularity = $nbhours * 3600;
		$periodsize = $nbhours;
		$periodtype = "hours";
	} else {
		$nbdays = ceil($duration/(3600*24*MAX_BARS));
		if ($nbdays <= 3) {
			$granularity = $nbdays * 3600 * 24;
			$periodsize = $nbdays;
			$periodtype = "days";
		} else {
			$nbweeks = ceil($duration/(3600*24*7*MAX_BARS));
			$granularity = $nbweeks * 3600 * 24 * 7;
			$periodsize = $nbweeks;
			$periodtype = "weeks";
		}
	}
	
	
	$startdate = sprintf('%04d-%02d-%02d 00:00:00',$byear,$bmonth,$bday);
	$stopdate = sprintf('%04d-%02d-%02d 00:00:00',$eyear,$emonth,$eday);
	$startstep = timestep($starttime);
	$stopstep = timestep($stoptime);
	$nbtimesteps = $stopstep - $startstep;
	$link = dbconnect();
	// Select all jobs contained in a single time slot
	$query = <<<EOF
SELECT
	jobClusterName, FLOOR((UNIX_TIMESTAMP(jobTStart)-{$starttime})/{$granularity}) as starttimestep, SUM(UNIX_TIMESTAMP(jobTStop) - UNIX_TIMESTAMP(jobTStart))
FROM
	jobs
WHERE
	jobTStart >= '{$startdate}' and jobTStop < '{$stopdate}' and FLOOR((UNIX_TIMESTAMP(jobTStart)-{$starttime})/{$granularity}) = FLOOR((UNIX_TIMESTAMP(jobTStop)-{$starttime})/{$granularity})
GROUP BY
	jobClusterName,starttimestep
EOF;
	list($res,$nb) = sqlquery($query,$link);
	$data = array();

	$tempname = "";
	for ($i = 0; $i < $nb; $i++) {
		if ($res[$i][0] != $tempname) {
			$j = 0;
			$tempname = $res[$i][0];
			$data[$tempname] = array();
		}
		$data[$tempname][$res[$i][1]] = $res[$i][2];
	}

	// Select jobs overlapping timeslots
	$query = <<<EOF
SELECT
	jobClusterName, UNIX_TIMESTAMP(jobTStart), UNIX_TIMESTAMP(jobTStop)
FROM
	jobs
WHERE
	jobTStop > '{$startdate}' and jobTStart < '{$stopdate}' and FLOOR((UNIX_TIMESTAMP(jobTStart)-{$starttime})/{$granularity}) != FLOOR((UNIX_TIMESTAMP(jobTStop)-{$starttime})/{$granularity})
EOF;
	list($res,$nb) = sqlquery($query,$link);

	for ($i = 0; $i < $nb; $i++) {
		// border effects
		if ($res[$i][1] < $starttime) {
			$res[$i][1] = $starttime;
		}
		if ($res[$i][2] > $stoptime) {
			$res[$i][2] = $stoptime;
		}
		$start = $res[$i][1];
		$stop = $res[$i][2];
		while ($start != $stop) {
			$nexttimestep = (timestep($start)+1) * $granularity + $starttime;
			if ($nexttimestep > $stop) $nexttimestep = $stop;
			$data[$res[$i][0]][timestep($start)] += $nexttimestep - $start;
			$start = $nexttimestep;
		}
	}

	// NULL values to 0
	foreach ($data as $key=>$value) {
		for ($i = 0;$i < $nbtimesteps;$i++) {
			if (!isset($data[$key][$i])) {
				$data[$key][$i] = 0;
			}
		}
	}

	$colorarray = array("bisque4","wheat1","brown","cadetblue1","chartreuse","cornsilk","darkgoldenrod","darkolivegreen4","deeppink","deepskyblue","gainsboro","hotpink","linen","maroon4","purple3","rosybrown3","thistle3","turquoise3");

	if ($nb != 0) {
		$graph->SetScale("textlin");
	
		$graph->title->Set("Computing Power");
		$graph->title->SetFont(FF_FONT1,FS_BOLD);
		$graph->xaxis->title->Set("Time (".$periodsize." ".$periodtype." periods)");
		$graph->yaxis->title->Set("Power");
		$graph->xaxis->title->SetFont(FF_FONT1,FS_BOLD);
		$graph->yaxis->title->SetFont(FF_FONT1,FS_BOLD);
		$graph->SetShadow();
		$graph->img->SetMargin(70,100,100,11*(1+count($data)));
		$graph->legend->Pos(0.05,0.05,"right","top");	
		$barplot = array();
		$i = 0;
		foreach ($data as $key=>$val1) {
			$tempbar = new BarPlot($val1);
			$tempbar->SetLegend($key);
			$i %= count($colorarray);
			$tempbar->SetFillColor($colorarray[$i++]);
			$barplot[] = $tempbar;
		}
		$accbarplot = new AccBarPlot($barplot);
		$graph->Add($accbarplot);
		$graph->Stroke();
	}
	else {
		$graph->title->Set("no job recorded on clusters");
		$graph->Stroke();
	}

	mysql_close($link);
} else {
	$graph = new PieGraph(500,50,"auto");
	$graph->title->Set("Wrong date parameters");
	$graph->Stroke();
}
?>

