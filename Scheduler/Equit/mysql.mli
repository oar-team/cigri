(*
    Copyright (c) 2001-2003 Shawn Wagner <shawnw@speakeasy.org>    
    Copyright (c) 1998, 1999 Christian Lindig <lindig@gaertner.de>.  
    All rights reserved.

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions
    are met:

    1. Redistributions of source code must retain the above copyright
       notice, this list of conditions and the following disclaimer.
    
    2. Redistributions in binary form must reproduce the above
       copyright notice, this list of conditions and the following
       disclaimer in the documentation and/or other materials provided
       with the distribution.

    THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED
    WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
    OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
    DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR AND COPYRIGHT HOLDER BE
    LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
    OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
    PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
    PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
    THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR
    TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
    THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
    SUCH DAMAGE.
*)

(**

    This module provides access to MySQL databases, roughly following the C API

*)

(** {1 Database connections} *)

(** {2 Opening a connection} *)

(** database connection handle *)
type dbd

(** Login information for a database. database. Use [None] for default values *)
type db         = { dbhost    : string option;  (**    database server host *)
                dbname    : string option;  (**    database name        *)
                dbport    : int option;     (**    port                 *)
                dbpwd     : string option;  (**    user password        *)
                dbuser    : string option;  (**    database user        *)
                } 

(** Login information using all defaults *)
val defaults: db

(** [connect db] connects to the database [db] and returns a handle for
   further user *)
external connect : db -> dbd = "db_connect"

(** Shortcut for connecting to a database with mostly default field values *)
val quick_connect: ?host:string -> ?database:string -> ?port:int -> ?password:string -> ?user:string -> unit -> dbd

(** {2 Altering a connection} *)

(** [change_user dbd db] tries to change the current user and database.
   The host and port fields of db are ignored. *)
external change_user : dbd -> db -> unit = "db_change_user"    

(** Another shortcut *)
val quick_change: ?user:string -> ?password:string -> ?database:string -> dbd -> unit

(** [select_db] Switch to a new db, using the current user and password. *)
external select_db   : dbd -> string -> unit = "db_select_db"

(** [disconnect dbd] releases a database connection [dbd]. The handle [dbd] 
   becomes invalid *)
external disconnect : dbd -> unit = "db_disconnect"

(** [ping dbd] makes sure the connection to the server is up, and
   re-establishes it if needed. *)
external ping : dbd -> unit = "db_ping"

(** {2 Information about a connection} *)

(** [list_db] Return a list of all visible databases on the current server *)
external list_dbs    : dbd -> ?pat:string -> unit -> string array option = "db_list_dbs"

(** Return the MySQL client library version *)
external client_info : dbd -> string = "db_client_info"

(** Return information about the server connection *)
external host_info   : dbd -> string = "db_host_info"

(** Return the MySQL server version *)
external server_info : dbd -> string = "db_server_info"

(** Return the protocol version being used *)
external proto_info  : dbd -> int    = "db_proto_info"

(** {2 Errors} *)

(** When most of the API functions fail, they raise this exception with a description of the failure. *)
exception Error of string

