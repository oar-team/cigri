<?php
include("../../dbfunctions.inc");
require_once("../../jpgraph-1.12.2/src/jpgraph.php");
require_once("../../jpgraph-1.12.2/src/jpgraph_bar.php");
define('NB_BARS',20);

$link = dbconnect();

if (isset($_GET['id'])) {
	if (is_numeric($_GET['id'])) {
		$jobid = $_GET['id'];
	}
}

if (!isset($jobid)) { exit(1);}

$graph = new Graph(650,650,"mjob".$jobid,720);

$query = <<<EOF
SELECT
	UNIX_TIMESTAMP(jobTStop) - UNIX_TIMESTAMP(jobTStart)
FROM
	jobs
WHERE
	jobState='TERMINATED'
	AND jobMJobsId = '$jobid'
EOF;

$nb=0;
$result = mysql_query($query,$link);
$times = array();
while ($row = mysql_fetch_array($result)) {
	$times[] = $row[0];
	$nb++;
}
mysql_free_result($result);

$total = 0;
for ($i = 0;$i < $nb;$i++) {
	$total += $times[$i];
}

if ($nb != 0) {
	sort($times);
	$min = $times[0];
	$max = $times[$nb-1];
	$moy = $total / $nb;
	if ($nb % 2 == 0) {
		$median = ($times[$nb/2-1] + $times[$nb/2]) / 2;
	} else {
		$median = $times[floor($nb/2)];
	}

	$ticks = array();
	$granularity = ($max+1)/NB_BARS;
	$temp = 0;
	for ($i = 0;$i < NB_BARS;$i++) {	
		$ticks[$i] = sprintf("%dm%02ds",$temp/60,$temp%60);
		$temp += $granularity;
	}
	// Enter data
	$data = array();
	for ($i = 0;$i < NB_BARS;$i++) {
		$data[] = 0;
	}
	$temp = $granularity;
	$i = 0;
	$j = 0;
	$variance = 0;
	while ($i < $nb) {
		while ($times[$i] >= $temp) {
		       $j++;
		       $temp += $granularity;
		}
		$tempv = $times[$i] - $moy;
		$tempv *= $tempv;
		$variance += $tempv;
		$data[$j]++;
		$i++;
	}
	$stddev = sqrt($variance/$nb);

	for ($i = 0;$i < NB_BARS;$i++) {
		$data[$i] = $data[$i]/$nb*100;
	}

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
	$graph->img->SetMargin(70,100,30,170);
	$gtext = new Text("Number of jobs: ".$nb);
	$gtext->Pos(0.2,0.82);
	$graph->Add($gtext);
	$moyline = new PlotLine(VERTICAL,$moy/$max*NB_BARS,"red",2);
	$graph->Add($moyline);
	$medianline = new PlotLine(VERTICAL,$median/$max*NB_BARS,"blue",2);
	$graph->Add($medianline);	
	$stddev1 = new PlotLine(VERTICAL,($moy+$stddev)/$max*NB_BARS,"darkgreen",1);
	$graph->Add($stddev1);	
	$stddev2 = new PlotLine(VERTICAL,($moy-$stddev)/$max*NB_BARS,"darkgreen",1);
	$graph->Add($stddev2);	
	$g2text = new Text("Minimal execution time: ".$min." s");
	$g2text->Pos(0.2,0.84);
	$graph->Add($g2text);
	$g3text = new Text("Maximal execution time: ".$max." s");
	$g3text->Pos(0.2,0.86);
	$graph->Add($g3text);
	$temptext = sprintf("Mean time: %.2f s",$moy);
	$g4text = new Text($temptext);
	$g4text->Pos(0.2,0.88);
	$g4text->SetColor("red");
	$graph->Add($g4text);
	$temptext = sprintf("Median time: %.2f s",$median);
	$g5text = new Text($temptext);
	$g5text->Pos(0.2,0.90);
	$g5text->SetColor("blue");
	$graph->Add($g5text);
	$temptext = sprintf("Standard deviation: %.2f s",$stddev);
	$g6text = new Text($temptext);
	$g6text->Pos(0.2,0.92);
	$g6text->SetColor("darkgreen");
	$graph->Add($g6text);
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

