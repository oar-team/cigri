let cmp critere x y = Pervasives.compare (critere x) (critere y)			   
let get_option = function
    Some x -> x
  | None -> failwith "get_option"		
      
type mjob_t = {
  mjobId : int;
  mjobUser : string;
  mjobTsub : int*int*int*int*int*int; (* Beuh c'que c'est sale *)
  (* mjobTotalJobs : int; *)
  mjobLeftJobs : int;
  mjobClusters : string list;
}


type cluster_t = {
  clusterName : string;
  clusterNodes : int;
}

type assign_t = {
  assignId : int;
  assignCluster : string;
  assignNb : int;
}


let schedule mjobs clusters = 
  let repart mjobs buffer cluster = 
    let possibleJobs = 
      List.sort (cmp (fun mj -> mj.mjobLeftJobs)) 
	(List.filter (fun mjob -> List.mem cluster.clusterName mjob.mjobClusters) mjobs) in 
    let rec aux n l buf = function 
	[] -> buf
      | mj::mjs -> 
      	if n = 0 then buf 
	else let nb = Pervasives.min mj.mjobLeftJobs (n / l) in 
	  aux (n - nb) (l - 1) 
	    ({assignId = mj.mjobId; assignCluster = cluster.clusterName; assignNb = nb}::buf) mjs in 
      aux cluster.clusterNodes (List.length possibleJobs) buffer possibleJobs in 
    
    List.fold_left (repart mjobs) [] clusters

let execQuery dbd q = 
  let res = Mysql.exec dbd q in 
    match Mysql.errmsg dbd with 
	None -> res
      | Some s -> (Printf.printf "[SCHEDULER][SQLERROR] : %s\n" s; failwith "execQuery")
	  
let getInfoMjobs dbd = 
  let resMJobs = execQuery dbd "SELECT multipleJobsRemainedMJobsId, multipleJobsRemainedNumber 
                                        FROM multipleJobsRemained" in 
  let getOneInfo a = 
    let id = Mysql.int2ml (get_option a.(0)) in
    let res1 = execQuery dbd 
		 (Printf.sprintf "SELECT MJobsUser, MJobsTSub FROM multipleJobs WHERE MJobsId = %d" id) in
    let res2 = execQuery dbd 
		 (Printf.sprintf "SELECT propertiesClusterName FROM properties 
                                        WHERE propertiesMJobsId = %d AND propertiesActivated = \'ON\'" id) in
    let array1 = get_option (Mysql.fetch res1) in
      { mjobId = id;
	mjobUser = get_option (array1.(0));
	mjobTsub = Mysql.datetime2ml (get_option (array1.(1)));
	mjobLeftJobs = Mysql.int2ml (get_option a.(1));
	mjobClusters = Mysql.map res2 
			 (fun a -> get_option a.(0)); } in
    
    Mysql.map resMJobs getOneInfo

let getFreeNodes dbd = 
  
  let resFreeNodes = Mysql.exec dbd "SELECT clusterFreeNodesClusterName, clusterFreeNodesNumber 
                                                   FROM clusterFreeNodes" in 
    Mysql.map resFreeNodes 
      (fun a -> { clusterName = get_option a.(0);
		  clusterNodes = Mysql.int2ml (get_option a.(1)) }) 
	 
let makeAssign dbd a = 
  Printf.printf "[SCHEDULER] Assigning %d jobs of mjob %d on %s\n" a.assignNb a.assignId a.assignCluster;
  ignore (execQuery dbd 
	    (Printf.sprintf "INSERT INTO jobsToSubmit (jobsToSubmitMJobsId,
                                               jobsToSubmitClusterName,
                                               jobsToSubmitNumber)
                                VALUES (%d,\"%s\",%d)" a.assignId a.assignCluster a.assignNb))
    
    
    
let _ = 
  print_endline "[SCHEDULER] Begining of scheduler EQUIT";
  let dbd = Mysql.connect { Mysql.dbhost = Some "localhost"; 
			    Mysql.dbname = Some "cigri"; 
			    Mysql.dbport = None;
			    Mysql.dbpwd = Some "cigri"; 
			    Mysql.dbuser = Some "cigri" } in
  let sched = schedule (getInfoMjobs dbd) (getFreeNodes dbd) in 
    List.iter (makeAssign dbd) sched; 
    print_endline "[SCHEDULER] End of scheduler EQUIT";;

