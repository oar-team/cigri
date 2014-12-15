# CIRODS is a library developped by CIMENT (http://ciment.ujf-grenoble.fr) 
# to ease the use of the PyRods API (Python bindings of the IRODS API)
# It is optimized for the following cases:
# - Manipulation of numerous (<32MB) small files
# - Creation/Selection of numerous user defined meta-data
# @authors: Radhoane <Radhoine.Ben-Younes@e.ujf-grenoble.fr>
#           Bruno Bzeznik <Bruno.Bzeznik@imag.fr>

# This librairy relies on Pyrods, that should be installed first:
#      https://code.google.com/p/irodspython/wiki/PyRods


# Import the API
from irods import *
import os
import sys
#Use for multiprocessig
from multiprocessing import *
from subprocess import *
import time
import atexit
# Used for json liste
import json
# This import is used for parsing the query
import re
import numpy as np
from pyparsing import *
'''
There are 6 main function :

Add_Meta_From_JsonList(Path_Of_Jsonfile)
RmMetaFromJsonList(Path_Of_Jsonfile)
Get_files_From_list(listfiles,option = None ):
Get_files_From_file(File,path(option))
Get_files_from_collection(path_collection)
Query(query,path = None):


'''
#--------------------------------------------------------------

dots = 0


def Add_Meta_From_JsonList(Path_Of_Jsonfile,n_procs=8):


    try:
        Jsonfile = open(Path_Of_Jsonfile,'r')
    except:
        print "Error, Jsonfile not found"
        exit(2)

    # Load the json format file
    js = json.load(Jsonfile)
    List_meta = js['addmetadata']
    # List_meta containt all the list of meda_data
    # Example List_meta[0][0] = /cigri/home/radhoane/test/file1.
    # Path of the first metadata,
    # Establish communication queues

    tasks = JoinableQueue()

    conexions = [ Process_addmetadata(tasks)
                  for i in xrange(n_procs) ]

    # Start all connexion
    for connexion in conexions:
        connexion.start()

    # Now we push all values to the task list.

    for i in range(len(List_meta)):
        tasks.put(List_meta[i])

    # Add a None pill for each consumer for check each process end corretly.
    for i in xrange(n_procs):
        tasks.put(None)

    # Wait for all of the tasks to finish
    tasks.join()

# Procces_addmetata is a class used for , each process is initilse by the
class Process_addmetadata(Process):


        def __init__(self, task_queue):
            #initialize the connection variables
            self.status, self.myEnv = getRodsEnv()
            self.conn, self.errMsg = rcConnect(self.myEnv.rodsHost, self.myEnv.rodsPort, self.myEnv.rodsUserName, self.myEnv.rodsZone)

            self.status = clientLogin(self.conn)

            Process.__init__(self)
            # Initilializ by is the list of task.
            self.task_queue = task_queue

        def run(self):
            # When tasks.start, run start. Each process take a task from the list and execute the function Add_metadata
            proc_name = self.name
            while True:
                # Pick one metadata from the list, protect with a lock
                List_meta = self.task_queue.get()

                #Check if next_task is None, the process can end.
                if List_meta is None:
                    #print '%s: Exiting' % proc_name
                    # The process is end
                    self.task_queue.task_done()
                    # End the connection
                    self.conn.disconnect()
                    break
                # If meta_data have unit option
                if len(List_meta) == 5 :
                    add_meta(self.conn, List_meta[0], List_meta[1], List_meta[2], List_meta[3],List_meta[4])
                    time.sleep(0.3)

                else:
                    add_meta(self.conn, List_meta[0], List_meta[1], List_meta[2], List_meta[3],"None")

                self.task_queue.task_done()

            return