(** Possible error codes from a failed operation that doesn't throw an exception *)
(* Auto-generated on Thu Feb 20 06:10:26 2003 from MySQL headers. *)
type error_code = Aborting_connection | Access_denied_error | Alter_info | Bad_db_error | Bad_field_error | Bad_host_error | Bad_null_error | Bad_table_error | Blob_cant_have_default | Blob_key_without_length | Blob_used_as_key | Blobs_and_no_terminated | Cant_create_db | Cant_create_file | Cant_create_table | Cant_create_thread | Cant_delete_file | Cant_drop_field_or_key | Cant_find_dl_entry | Cant_find_system_rec | Cant_find_udf | Cant_get_stat | Cant_get_wd | Cant_initialize_udf | Cant_lock | Cant_open_file | Cant_open_library | Cant_read_charset | Cant_read_dir | Cant_remove_all_fields | Cant_reopen_table | Cant_set_wd | Checkread | Columnaccess_denied_error | Commands_out_of_sync | Con_count_error | Conn_host_error | Connection_error | Db_create_exists | Db_drop_delete | Db_drop_exists | Db_drop_rmdir | Dbaccess_denied_error | Delayed_cant_change_lock | Delayed_insert_table_locked | Disk_full | Dup_entry | Dup_fieldname | Dup_key | Dup_keyname | Dup_unique | Empty_query | Error_on_close | Error_on_read | Error_on_rename | Error_on_write | Field_specified_twice | File_exists_error | File_not_found | File_used | Filsort_abort | Forcing_close | Form_not_found | Function_not_defined | Get_errno | Got_signal | Grant_wrong_host_or_user | Handshake_error | Hashchk | Host_is_blocked | Host_not_privileged | Illegal_grant_for_table | Illegal_ha | Insert_info | Insert_table_used | Invalid_default | Invalid_group_func_use | Invalid_use_of_null | Ipsock_error | Key_column_does_not_exits | Key_not_found | Kill_denied_error | Load_info | Localhost_connection | Mix_of_group_func_and_fields | Multiple_pri_key | Namedpipe_connection | Namedpipeopen_error | Namedpipesetstate_error | Namedpipewait_error | Net_error_on_write | Net_fcntl_error | Net_packet_too_large | Net_packets_out_of_order | Net_read_error | Net_read_error_from_pipe | Net_read_interrupted | Net_uncompress_error | Net_write_interrupted | Nisamchk | No | No_db_error | No_raid_compiled | No_such_index | No_such_table | No_such_thread | No_tables_used | No_unique_logfile | Non_uniq_error | Nonexisting_grant | Nonexisting_table_grant | Nonuniq_table | Normal_shutdown | Not_allowed_command | Not_form_file | Not_keyfile | Null_column_in_index | Old_keyfile | Open_as_readonly | Out_of_memory | Out_of_resources | Out_of_sortmemory | Outofmemory | Parse_error | Password_anonymous_user | Password_no_match | Password_not_allowed | Primary_cant_have_null | Ready | Record_file_full | Regexp_error | Requires_primary_key | Server_gone_error | Server_handshake_err | Server_lost | Server_shutdown | Shutdown_complete | Socket_create_error | Stack_overrun | Syntax_error | Table_cant_handle_auto_increment | Table_cant_handle_blob | Table_exists_error | Table_must_have_columns | Table_not_locked | Table_not_locked_for_write | Tableaccess_denied_error | Tcp_connection | Textfile_not_readable | Too_big_fieldlength | Too_big_rowsize | Too_big_select | Too_big_set | Too_long_ident | Too_long_key | Too_long_string | Too_many_delayed_threads | Too_many_fields | Too_many_key_parts | Too_many_keys | Too_many_rows | Too_many_tables | Udf_exists | Udf_no_paths | Unexpected_eof | Unknown_character_set | Unknown_com_error | Unknown_error | Unknown_host | Unknown_procedure | Unknown_table | Unsupported_extension | Update_info | Update_without_key_in_safe_mode | Version_error | Wrong_auto_key | Wrong_column_name | Wrong_db_name | Wrong_field_spec | Wrong_field_terminators | Wrong_field_with_group | Wrong_group_field | Wrong_host_info | Wrong_key_column | Wrong_mrg_table | Wrong_outer_join | Wrong_paramcount_to_procedure | Wrong_parameters_to_procedure | Wrong_sub_key | Wrong_sum_select | Wrong_table_name | Wrong_value_count | Wrong_value_count_on_row | Yes

(** The status of a query *)
type status = StatusOK (** The query was successful *)
	      | StatusEmpty (** The query was successful, but found no results *)
	      | StatusError of error_code (** There was some problem with the query *)

(** [status dbd] returns the status of the last action on [dbd] *)
val status : dbd -> status

(** [errno dbd] returns the error_code for the last action on [dbd]. Useful when
   you know there's an error, to avoid an extra layer of matching in [status] *)
val errno  : dbd -> error_code

(** [errmsg dbd] returns an error message in case the last operation on [dbd] 
   failed *)
external errmsg : dbd -> string option = "db_errmsg"

(** {1 Queries} *)

(** {2 Making a query} *)

(** handle to access the result of a query *)
type result     

(** [exec dbd str] executes a SQL statement and returns a handle to obtain 
   the result. Check [status] for errors! *) 
external exec : dbd -> string -> result = "db_exec"

(** {2 Getting the results of a query} *)

(** [fetch result] returns the next row from a result as [Some a] or [None] 
   in case there is no next result. The array [a] contains the values from
   the current row, where NULL values are denoted by [None]. Use 
   [column] to fetch single values by field name instead of by
   position *)
external fetch : result -> string option array option = "db_fetch"

(** [to_row result row] sets the current row.

@raise Invalid_argument if the row is out of range.
*)
external to_row : result -> int64 -> unit             = "db_to_row"

(** [size result] returns the size of the actual result set (number of 
   rows) *)
external size : result -> int64 = "db_size"

(** [iter result f] applies f to each row of result in turn, starting
from the first. iter_col applies f to the value of the named column
in every row.

   The iter versions return unit, the map versions return a list of
   the results of all the function applications. If there were no rows
   in the result, returns an empty list.

   The iter forms are all tail-recursive, so they can be used with any
   size of results. The map forms are tail-recursive, but take up
   space with the list they build. *)

val iter : result -> f:(string option array -> unit) -> unit
val iter_col : result -> key:string -> f:(string option -> unit) -> unit
val iter_cols : result -> key:string array -> f:(string option array -> unit) -> unit
val map : result -> f:(string option array -> 'a) -> 'a list
val map_col : result -> key:string -> f:(string option -> 'a) -> 'a list
val map_cols : result -> key:string array -> f:(string option array -> 'a) -> 'a list

(** Returns one field of a result row based on column name. *)
val column : result -> key:string -> row:string option array -> string option


(** {2 Metainformation about a result set} *)

(** The type of a database field. Each of these represents one or more MySQL data types. *)
type dbty       = IntTy          
                | FloatTy        
                | StringTy       
                | SetTy          
                | EnumTy         
                | DateTimeTy     
                | DateTy         
                | TimeTy         
                | YearTy         
                | TimeStampTy    
                | UnknownTy      
                | Int64Ty        
		| BlobTy          
		| DecimalTy

(** The type that describes a field of a table or result *)
type field = { name : string; (** Name of the field *)
               table : string option; (** Table name, or None if a constructed field *)
               def : string option; (** Default value of the field *)
               ty : dbty (** The type of data stored in the field *);
               max_length : int; (** Maximum width of field for the result set *)
               flags : int; (** Flags set *)
               decimals : int (** Number of decimals for numeric fields *)
             } 

(** Turn a field-type type into a string for printing *)
val pretty_type: dbty -> string

(** [affected result] returns the number of rows changed by the last
   UPDATE, or deleted by the last DELETE, or added by the last INSERT,
   or the number of rows returned by the last SELECT *)
external affected : dbd -> int64 = "db_affected"
      
(** [fields result] returns the number of fields in a row *)
external fields : result -> int = "db_fields"

(** [names result] returns an array of the field names for the current result
 *)
 val names : result -> string array

(** [types result] returns an array with the MySQL types of the current 
   result *)
val types : result -> dbty array

(** Returns the information on the next field *)
external fetch_field : result -> field option = "db_fetch_field"

(** Returns information on all the fields *)
external fetch_fields : result -> field array option = "db_fetch_fields"

(** Returns information on a specific field, wit the first field numbered 0 *)
external fetch_field_dir : result -> int -> field option = "db_fetch_field_dir"

(** {1 Working with MySQL data types} *)

(** [escape str] returns the same string as [str] in MySQL syntax with
special characters quoted to not confuse the MySQL parser *)
external escape : string -> string = "db_escape"

(** [xxx2ml str] decodes a MySQL value of type xxx into a corresponding
   OCaml value *)

(** Use for all MySQL signed integer types but BIGINT *)
val int2ml          : string -> int
val decimal2ml      : string -> string
val int322ml        : string -> int32
val nativeint2ml    : string -> nativeint

(* Use for MySQL signed BIGINT type *)
val int642ml        : string -> int64

(** Use for MySQL FLOAT, DOUBLE and REAL types *)
val float2ml        : string -> float

(** Use for MySQL CHAR and VARCHAR types *)
val str2ml          : string -> string

val enum2ml         : string -> string

(** Use for all MySQL BLOB and TEXT types *)
val blob2ml         : string -> string

val set2ml          : string -> string list
val datetime2ml     : string -> int * int * int * int * int * int
val date2ml         : string -> int * int * int
val time2ml         : string -> int * int * int
val year2ml         : string -> int
val timestamp2ml    : string -> int * int * int * int * int * int

(** Not yet supported: DECIMAL and NUMERIC *)

(** [opt f v] applies [f] to optional value [v]. Use this to fetch
   data of known type from database fields which might be NULL:
   [opt int2ml str] *)
val opt : ('a -> 'b) -> 'a option -> 'b option


(** [not_null f v] applies [f] to [Some v]. Use this to fetch data of known 
   type from database fields which never can be NULL: [not_null int2ml str] 
*)
val not_null : ('a -> 'b) -> 'a option -> 'b

(** [ml2xxx v] encodes [v] into MySQL syntax. *)

val ml2str          : string -> string
val ml2blob         : string -> string
val ml2int          : int -> string
val ml2decimal      : string -> string
val ml322int        : int32 -> string
val ml642int        : int64 -> string
val ml2float        : float -> string
val ml2enum         : string -> string
val ml2set          : string list -> string
val ml2datetime     : int * int * int * int * int * int -> string
val ml2datetimel    : year:int -> month:int -> day:int -> hour:int -> min:int -> sec:int -> string
val ml2date         : int * int * int -> string
val ml2datel        : year:int -> month:int -> day:int -> string
val ml2time         : int * int * int -> string
val ml2timel        : hour:int -> min:int -> sec:int -> string
val ml2year         : int -> string
val ml2timestamp    : int * int * int * int * int * int -> string
val ml2timestampl   : year:int -> month:int -> day:int -> hour:int -> min:int -> sec:int -> string


(** [values vs] takes a list of strings and returns a string
   "(a,b,c ..)" where values are separated by comma and the whole
   list is enclosed into parentheses. This is useful to construct
   SQL `insert ... values ( .. )' statements *)
val values          : string list -> string


