let cmp critere x y = Pervasives.compare (critere x) (critere y)			   
let get_option = function
    Some x -> x
  | None -> failwith "get_option"		
let bicompose f g h x y = f (g x) (h y)
let id = fun x -> x
let agrege f transforme start = List.fold_left (bicompose f id transforme) start      

let concatene transforme = agrege (^) transforme ""

type mjob_t = {
  mjobId : int;
  mjobUser : string;
  mjobTsub : int*int*int*int*int*int; (* Beuh c'que c'est sale *)
  (* mjobTotalJobs : int; *)
  mutable mjobLeftJobs : int;
  mjobClusters : string list;
}


let printMJob m = 
  Printf.printf "MJob %d: %s, reste %d, sur %s\n"
    m.mjobId m.mjobUser m.mjobLeftJobs (concatene id m.mjobClusters)

type cluster_t = {
  clusterName : string;
  clusterNodes : int;
}

let printCluster c = 
  Printf.printf "Cluster %s : %d libres\n" c.clusterName c.clusterNodes

type assign_t = {
  assignId : int;
  assignCluster : string;
  assignNb : int;
}

(* Le scheduler *)

let schedule mjobs clusters = 
  let repart mjobs buffer cluster = 
    let possibleJobs = 
      List.sort (cmp (fun mj -> mj.mjobLeftJobs)) 
	(List.filter (fun mjob -> List.mem cluster.clusterName mjob.mjobClusters) mjobs) in 
    let rec aux n l buf = function 
	[] -> buf
      | mj::mjs -> 
	  let nb = Pervasives.min mj.mjobLeftJobs (n / l) in 
	    if nb = 0 then 
	      aux n (l - 1) buf mjs 
	    else ( mj.mjobLeftJobs <- mj.mjobLeftJobs - nb; 
		   aux (n - nb) (l - 1) 
		     ({assignId = mj.mjobId; assignCluster = cluster.clusterName; assignNb = nb}::buf) mjs) in 
      aux cluster.clusterNodes (List.length possibleJobs) buffer possibleJobs in 
    
    List.fold_left (repart mjobs) [] clusters
      
(* Les fonctions d'accès à la base de données *)

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
  let resFreeNodes = execQuery dbd "SELECT clusterFreeNodesClusterName, clusterFreeNodesNumber 
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
    
(* Le programme principal *)    
    
let main = 
  print_endline "[SCHEDULER] Begining of scheduler EQUIT";
  let istest = ref false in 
    Arg.parse ["-test", Arg.Set istest, "Test Mode : uses another server"]
      ignore "sched_equitCigri [option]";
    let connector = if !istest 
    then { Mysql.dbhost = Some "pawnee"; 
	   Mysql.dbname = Some "cigriSched"; 
	   Mysql.dbport = None;
	   Mysql.dbpwd = Some "cigriSched"; 
	   Mysql.dbuser = Some "cigriSched" }
    else { Mysql.dbhost = Some "localhost"; 
	   Mysql.dbname = Some "cigri"; 
	   Mysql.dbport = None;
	   Mysql.dbpwd = Some "cigri"; 
	   Mysql.dbuser = Some "cigri" } in
    let dbd = Mysql.connect connector in 
    let mjobs = getInfoMjobs dbd and nodes = getFreeNodes dbd in 
      List.iter printMJob mjobs; 
      print_newline(); 
      List.iter printCluster nodes;
    let sched = schedule mjobs nodes in 
      List.iter (makeAssign dbd) sched; 
      print_endline "[SCHEDULER] End of scheduler EQUIT";;

