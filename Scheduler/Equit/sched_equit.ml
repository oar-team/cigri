let cmp critere x y = Pervasives.compare (critere x) (critere y)			   
let get_option = function
    Some x -> x
  | None -> failwith "get_option"		
let bicompose f g h x y = f (g x) (h y)
let id = fun x -> x
let agrege f transforme start = List.fold_left (bicompose f id transforme) start      

let concatene transforme = agrege (^) transforme ""

let debug = ref false

type mjob_t = {
  mjobId : int;
  mjobUser : string;
  mjobTsub : int*int*int*int*int*int; (* Beuh c'que c'est sale *)
  (* mjobTotalJobs : int; *)
  mutable mjobLeftJobs : int;
  mjobClusters : string list;
}


let printMJob m = 
  Printf.printf "MJob %d: %s, reste %d, sur%s\n"
    m.mjobId m.mjobUser m.mjobLeftJobs (concatene ((^) " ") m.mjobClusters)

type cluster_t = {
  clusterName : string;
  clusterNodes : int;
  clusterWaitingJobs : int;
  clusterTotalNodes : int;
}

let printCluster c = 
  Printf.printf "Cluster %s : %d libres sur %d, %d waiting\n" 
    c.clusterName c.clusterNodes c.clusterTotalNodes c.clusterWaitingJobs

type assign_t = {
  assignId : int;
  assignCluster : string;
  mutable assignNb : int;
}

let printAssign a = 
  Printf.printf "[SCHEDULER] Assigning %d jobs of mjob %d on %s\n" a.assignNb a.assignId a.assignCluster
  

let empty_assign = [] 
let add_assign l x = 
  let rec find p = function 
      [] -> raise Not_found
    | y::ys when p y x -> y 
    | y::ys -> find p ys in 

    
    try let a = find (fun e f -> (e.assignId, e.assignCluster) = (f.assignId, f.assignCluster)) l in 
      if (!debug) then 
	Printf.printf "[SCHED-DEBUG] Adding %d to mJob %d on %s (already %d)\n" 
	  x.assignNb x.assignId x.assignCluster a.assignNb;
      a.assignNb <- a.assignNb + x.assignNb; l
    with Not_found -> 
      ( if (!debug) then 
	  Printf.printf "[SCHED-DEBUG] Setting %d to mJob %d on %s\n"
	    x.assignNb x.assignId x.assignCluster;
	x::l )


(* Le scheduler *)

let schedule flood_param mjobs clusters = 
  let repart calc_avail mjobs assigns cluster = 
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
		   let nxt_assign = add_assign buf {assignId = mj.mjobId; 
						    assignCluster = cluster.clusterName; 
						    assignNb = nb} in
		     aux (n - nb) (l - 1) nxt_assign mjs ) in 
      aux (calc_avail cluster) (List.length possibleJobs) assigns possibleJobs in 
    
  let first_pass = List.fold_left (repart (fun c -> c.clusterNodes - c.clusterWaitingJobs) mjobs) 
		     empty_assign clusters in 
(*    first_pass *)
    List.fold_left (repart (fun c -> flood_param * c.clusterTotalNodes / 100) mjobs) first_pass clusters 

    
      
