<?php
include("../dbfunctions.inc");
require_once("../jpgraph/src/jpgraph.php");
require_once("../jpgraph/src/jpgraph_bar.php");
require_once("../jpgraph/src/jpgraph_pie.php");
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
if (!$_GET['timerange']) {
	$ok = false;
} else {
	switch ($_GET['timerange']) {
		case "1 day":
			$timerange = 24*3600;
			$granularity = 3600;
			break;
		case "1 week":
			$timerange = 7*24*3600;
			$granularity = 24*3600;
			break;
		case "2 weeks":
			$timerange = 14*24*3600;
			$granularity = 24*3600;
			break;
		case "1 month":
			$timerange = 30*24*3600;
			$granularity = 24*3600;
			break;
		case "1 year":
			$timerange = 365*24*3600;
			$granularity = 30*24*3600;
			break;
		default:
			// Set to month
			$timerange = 30*24*3600;
			$granularity = 24*3600;
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
}
if ($ok) {
	$starttime = mktime(0,0,0,$bmonth,$bday,$byear);
	$stoptime = $starttime + $timerange;
	$eyear = date("Y",$stoptime);
	$emonth = date("m",$stoptime);
	$eday = date("d",$stoptime);

	// Check graph
	$cachefile = sprintf("power%04d%02d%02d%d",$byear,$bmonth,$bday,$timerange);
	$graph = new Graph(650,650,$cachefile,720);

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
	$tickslabels = array();
	$time = $starttime;
	for ($i = 0;$i < $nbtimesteps;$i++) {
		if ($granularity <= 3600) {
			$newtick = date("H:i:s",$time);
		} else {
			$newtick = date("Y-m-d",$time);
		}
		$tickslabels[] = $newtick;
		$time += $granularity;
	}
	
	$colorarray = array("brown","khaki1","burlywood2","khaki3","bisque1","chocolate3","darkcyan","darkgreen","gold2","lightsalmon","chartreuse4","steelblue2");

	if ($nb != 0) {
		$graph->SetScale("textlin");
	
		$graph->title->Set("Computing Power");
		$graph->title->SetFont(FF_FONT1,FS_BOLD);
		$graph->xaxis->title->Set("Time");
		$graph->xaxis->SetLabelAngle(90);
		$graph->xaxis->SetTickLabels($tickslabels);
		
		$graph->yaxis->title->Set("Power");
		$graph->xaxis->title->SetFont(FF_FONT1,FS_BOLD);
		$graph->yaxis->title->SetFont(FF_FONT1,FS_BOLD);
		$graph->SetShadow();
		$graph->img->SetMargin(70,100,30+11*(1+count($data)),100);
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
		$graph->SetScale("textlin",0,1);
		$temparr = array(0);
		$barplot = new BarPlot($temparr);
		$graph->Add($barplot);
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
