<?php
include("../dbfunctions.inc");
require_once("../jpgraph-1.12.2/src/jpgraph.php");
require_once("../jpgraph-1.12.2/src/jpgraph_bar.php");
define('NB_BARS',20);

$link = dbconnect();
$time = time();

$timerepartition = $_GET['timerepartition'];
if ($timerepartition == "day") {
	// 1 day = 86400 seconds
	$sec = $time - 86400;
}
else if ($timerepartition == "month") {
	// 1 month = 31 days = 2678400 seconds
	$sec = $time - 2678400;
}
else if ($timerepartition == "year") {
	// 1 year = 365 days = 31 622 400 seconds
	$sec = $time - 31622400 ;
}
else if ($timerepartition == "week") {
	// 1 week = 604 800 seconds
	$sec = $time - 604800;
}
else {
	// default is week timerepartition
	$timerepartition = "week";
	$sec = $time - 604800;
}

// convert unix timestamp to SQL timestamp
$date = date("Y-m-d H:m:s",$sec);

$graph = new Graph(650,650,"jobs".$timerepartition,720);

$query = <<<EOF
SELECT
	MAX(UNIX_TIMESTAMP(jobTStop) - UNIX_TIMESTAMP(jobTStart))
FROM
	jobs
WHERE
	jobState='TERMINATED'
	AND jobTStart > '$date'
EOF;

	list($res,$nb) = sqlquery($query,$link);
	$maxduration = $res[0][0];
	$divby = ($maxduration+1) / NB_BARS;
	
	$query = <<<EOF
SELECT
	COUNT(jobId), FLOOR((UNIX_TIMESTAMP(jobTStop) - UNIX_TIMESTAMP(jobTStart)) / {$divby}) as timeslot
FROM
	jobs
WHERE
	jobState='TERMINATED'
	AND jobTStart > '$date'
GROUP BY
	timeslot
HAVING
	timeslot >= 0
EOF;

list($res,$nb) = sqlquery($query,$link);
$total = 0;
for ($i = 0;$i < $nb;$i++) {
	$total += $res[$i][0];
}
$j = 0;
for ($i = 0;$i < NB_BARS;$i++) {	
	if ($res[$j][1] == $i) {
		$data[$i] = $res[$j][0] / $total * 100;
		$j++;
	} else {
		$data[$i] = 0;
	}
	$ticks[$i] = sprintf("%dm%02ds",$i*$divby/60,($i*$divby)%60);
}

if ($nb != 0) {
	$graph->SetScale("textlin");
	$graph->title->Set("Jobs time repartition");
	$graph->title->SetFont(FF_FONT1,FS_BOLD);
	$graph->xaxis->title->Set("Duration");
	$graph->xaxis->SetLabelAngle(90);
	$graph->xaxis->SetTickLabels($ticks);
	$graph->yaxis->title->Set("%");
        $graph->xaxis->title->SetFont(FF_FONT1,FS_BOLD);
        $graph->yaxis->title->SetFont(FF_FONT1,FS_BOLD);
	$graph->SetShadow();
	$graph->img->SetMargin(70,100,30,100);
	$barplot = new BarPlot($data);
	$graph->Add($barplot);
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
?>