# the function use the function of API pyrods for addmetadata
def add_meta(conn,pathOfFile, typefile, MetaName,MetaValue,Unit = "None"):

    if Unit == "None" :

        if typefile == 'c' :

            addCollUserMetadata(conn,pathOfFile,MetaName,MetaValue)

        else :
            addFileUserMetadata(conn, pathOfFile,MetaName,MetaValue)
    else :

        if typefile == 'c' :
            addCollUserMetadata(conn,pathOfFile,MetaName,MetaValue,Unit)

        else :
            addFileUserMetadata(conn, pathOfFile,MetaName,MetaValue,Unit)


#-------------------------------------------------------------

def Rm_Meta_From_JsonList(Path_Of_Jsonfile,n_procs=8):


    try:
        Jsonfile = open(Path_Of_Jsonfile,'r')
    except:
        print "Error, Jsonfile not found"
        exit(2)

    # Load the json format file
    js = json.load(Jsonfile)
    List_meta = js['addmetadata']
    # List_meta containt all the list of meda_data
    # Example List_meta[0][0] = /cigri/home/radhoane/test/file1.
    # Path of the first metadata,
    # Establish communication queues

    tasks = JoinableQueue()

    conexions = [ Process_rm_metadata(tasks)
                  for i in xrange(n_procs) ]

    # Start all connexion
    for connexion in conexions:
        connexion.start()

    # Now we push all values to the task list.

    for i in range(len(List_meta)):
        tasks.put(List_meta[i])

    # Add a None pill for each consumer for check each process end corretly.
    for i in xrange(n_procs):
        tasks.put(None)

    # Wait for all of the tasks to finish
    tasks.join()

# Procces_addmetata is a class used for , each process is initilse by the
class Process_rm_metadata(Process):


        def __init__(self, task_queue):
            #initialize the connection variables
            self.status, self.myEnv = getRodsEnv()
            self.conn, self.errMsg = rcConnect(self.myEnv.rodsHost, self.myEnv.rodsPort, self.myEnv.rodsUserName, self.myEnv.rodsZone)

            self.status = clientLogin(self.conn)

            Process.__init__(self)
            # Initilializ by is the list of task.
            self.task_queue = task_queue

        def run(self):
            # When tasks.start, run start. Each process take a task from the list and execute the function Add_metadata
            proc_name = self.name
            while True:
                # Pick one metadata from the list, protect with a lock
                List_meta = self.task_queue.get()

                #Check if next_task is None, the process can end.
                if List_meta is None:
                    #print '%s: Exiting' % proc_name
                    # The process is end
                    self.task_queue.task_done()
                    # End the connection
                    self.conn.disconnect()
                    break
                # If meta_data have unit option
                if len(List_meta) == 5 :
                    rm_meta(self.conn, List_meta[0], List_meta[1], List_meta[2], List_meta[3],List_meta[4])
                    time.sleep(0.3)

                else:
                    rm_meta(self.conn, List_meta[0], List_meta[1], List_meta[2], List_meta[3],"None")

                self.task_queue.task_done()

            return
# the function use the function of API pyrods for addmetadata
def rm_meta(conn,pathOfFile, typefile, MetaName,MetaValue,Unit = "None"):

    if Unit == "None" :

        if typefile == 'c' :

            rmCollUserMetadata(conn,pathOfFile,MetaName,MetaValue)

        else :
            rmFileUserMetadata(conn, pathOfFile,MetaName,MetaValue)
    else :

        if typefile == 'c' :
            rmCollUserMetadata(conn,pathOfFile,MetaName,MetaValue,Unit)

        else :
            rmFileUserMetadata(conn, pathOfFile,MetaName,MetaValue,Unit)


#-------------------------------------------------------------

