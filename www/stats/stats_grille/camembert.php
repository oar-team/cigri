<?php
include "../../functions.inc";
include ("../../jpgraph-1.12.2/src/jpgraph.php");
include ("../../jpgraph-1.12.2/src/jpgraph_pie.php");
include ("../../jpgraph-1.12.2/src/jpgraph_pie3d.php");

$link = dbconnect();
$time=time();

if ($bouton == "day"){
// un jour =86400 secondes
    $sec=$time- 86400;
}else if($bouton == "month"){
// un mois = 2678400 secondes si on compte 31 jours
    $sec=$time- 2678400;
}else if($bouton == "year"){
// une année =  secondes 365 jours
    $sec=$time- 31622400 ;
}else if($bouton == "week"){
// une semaine =604800 secondes
    $sec=$time- 604800;
}

// retraduire la date de seconde en jour mois heure
$date= date("Y-m-d H:m:s",$sec);

$query="select jobClusterName , sum(UNIX_TIMESTAMP(jobTStop) - UNIX_TIMESTAMP(jobTStart)) as nombre
        from jobs
        where jobState='TERMINATED'
        and jobTStart >'$date'
        group by jobClusterName
        ";

list($reponse,$nb) = sql_query($query);
mysql_close($link);

$data = array();
$legend = array();
for($i=0; $i<$nb; $i++){
    $data[$i] = $reponse[$i][nombre];
    $temps =intval($reponse[$i][nombre]/3600);

    if ($temps==0){
        $temps=$reponse[$i][nombre]."s";
    }else{
        $temps = $temps."h";
    }
    $legend[$i] = $reponse[$i][jobClusterName]."(".$temps.")";
}

if ( $nb != 0){
    //$data = array(40,60,21,33);
    //$legend=array("bla","ble","bli","kli");

    $graph = new PieGraph(620,450,"auto");
    //$graph->SetShadow();

    $graph->title->Set("Time Repartition");
    $graph->title->SetFont(FF_FONT1,FS_BOLD);

    $p1 = new PiePlot3D($data);
    $p1->SetSize(0.5);
    $p1->SetCenter(0.45);
    $p1->SetTheme("sand");
    $p1->SetLegends($legend);

    $graph->Add($p1);
    $graph->Stroke();
}else{
    $graph = new PieGraph(500,50,"auto");
    $graph->title->Set("no event on clusters");
    $graph->Stroke();
}

?>

