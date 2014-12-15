#!/usr/bin/env python

import cirods
import argparse

default_n_procs=8

parser = argparse.ArgumentParser(description="Get small files from irods using multiprocessing. May also be used to recursively retrieve files from custom metadata searching. \nBasic usage:\n%s -n 8 /cigri/home/mylogin/mycollection"%__file__)
parser.add_argument('collection_path',
                   help='Path of the collection')
parser.add_argument('-n', metavar='N_PROCS', type=int, default=default_n_procs,
                   help="Number of processes to run in parallel (default: %d)"%default_n_procs)
parser.add_argument('--dest', metavar='DEST_DIR', default=None,
                   help='Destination directory (default: current directory)')
parser.add_argument('--nodots', action='store_true',
                   help='Dont print the dots (else, a dot is printed for each downloaded file)')
parser.add_argument('--query',default=None,
                   help="Metadata filtering query. In this case, collection_path is used to restrict the search to this tree, but searched objects must be inside subcollections. Example: %s --query '[MY_DATA,=,1,d] OR [MY_DATA,>,5,d]' /cigri/home/mylogin"%__file__)
parser.add_argument('--listfile',default=None,
                   help="Give a local file containing the list of files to retrieve")

args = parser.parse_args()

if args.nodots:
  cirods.dots = 0
else: 
  cirods.dots = 1

if args.query == None and args.listfile == None:
    cirods.Get_files_from_collection(args.collection_path,args.dest,args.n)
else:
    if args.listfile == None:
        list=cirods.Query(args.query,"%s/%%"%args.collection_path,"ciget.files")
        cirods.Get_files_From_list(list,args.dest,args.n)
    else:
        cirods.Get_files_From_file(args.listfile,args.dest,args.n)

if not args.nodots:
  print