def Get_files_From_list(listfiles,current_path = None,n_procs=8):
    print " Download in progress..."
    '''
    This function use many process for dowload file from a list of file.
    This function is recommended for dowload a large number of medium and small file size.
    Otherwise, the function iget iRODS remains more effective.
    buffersiez = 524288


'    '''
    # Establish communication queues
    tasks = JoinableQueue()

    conexions = [ Process_getFile(tasks)
                  for i in xrange(n_procs) ]


    # Set download directory
    chdrir_path = os.getcwd()
    if current_path  == None:
        current_chdir = os.getcwd()
    else:
        try:
            os.chdir(current_path)
            current_chdir = os.getcwd()
        except OSError:
            print "Error: %s: no such file or directory"%current_path
            exit(2)

    # start processes
    for con in conexions:
        con.start()

    # if we want keeps the same directory tree from the home of iRODS
    for i in range(0,len(listfiles)):
            file = listfiles[i]
            b = file[1]
            path = file[0]+'/'+file[1]
            pathformkdir = file[0].split("/")
            pathfor = pathformkdir[4:len(pathformkdir)]
            # Create all directory in local
            for directroy in pathfor:
                try:
                   os.mkdir('{0}'.format(directroy))
                except OSError:
                    pass
                try:
                   os.chdir('{0}'.format(directroy))
                except OSError:
                    pass
            os.chdir('%s'%current_chdir)
            chemin = '{1}/{0}/{2}'.format("/".join(pathfor),current_chdir,b)
            tasks.put((listfiles[i],chemin))


    # Add a  None to task list for check if the process end
    for i in xrange(n_procs):
        tasks.put(None)

    # Wait for all of the tasks to finish

    tasks.join()
    os.chdir(chdrir_path)

class Process_getFile(Process):


    def __init__(self, task_queue):
        #Inite each connexion with default values and the task_queue.


        self.status, self.myEnv = getRodsEnv()
        self.conn, self.errMsg = rcConnect(self.myEnv.rodsHost, self.myEnv.rodsPort, self.myEnv.rodsUserName, self.myEnv.rodsZone)

        self.status = clientLogin(self.conn)

        Process.__init__(self)
        self.task_queue = task_queue
        global dots
        self.dots = dots

    # run the collection for excute task

    def run(self):

        dots

        #Use just for print the name of connection in case of error.
        proc_name = self.name

        while True:

            next_task = self.task_queue.get() # We take the next values contain in the

            # This condition is just for check if all task has been done.
            if next_task is None:
                # Poison pill means shutdown
                #print '%s: Exiting' % proc_name
                self.task_queue.task_done()
                self.conn.disconnect() # D't forget to disconnect alll collection
                break

            path = next_task[0][0]+'/'+next_task[0][1]
            chemin = next_task[1]
            iget_connexion(self.conn,path,chemin)
            self.task_queue.task_done()

            if self.dots == 1:
                sys.stdout.write(".")
                sys.stdout.flush()

        return

def iget_connexion(conn,pathOfFile_Irods,pathOfFile_local):

        writebuffer = None
        timer = True
        maxtimer = 0
        while timer:
            try :
                f = irodsOpen(conn,'{0}'.format(pathOfFile_Irods), 'r+')
                w = open('{0}'.format(pathOfFile_local),'ab+')
                timer = False
            except:
                time.sleep(random.uniform(0,05 + maxtimer/5, 0.1 + maxtimer /5))
                maxtimer += 1
                if maxtimer == 7:
                    print '--- Error with file:  %s'%pathOfFile_Irods
                    return


        # By default, siezbuffer is 550 000 .
        sizebuffer = 548000
        end = False
        maxtimer = 0
        while not end:
            try:
                writebuffer = f.read(sizebuffer)

                if not writebuffer:
                    w.write(writebuffer)
                    end = True

                w.write(writebuffer)

            except:
                maxtimer += 1
                time.sleep(random.uniform(0,05 + maxtimer/7, 0.1 + maxtimer/7))
                if maxtimer ==7:
                    print '--- Error with file:  %s'%pathOfFile_Irods
                    end = True
                    return

        w.close()
        f.close()
#------------------------------------------------------------------------------


