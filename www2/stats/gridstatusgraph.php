<?php
include("../dbfunctions.inc");
require_once("../jpgraph/src/jpgraph.php");
require_once("../jpgraph/src/jpgraph_pie.php");
require_once("../jpgraph/src/jpgraph_pie3d.php");

function is_blacklisted($cluster,$link) {
  $query = "SELECT eventType FROM events WHERE eventState='ToFIX'
                                                AND eventClusterName='$cluster'
                                                AND eventMJobsId is null";
  list($res,$nb) = sqlquery($query,$link);
  return $nb;
}
  

$link = dbconnect();

$graph = new PieGraph(650,350,"grid".$timerepartition,720);

$query = "SELECT timestamp FROM gridstatus ORDER BY timestamp desc LIMIT 1";
list($res,$nb) = sqlquery($query,$link);
if ($res[0][0]) {
    $date=date("Y-m-d H:i:s",$res[0][0]);
    $data = array();
    $legend = array();
    $query = "SELECT * from gridstatus where timestamp=";
    $query .= $res[0][0];
    $query .=" order by maxResources desc";
    list($res,$nb) = sqlquery($query,$link);
    $legend[0]="Used by CIGRI";
    $legend[1]="Localy used or localy unavailable";
    $legend[2]="Blacklisted";
    $legend[3]="Free";
    $TotalMax=0;
    
    for($i = 0; $i < $nb;$i++) {
        $cluster=$res[$i][1];
        $maxResources=$res[$i][2];
	$totalMax+=$res[$i][2];
	$freeResources=$res[$i][3];
	$usedResources=$res[$i][4];
	if (is_blacklisted("$cluster",$link) != 0) {
          $data[0]+=0;
	  $data[1]+=0;
	  $data[2]+=$maxResources;
	  $data[3]+=0;
	}
	else {
          $data[0]+=$usedResources;
          $data[1]+=($maxResources - $usedResources - $freeResources);
	  $data[2]+=0;
          $data[3]+=$freeResources;
	}
    }

    $graph->title->Set("Grid resources status snapshot at $date\n$totalMax CPUs in the grid");
	$graph->title->SetFont(FF_FONT1,FS_BOLD);

	$p1 = new PiePlot3D($data);
	$p1->SetSize(0.4);
	$p1->SetCenter(0.35,0.65);
	$p1->SetTheme("sand");
	$p1->SetLegends($legend);
	$p1->SetSliceColors(array('brown','lightred','gray','gray9@0.5'));

	$graph->Add($p1);
	$graph->Stroke();
}
else {
	$graph->title->Set("no gridstatus data");
	$graph->Stroke();
}

mysql_close($link);
?>

