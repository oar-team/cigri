<?php
include("../dbfunctions.inc");
require_once("../jpgraph-1.12.2/src/jpgraph.php");
require_once("../jpgraph-1.12.2/src/jpgraph_pie.php");
require_once("../jpgraph-1.12.2/src/jpgraph_pie3d.php");

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

$graph = new PieGraph(650,450,"grid".$timerepartition,720);

$query = <<<EOF
SELECT
	jobClusterName, SUM(UNIX_TIMESTAMP(jobTStop) - UNIX_TIMESTAMP(jobTStart))
FROM
	jobs
WHERE
	jobState='TERMINATED'
	AND jobTStart > '$date'
GROUP BY
	jobClusterName
EOF;

list($res,$nb) = sqlquery($query,$link);
$data = array();
$legend = array();

for ($i = 0; $i < $nb; $i++) {
	$data[$i] = $res[$i][1];
	// if time > 1h, display only hours	
	$time = intval($res[$i][1]/3600);
	if ($time == 0) {
		$time = $res[$i][1]."s";
	}
	else {
		$time = $time."h";
	}
	$legend[$i] = $res[$i][0]." (".$time.")";
}

if ($nb != 0) {

	$graph->title->Set("Time Repartition");
	$graph->title->SetFont(FF_FONT1,FS_BOLD);

	$p1 = new PiePlot3D($data);
	$p1->SetSize(0.4);
	$p1->SetCenter(0.35,0.65);
	$p1->SetTheme("sand");
	$p1->SetLegends($legend);

	$graph->Add($p1);
	$graph->Stroke();
}
else {
	$graph->title->Set("no event recorded on clusters");
	$graph->Stroke();
}

mysql_close($link);
?>