def Get_files_From_file(Infile,current_path = None,n_procs=8):
    try:
        f = open("%s"%Infile,'r')
    except:
        print "Error, file %s not found"%Infile
        exit(2)
    list_file = []
    i = 0
    for ligne in f :
        data = ligne.split(" ")
        try :
            list_file.append((data[0],data[1]))
            i += 1
        except:
            pass
    f.close()
    Get_files_From_list(list_file,current_path,n_procs)
#--------------------------------------------------------------------------

# This function get the list of path of all file containt in one collection
def Get_list_of_file_in_collection(path_collection,conn,list_file):
        c = irodsCollection(conn,path_collection)
        for data in c.getObjects():
            list_file.append((c.getCollName(),data[0]))
        for Collection in c.getSubCollections():
            Get_list_of_file_in_collection(path_collection +'/'+ Collection,conn,list_file)
        return list_file


#-----------------------------------------------------------------------------




# This function gets all the files recursively from a collection

def Get_files_from_collection(path_collection,current_path = None,n_procs=8):

    status, myEnv = getRodsEnv()
    conn, errMsg = rcConnect(myEnv.rodsHost, myEnv.rodsPort,
                             myEnv.rodsUserName, myEnv.rodsZone)
    status = clientLogin(conn)
    list_file = []
    try :
        list_file = Get_list_of_file_in_collection(path_collection,conn,list_file)
    except :
        print " Error Open Collection"
        exit(2)
    print "%s file(s) found "%len(list_file)
    if len(list_file) != 0:
        Get_files_From_list(list_file,current_path,n_procs)


#------------------------------------------------------------------------------

# Query is one of the main function, this can
def Query(query,path = None, Outfile = None):
    print " Metadata search in progress... \n"
    # Parser option
    integer = Word(nums).setParseAction(lambda tOutfile:int(t[0]))
    variable = Word(alphas + "[" + "]",max=10)
    operand = integer | variable
    multop = oneOf('AND /')
    plusop = oneOf('OR -')

    expr = operatorPrecedence( operand,
    [
     (multop, 2, opAssoc.LEFT),
     (plusop, 2, opAssoc.LEFT)
     ]
    )
    # Replace '[' and ']'
    query = query.replace('[', '<meta>')
    query = query.replace(']','</meta>')

    MyStr = query
    m=re.compile('<meta>(.*?)</meta>', re.DOTALL).findall(MyStr)
    l = listeofl()
    i = 0
    for n in m :
         l.add(n)
         char = chr(97 + i)
         i +=1
         query = query.replace('<meta>{0}</meta>'.format(n),char)
    List_of_file=(expr.parseString(query))
    List_of_file = list(arbre(List_of_file,0,definemax(List_of_file),l,path))
    print "\n Found %s File(s)"%len(List_of_file)
    if Outfile == None :
        return List_of_file
    else:
        Outfil = open("%s"%Outfile,'w')
        for data in List_of_file :
            Outfil.writelines("{0} {1} \n".format(data[0],data[1]))
        Outfil.close()
        return List_of_file



#-----------------------SubFunction----------------------------------

def query_data(liste,path):
    liste = liste.split(",")
    meta_data_name = liste[0]
    signe = liste[1]
    meta_data_value = liste[2]
    type = liste[3]

    status, myEnv = getRodsEnv()
    conn, errMsg = rcConnect(myEnv.rodsHost, myEnv.rodsPort,
                         myEnv.rodsUserName, myEnv.rodsZone)
    status = clientLogin(conn)

# Prepare query objects
    genQueryInp = genQueryInp_t()
    sqlCondInp = inxValPair_t()
    selectInp = inxIvalPair_t()
    if type == 'd':
        if meta_data_value == None:
            nbr_condition = 2
        else:
            nbr_condition = 3
