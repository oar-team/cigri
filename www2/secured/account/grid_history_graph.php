<?php
include("../../dbfunctions.inc");
require_once("$JPGRAPH_DIR/jpgraph.php");
require_once("$JPGRAPH_DIR/jpgraph_bar.php");
require_once("$JPGRAPH_DIR/jpgraph_line.php");

# Get the begin and end timestamps
if (isset($_GET['begin'])) $begin = $_GET['begin'];
else {
  $begin=time()-86400;
}
if (isset($_GET['end'])) $end = $_GET['end'];
else {
  $end=time();
}
if (isset($_GET['cluster'])) {
  $cluster_query="and clusterName='".$_GET['cluster']."' ";
  $title="Grid status history: ".$_GET['cluster']." details";;
}
else {
  $cluster_query="";
  $title="Grid status history";
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
#$graph->xaxis->HideTicks(true,false); 
$graph->legend->Pos(0.1,0.01);
$graph->SetMargin(45,45,75,55);
$graph->yaxis->scale->SetAutoMin(0);
$graph->yaxis->SetTitle("Resources");
$graph->xaxis->SetTitle("Time");
#$graph->xaxis->HideLastTickLabel();


# Get the data to plot
$query = "select timestamp,sum(maxResources),sum(maxResources -freeResources),sum(maxResources - freeResources - usedResources),sum(blacklisted*maxResources) from gridstatus where timestamp < $end and timestamp > $begin $cluster_query group by timestamp order by timestamp";
$result = mysql_query($query,$link);
$i=0; $j=0;
$step=(mysql_result($result,mysql_num_rows($result)-1,0)-mysql_result($result,0,0))/600;

while ($row = mysql_fetch_row($result)) {
    if ($j>=$step) {
      $x[$i]=$row[0];
      $max[$i]=$row[1];
      $cigriused[$i]=$row[2];
      $localyused[$i]=$row[3];
      $blacklisted[$i]=$row[4];
      $i++;
      $j=0;
    }
    if ($prev_timestamp) $j=$j+$row[0]-$prev_timestamp;
    $prev_timestamp=$row[0];
}

# Set the title (containing timestamps)
$title .= "\nfrom ".date("Y/m/d H:i",mysql_result($result,0,0)). " to ".date("Y/m/d H:i",mysql_result($result,mysql_num_rows($result)-1,0));
#$graph->tabtitle->Set($title);

# Bargraph of total resources
mysql_free_result($result);
$barplot = new BarPlot($max,$x);
$barplot->SetFillColor('khaki1');
$barplot->SetColor('khaki1');
$barplot->SetLegend('Total resources');
#$barplot->SetWidth(2);
$graph->Add($barplot);

# Bargraph of resources used by cigri
$barplot = new BarPlot($cigriused,$x);
$barplot->SetFillColor('brown');
$barplot->SetColor('brown');
$barplot->SetLegend('Used by CiGri (cumul)');
#$barplot->SetWidth(2);
$graph->Add($barplot);

# Bargraph of resources localy used
$barplot = new BarPlot($localyused,$x);
$barplot->SetFillColor('chocolate3');
$barplot->SetColor('chocolate3');
$barplot->SetLegend('Localy used or unavailable');
#$barplot->SetWidth(2);
$graph->Add($barplot);

# Bargraph of blacklisted resources
$barplot = new BarPlot($blacklisted,$x);
$barplot->SetFillColor('darkgray');
$barplot->SetColor('darkgray');
$barplot->SetLegend('Blacklisted (cluster unavailable)');
#$barplot->SetWidth(2);
$graph->Add($barplot);

# null bargraph for the white legend
$null[0]=0;
$barplot = new BarPlot($null);
$barplot->SetFillColor('white');
$barplot->SetColor('white');
$barplot->SetLegend('No status data');
#$graph->Add($barplot);

# Graph creation
#$graph->SetImgFormat('jpeg',90);
$graph->Stroke();

# Close mysql connection
mysql_close($link);
?>
