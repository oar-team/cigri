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
  Printf.printf "MJob %d: %s, reste %d, sur%s\n"
    m.mjobId m.mjobUser m.mjobLeftJobs (concatene ((^) " ") m.mjobClusters)

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
    
(* Lecture du fichier de config *)

let conf_file = ref "/etc/cigri.conf"

(* open Options

(* Version qui aurait pu marcher si Nico ne mettait pas des / de m...
   sans les protéger par des guillemets *)
let read_conf file = 
  let opf = create_options_file file in 
  let db_host = define_option opf ["database_host"] "" string_option "localhost"
  and db_name = define_option opf ["database_name"] "" string_option "truc"
  and db_username = define_option opf ["database_username"] "" string_option ""
  and db_userpassword = define_option opf ["database_userpassword"] "" string_option "" in 
  let convert = function 
      "" -> None
    | s -> Some s in 
    load opf; 
    { Mysql.dbhost = convert (!! db_host); 
      Mysql.dbname = convert (!! db_name);
      Mysql.dbport = None;
      Mysql.dbpwd = convert (!! db_userpassword);
      Mysql.dbuser = convert (!! db_username) } *)

(* La vraie version. Y'a pas intérêt à ce que tu me mettes des mots finissant par un /.
   Sinon je te démonte *)
    
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
    
(* Le programme principal *)    

let main = 
  print_endline "[SCHEDULER] Begining of scheduler EQUIT";
  let istest = ref false in 
    Arg.parse ["-test", Arg.Set istest, "Test Mode : uses a test database";
	       "-conf_file", Arg.String (fun s -> conf_file := s), "Set conf_file; default = "^(!conf_file)]
      ignore "sched_equitCigri [option]";
    let connector = if !istest 
    then { Mysql.dbhost = Some "pawnee"; 
	   Mysql.dbname = Some "cigriSched"; 
	   Mysql.dbport = None;
	   Mysql.dbpwd = Some "cigriSched"; 
	   Mysql.dbuser = Some "cigriSched" }
    else read_conf !conf_file in 
    let conv = function Some s -> s | None -> "''" in
      Printf.printf "Connecting to database %s on %s@%s\n" 
	(conv connector.Mysql.dbname) 
	(conv connector.Mysql.dbuser)
	(conv connector.Mysql.dbhost);
      let dbd = Mysql.connect connector in 
      let mjobs = getInfoMjobs dbd and nodes = getFreeNodes dbd in 
	List.iter printMJob mjobs; 
	print_newline(); 
	List.iter printCluster nodes;
	let sched = schedule mjobs nodes in 
	  List.iter (makeAssign dbd) sched; 
	  print_endline "[SCHEDULER] End of scheduler EQUIT";;