# Select the attribute we want, order the result by data size
        if path == None :
            path = myEnv.rodsHome + '%'
        selectInp.init([COL_COLL_NAME,
                COL_DATA_NAME,
                ],
                [NO_DISTINCT,NO_DISTINCT], 2)
    #test l'ordre
        sqlCondInp.init([COL_COLL_NAME,COL_META_DATA_ATTR_NAME, COL_META_DATA_ATTR_VALUE],
                ["like'{0}'".format(path),"='%s'"%meta_data_name,"{0}'{1}'".format(signe,meta_data_value)],
                nbr_condition)
        files = queryToTupleList(conn, selectInp, sqlCondInp)
        print 'the request with meta_name \"{0}\", signe \"{1}\", value \"{2} \" found {3} file(s)  '.format(meta_data_name,signe,meta_data_value,len(files))
        conn.disconnect
    if type == 'c':
        if meta_data_value == None:
            nbr_condition = 2
        else:
            nbr_condition = 3

        if path == None :
            path = myEnv.rodsHome + '%'
# Select the attribute we want, order the result by data size
        selectInp.init([COL_COLL_NAME,
                    COL_DATA_NAME,
                    ],
                    [0, 0]  , 1)
        #test l'ordre
        sqlCondInp.init([COL_COLL_NAME,COL_META_COLL_ATTR_NAME, COL_META_COLL_ATTR_VALUE],
                    ["like'{0}'".format(path),"='%s'"%meta_data_name,"{0}'{1}'".format(signe,meta_data_value)],
                    nbr_condition)
        List_Collection = queryToTupleList(conn, selectInp, sqlCondInp)
        files = []
        for Collection in List_Collection:
            Get_list_of_file_in_collection(Collection,conn,files)
        print 'the request with meta_name \"{0}\", signe \"{1}\", value  \"{2} \"  found {3} collection(s)  '.format(meta_data_name,signe,meta_data_value,len(List_Collection))
        conn.disconnect
    return files

class listeofl():
    def __init__ (self) :
        self.list = []
    def add(self,x):
        self.list.append(x)
    def value(self,x):
        return self.list[(ord(x)- 97 )]

def extract_between(text, sub1, sub2, nth):
    if sub2 not in text.split(sub1, nth)[-1]:
        return None
    return text.split(sub1, nth)[-1].split(sub2, nth)[0]

def definemax(liste):
    number = 1
    while len(liste) >0 :
        liste = liste[0]
        if liste == liste[0]:
            break
        number += 1
    return number
# This function is a parseur for exectute all request in order
def arbre(liste,min,max,l,path):
        min += 1
        if min == max:
            for i in range(len(liste)):
                if liste[i] == 'AND':
                        return set_common_elements(Transforme(liste[i-1],l,path),Transforme(liste[i+1],l,path))

                elif liste[i] == 'OR':
                        return set_element_or(Transforme(liste[i-1],l,path),Transforme(liste[i+1],l,path))
                if len(liste) == 1 :
                    return Transforme(liste[0],l,path)
        else:
            if len(liste)>0 and (liste[0] == liste):
                return result
            result = arbre(liste[0],min,max,l,path)
            for i in range(len(liste)):
                    if liste[i] == 'AND':
                        return  set_common_elements(Transforme(liste[i+1],l,path),result)

                    if liste[i] == 'OR':
                        return set_element_or(Transforme(liste[i+1],l,path),result)
        return result

def Transforme(liste,l,path):
    if len(liste) == 3:
        if liste[1] == 'AND':
            return set_common_elements(query_data(l.value(liste[0]),path),query_data(l.value(liste[2]),path))
        if liste[1] == 'OR':
            return set_element_or(query_data(l.value(liste[0]),path),query_data(l.value(liste[2]),path))
    else:
        return query_data(l.value(liste[0]),path)

def set_element_or(list1,list2):
    return list(set(list1).union(list2))

def set_common_elements(list1, list2):
    return list(set(list1).intersection(list2))

def Parcour(path_collection,conn,list_file):
        c = irodsCollection(conn,path_collection)
        for data in c.getObjects():
            list_file.append((c.getCollName(),data[0]))
        for Collection in c.getSubCollections():
            Parcour(path_collection +'/'+ Collection,conn,list_file)
        return list_file



