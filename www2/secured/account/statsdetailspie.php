<?php
include("../../dbfunctions.inc");
require_once("../../jpgraph/src/jpgraph.php");
require_once("../../jpgraph/src/jpgraph_pie.php");
require_once("../../jpgraph/src/jpgraph_pie3d.php");

$link = dbconnect();

if (isset($_GET['id'])) {
	if (is_numeric($_GET['id'])) {
		$jobid = $_GET['id'];
	}
}

if (!isset($jobid)) { exit(1);}

$graph = new PieGraph(650,450,"mjobpie".$jobid,720);

	$query = <<<EOF
SELECT
	jobClusterName, SUM(UNIX_TIMESTAMP(jobTStop) - UNIX_TIMESTAMP(jobTStart))
FROM
	jobs
WHERE
	jobState='TERMINATED'
	AND jobMJobsId = '$jobid'
GROUP BY
	jobClusterName
ORDER BY
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
        $graph->title->Set("no job recorded on multijob");
	$graph->Stroke();
}

mysql_close($link);
?>