(* Les fonctions d'accès à la base de données *)

let execQuery dbd q = 
  let res = Mysql.exec dbd q in 
    match Mysql.errmsg dbd with 
	None -> res
      | Some s -> (Printf.printf "[SCHEDULER][SQLERROR] : %s\n" s; failwith "execQuery")
	  
let getInfoMjobs dbd = 
  let resMJobs = execQuery dbd "SELECT parametersMJobsId, COUNT(*)
                             FROM parameters,multipleJobs
                             WHERE MJobsId = parametersMJobsId
                             AND MJobsState = \"IN_TREATMENT\"
                             GROUP BY parametersMJobsId
                             ORDER BY parametersMJobsId DESC" in
  let getOneInfo a = 
    let id = Mysql.not_null Mysql.int2ml a.(0) in
    let res_User_TSub = execQuery dbd 
			  (Printf.sprintf "SELECT MJobsUser, MJobsTSub FROM multipleJobs WHERE MJobsId = %d" id) in
    let res_ClName = execQuery dbd 
		       (Printf.sprintf "SELECT propertiesClusterName FROM properties 
                                        WHERE propertiesMJobsId = %d" id) in
    let list_ClName = Mysql.map res_ClName (fun a -> Mysql.not_null Mysql.str2ml a.(0)) in

    let res_BlackList = execQuery dbd 
			  (Printf.sprintf "SELECT clusterBlackListClusterName FROM clusterBlackList, events
                                           WHERE (clusterBlackListMJobsID = %d OR clusterBlackListMJobsID = 0)
                                             AND (clusterBlackListEventId = eventId AND eventState = \'ToFIX\')" id) in 
    let list_BlackList = Mysql.map res_BlackList (fun a -> Mysql.not_null Mysql.str2ml a.(0)) in

    let array_user_tsub = get_option (Mysql.fetch res_User_TSub) in

      { mjobId = id;
	mjobUser = get_option (array_user_tsub.(0));
	mjobTsub = Mysql.not_null Mysql.datetime2ml array_user_tsub.(1);
	mjobLeftJobs = Mysql.not_null Mysql.int2ml a.(1);
	mjobClusters = List.filter (fun c -> not (List.mem c list_BlackList)) list_ClName; } in  
    
    Mysql.map resMJobs getOneInfo

let getClusterInfo dbd = 
  let resFreeNodes = execQuery dbd "SELECT nodeClusterName,count(*)
                                FROM nodes
                                WHERE nodeState = \"FREE\"
                                GROUP BY nodeClusterName" in
  let resTotalNodes =  execQuery dbd "SELECT nodeClusterName,count(*)
                                FROM nodes
                                GROUP BY nodeClusterName" in
  let resWaitingJobs = execQuery dbd "SELECT jobClusterName, count(*)
                                        FROM jobs 
                                        WHERE jobState = \"RemoteWaiting\"
                                        GROUP BY jobClusterName" in 
  let waitingList = 
    Mysql.map resWaitingJobs 
      (fun a -> (Mysql.not_null Mysql.str2ml a.(0), Mysql.not_null Mysql.int2ml a.(1))) in 

  let freeList = 
    Mysql.map resFreeNodes
      (fun a -> (Mysql.not_null Mysql.str2ml a.(0), Mysql.not_null Mysql.int2ml a.(1))) in 

    Mysql.map resTotalNodes
      (fun a -> 
	 let cl_name = Mysql.not_null Mysql.str2ml a.(0) in
	 let nb_waiting = try List.assoc cl_name waitingList with Not_found -> 0 in 
	 let nb_free = try List.assoc cl_name freeList with Not_found -> 0 in 
	   { clusterName = cl_name;
	     clusterTotalNodes = Mysql.not_null Mysql.int2ml a.(1);
	     clusterNodes = nb_free;
	     clusterWaitingJobs = nb_waiting; }) 
      
let makeAssign dbd a = 
  printAssign a;
  ignore (execQuery dbd 
	    (Printf.sprintf "INSERT INTO jobsToSubmit (jobsToSubmitMJobsId,
                                               jobsToSubmitClusterName,
                                               jobsToSubmitNumber)
                                VALUES (%d,\"%s\",%d)" a.assignId a.assignCluster a.assignNb))
    
(* Lecture du fichier de config *)

let conf_file = ref "/etc/cigri.conf"

open Options

(* Version qui aurait pu marcher si Nico ne mettait pas des / de m...
   sans les protéger par des guillemets *)

type options = {
  conn : Mysql.db;
  flood : int;
}
		  
let read_conf file = 
  let opf = create_options_file file in 
  let db_host = define_option opf ["database_host"] "" string_option "localhost"
  and db_name = define_option opf ["database_name"] "" string_option "truc"
  and db_username = define_option opf ["database_username"] "" string_option ""
  and db_userpassword = define_option opf ["database_userpassword"] "" string_option "" 
  and flood_parameter = define_option opf ["flood_parameter"] "" int_option 20 in 
  let convert = function 
      "" -> None
    | s -> Some s in 
    load opf; 
    { conn = { Mysql.dbhost = convert (!! db_host); 
	       Mysql.dbname = convert (!! db_name);
	       Mysql.dbport = None;
	       Mysql.dbpwd = convert (!! db_userpassword);
	       Mysql.dbuser = convert (!! db_username) };
      flood = !! flood_parameter; }



(* La vraie version. Y'a pas intérêt à ce que tu me mettes des mots finissant par un /.
   Sinon je te démonte *)
    
(*

let read_conf file = 
  let rec parse list = parser 
      [< _ = parse_assoc list; _ = parse list ?? "Beuh" >] -> ()
    | [< >] -> () 
  and parse_assoc list = parser 
      [< 'Genlex.Ident name; 
	 'Genlex.Kwd "=" ?? Printf.sprintf "= expected after name %s" name; 
	 value = parse_value ?? Printf.sprintf "value expected after name %s =" name >] 
      -> ( (* Printf.printf "Found %s = %s\n" name value; *)
	   try let f = List.assoc name list in f value
	   with _ -> () ) 
  and parse_value = parser 
      [< 'Genlex.Ident "/"; v = parse_val; s = parse_value_next >] -> "/"^v^s
    | [< v = parse_val; s = parse_value_next >] -> v^s
  and parse_value_next = parser
      [< 'Genlex.Ident "/"; v = parse_val; s = parse_value_next >] -> "/"^v^s
    | [< >] -> "" 
  and parse_val = parser
      [< 'Genlex.Ident v >] -> v
    | [< 'Genlex.Int i >] -> string_of_int i
    | [< 'Genlex.Float f >] -> string_of_float f
    | [< 'Genlex.String v >] -> v
    | [< 'Genlex.Char c >] -> String.make 1 c in

  let db_host = ref "" 
  and db_name = ref "" 
  and db_username = ref "" 
  and db_userpasswd = ref "" in 
  let convert = function 
      "" -> None
    | s -> Some s in 
    
    Printf.printf "Reading configuration file %s\n" file;

    parse ["database_host", (:=) db_host;
	   "database_name", (:=) db_name;
	   "database_username", (:=) db_username;
	   "database_userpassword", (:=) db_userpasswd] 
	(Genlex.make_lexer ["="] (Stream.of_channel (open_in file))); 
    
    { Mysql.dbhost = convert (! db_host); 
      Mysql.dbname = convert (! db_name);
      Mysql.dbport = None;
      Mysql.dbpwd = convert (! db_userpasswd);
      Mysql.dbuser = convert (! db_username) }
  

*)
  
(* Le programme principal *)    

let main = 
  print_endline "[SCHEDULER] Begining of scheduler EQUIT";
  let istest = ref false in 
  let nop = ref false in 
    Arg.parse ["-test", Arg.Set istest, "Test Mode : uses a test database";
	       "-conf_file", Arg.String (fun s -> conf_file := s), "Set conf_file; default = "^(!conf_file); 
	       "-n", Arg.Set nop, "Don't actually do anything -- just print out";
	       "-d", Arg.Set debug, "Print debug information abou the scheduler"]
      ignore "sched_equitCigri [option]";
    let opts = if !istest 
    then { conn = { Mysql.dbhost = Some "pawnee"; 
		    Mysql.dbname = Some "cigriSched"; 
		    Mysql.dbport = None;
		    Mysql.dbpwd = Some "cigriSched"; 
		    Mysql.dbuser = Some "cigriSched" };
	   flood = 50; }
    else read_conf !conf_file in 
    let conv = function Some s -> s | None -> "''" in
      Printf.printf "Connecting to database %s on %s@%s\n" 
	(conv opts.conn.Mysql.dbname) 
	(conv opts.conn.Mysql.dbuser)
	(conv opts.conn.Mysql.dbhost);
      flush stdout;
      let dbd = Mysql.connect opts.conn in 
      let mjobs = getInfoMjobs dbd and clusterInfo = getClusterInfo dbd in 
	List.iter printMJob mjobs; 
	print_newline(); 
	List.iter printCluster clusterInfo;
	let sched = schedule opts.flood mjobs clusterInfo in 
	  if !nop then 
	    List.iter printAssign sched
	  else List.iter (makeAssign dbd) sched; 
	  print_endline "[SCHEDULER] End of scheduler EQUIT";;

