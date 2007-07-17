<?php
include("../../dbfunctions.inc");
require_once("../../jpgraph/src/jpgraph.php");
require_once("../../jpgraph/src/jpgraph_bar.php");
require_once("../../jpgraph/src/jpgraph_line.php");

# Get the begin and end timestamps
if (isset($_GET['begin'])) $begin = $_GET['begin'];
else {
  $begin=time()-86400;
}
if (isset($_GET['end'])) $end = $_GET['end'];
else {
  $end=time();
}
  
# Connection
$link = dbconnect();
if (!isset($_GET['login'])) exit(1);
$login = $_GET['login'];

# Function to format the date labels
function xLabelFormat ($label) {
  return date("Y/m/d\n  H:i",$label);
}

# Graph definition
$graph = new Graph(750,400,"Grid status history",720);
$colorarray = array("brown","khaki1","burlywood2","khaki3","bisque1","chocolate3","darkcyan","darkgreen","gold2","lightsalmon","chartreuse4","steelblue2");
$graph->SetScale("lin");
$graph->SetShadow();
#$graph->xaxis->HideLabels();
$graph->xaxis->SetLabelFormatCallback('xLabelFormat');
$graph->SetTickDensity(TICKD_DENSE,TICKD_VERYSPARSE);
$graph->xaxis->HideTicks(true,false); 
$graph->legend->Pos(0.1,0.01);
$graph->SetMargin(45,45,55,55);
$graph->yaxis->scale->SetAutoMin(0);
$graph->yaxis->SetTitle("Resources");
$graph->xaxis->SetTitle("Time");
$graph->xaxis->HideLastTickLabel();
$graph->tabtitle->Set('Grid status history');


# Get the data to plot
$query = "select timestamp,sum(maxResources),sum(maxResources -freeResources),sum(maxResources - freeResources - usedResources) from gridstatus where timestamp < $end and timestamp > $begin group by timestamp";
$result = mysql_query($query,$link);
$i=0; $j=0;
$step=(mysql_result($result,mysql_num_rows($result)-1,0)-mysql_result($result,0,0))/600;

while ($row = mysql_fetch_row($result)) {
    if ($j>=$step) {
      $x[$i]=$row[0];
      $max[$i]=$row[1];
      $cigriused[$i]=$row[2];
      $localyused[$i]=$row[3];
      $i++;
      $j=0;
    }
    if ($prev_timestamp) $j=$j+$row[0]-$prev_timestamp;
    $prev_timestamp=$row[0];
}

# Bargraph of total resources
mysql_free_result($result);
$barplot = new LinePlot($max,$x);
$barplot->SetFillColor('khaki1');
$barplot->SetColor('khaki1');
$barplot->SetLegend('Total resources');
$graph->Add($barplot);

# Bargraph of resources used by cigri
$barplot = new LinePlot($cigriused,$x);
$barplot->SetFillColor('brown');
$barplot->SetColor('brown');
$barplot->SetLegend('Used by CiGri (cumul)');
$graph->Add($barplot);

# Bargraph of resources localy used
$barplot = new LinePlot($localyused,$x);
$barplot->SetFillColor('chocolate3');
$barplot->SetColor('chocolate3');
$barplot->SetLegend('Localy used or unavailable');
$graph->Add($barplot);

# Graph creation
$graph->SetImgFormat('jpeg',90);
$graph->Stroke();

# Close mysql connection
mysql_close($link);
?>
