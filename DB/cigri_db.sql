CREATE DATABASE IF NOT EXISTS cigri;
CONNECT cigri;

# Creation de l utilisateur cigri
#CONNECT mysql;
#INSERT INTO user (Host,User,Password) VALUES('localhost','cigri',PASSWORD('cigri'));

#INSERT INTO user (Host,User,Password) VALUES('%.imag.fr','cigri',PASSWORD('cigri'));
#INSERT INTO db  (Host,Db,User,Select_priv,Insert_priv,Update_priv,Delete_priv, Create_priv,Drop_priv) VALUES
#				('localhost','cigri','cigri','Y','Y','Y','Y','Y','Y');
#INSERT INTO db  (Host,Db,User,Select_priv,Insert_priv,Update_priv,Delete_priv, Create_priv,Drop_priv) VALUES
#				('%.imag.fr','cigri','cigri','Y','Y','Y','Y','Y','Y');
#FLUSH PRIVILEGES;

#GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP ON cigri.* TO cigri@localhost;
#GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP ON cigri.* TO cigri@"%.imag.fr";
#FLUSH PRIVILEGES;


DROP TABLE IF EXISTS errors;
CREATE TABLE IF NOT EXISTS errors (
errorId INT UNSIGNED NOT NULL AUTO_INCREMENT ,
errorType ENUM('USER_SOFTWARE','RUNNER_SUBMIT','JOBID_PARSE') NOT NULL ,
errorState ENUM('ToFIX','RESUBMITTED','CANCELED') DEFAULT 'ToFIX' NOT NULL ,
errorJobId BIGINT UNSIGNED ,
errorDate DATETIME NOT NULL ,
errorMessage VARCHAR( 255 ) ,
PRIMARY KEY (errorId)
)TYPE = InnoDB;

DROP TABLE IF EXISTS clusterErrors;
CREATE TABLE IF NOT EXISTS clusterErrors (
clusterErrorId INT UNSIGNED NOT NULL AUTO_INCREMENT ,
clusterErrorType ENUM('QSTAT_CMD','PBSNODES_CMD','PBSNODES_PARSE') NOT NULL ,
clusterErrorState ENUM('ToFIX','FIXED') DEFAULT 'ToFIX' NOT NULL ,
clusterErrorClusterName VARCHAR( 100 ) NOT NULL ,
clusterErrorDate DATETIME NOT NULL ,
clusterErrorMessage VARCHAR( 255 ) ,
PRIMARY KEY (clusterErrorId)
)TYPE = InnoDB;

DROP TABLE IF EXISTS schedulerErrors;
CREATE TABLE IF NOT EXISTS schedulerErrors (
schedulerErrorId INT UNSIGNED NOT NULL AUTO_INCREMENT ,
schedulerErrorType ENUM('NB_PARAMS','NB_NODES','FILE') NOT NULL ,
schedulerErrorState ENUM('ToFIX','FIXED') DEFAULT 'ToFIX' NOT NULL ,
schedulerErrorSchedulerId INT UNSIGNED NOT NULL,
schedulerErrorDate DATETIME NOT NULL ,
schedulerErrorMessage VARCHAR( 255 ) ,
PRIMARY KEY (schedulerErrorId)
)TYPE = InnoDB;

DROP TABLE IF EXISTS clusters;
CREATE TABLE IF NOT EXISTS clusters (
clusterName VARCHAR( 100 ) NOT NULL ,
clusterState ENUM('Alive','Dead') DEFAULT 'Alive' NOT NULL ,
clusterAdmin VARCHAR( 100 ) NOT NULL ,
clusterBatch ENUM('PBS','OAR') DEFAULT 'OAR' NOT NULL ,
clusterAlias VARCHAR( 20 ) ,
#nbFreeNodes INT UNSIGNED NOT NULL DEFAULT 0 ,
#clusterState ENUM('VALID','NOTVALID') DEFAULT 'VALID' NOT NULL ,
#clusterCpu VARCHAR( 100 ) NOT NULL ,
#clusterMem INT UNSIGNED ,
#clusterDisk INT UNSIGNED ,
#clusterBandwidth INT UNSIGNED,
PRIMARY KEY (clusterName)
)TYPE = InnoDB;

DROP TABLE IF EXISTS nodes;
CREATE TABLE IF NOT EXISTS nodes (
nodeId INT UNSIGNED NOT NULL AUTO_INCREMENT ,
nodeName VARCHAR( 100 ) NOT NULL ,
nodeClusterName VARCHAR( 100 ) NOT NULL ,
nodeState ENUM('BUSY','FREE') DEFAULT 'BUSY' NOT NULL ,
PRIMARY KEY (nodeId),
INDEX nom (nodeName,nodeClusterName)
)TYPE = InnoDB;

DROP TABLE IF EXISTS jobs;
CREATE TABLE IF NOT EXISTS jobs (
jobId BIGINT UNSIGNED NOT NULL AUTO_INCREMENT ,
jobState ENUM('toLaunch', 'Running', 'RemoteWaiting', 'Terminated', 'Error', 'Killed', 'Fragged') NOT NULL ,
jobFrag ENUM('YES','NO') NOT NULL DEFAULT 'NO' ,
jobMessage VARCHAR( 255 ) ,
jobMJobsId INT UNSIGNED ,
jobParam VARCHAR( 255 ) ,
jobName VARCHAR( 255 ) ,
jobNodeId INT UNSIGNED NOT NULL ,
jobBatchId INT UNSIGNED ,
jobRetCode INT ,
jobCollectedJobId INT DEFAULT 0 NOT NULL ,
jobTSub DATETIME ,
jobTStart DATETIME ,
jobTStop DATETIME ,
#jobTStat VARCHAR( 100 ) ,
PRIMARY KEY (jobId)
)TYPE = InnoDB;

DROP TABLE IF EXISTS multipleJobs;
CREATE TABLE IF NOT EXISTS multipleJobs (
MJobsId INT UNSIGNED NOT NULL ,
MJobsJDL MEDIUMBLOB ,
MJobsState ENUM('IN_TREATMENT','TERMINATED','FRAGGED') NOT NULL DEFAULT 'IN_TREATMENT' ,
MJobsFrag ENUM('YES','NO') NOT NULL DEFAULT 'NO' ,
MJobsUser VARCHAR( 50 ) NOT NULL ,
MJobsName VARCHAR( 255 ) ,
MJobsTSub DATETIME ,
#MJobsTStart DATETIME ,
#MJobsTStop DATETIME ,
#MJOBSMessage VARCHAR( 255 ) ,
PRIMARY KEY (MJobsId)
)TYPE = InnoDB;

DROP TABLE IF EXISTS parameters;
CREATE TABLE IF NOT EXISTS parameters (
parametersMJobsId INT UNSIGNED NOT NULL ,
parametersParam VARCHAR( 255 )  NOT NULL ,
parametersName VARCHAR( 255 ) ,
parametersPriority INT UNSIGNED DEFAULT 0 ,
INDEX param (parametersMJobsId),
PRIMARY KEY (parametersMJobsId, parametersParam)
)TYPE = InnoDB;

DROP TABLE IF EXISTS properties;
CREATE TABLE IF NOT EXISTS properties (
propertiesClusterName VARCHAR( 100 ) NOT NULL ,
propertiesMJobsId INT UNSIGNED NOT NULL ,
propertiesJobCmd VARCHAR( 255 ) NOT NULL ,
propertiesErrorChecker VARCHAR( 255 ) ,
propertiesActivated ENUM('ON','OFF') NOT NULL DEFAULT 'ON',
PRIMARY KEY (propertiesClusterName,propertiesMJobsId)
)TYPE = InnoDB;

DROP TABLE IF EXISTS clusterFreeNodes;
CREATE TABLE IF NOT EXISTS clusterFreeNodes (
clusterFreeNodesClusterName VARCHAR( 100 ) NOT NULL ,
clusterFreeNodesNumber INT UNSIGNED NOT NULL ,
PRIMARY KEY (clusterFreeNodesClusterName)
)TYPE = InnoDB;

DROP TABLE IF EXISTS multipleJobsRemained;
CREATE TABLE IF NOT EXISTS multipleJobsRemained (
multipleJobsRemainedMJobsId INT UNSIGNED NOT NULL ,
multipleJobsRemainedNumber INT NOT NULL ,
PRIMARY KEY (multipleJobsRemainedMJobsId)
)TYPE = InnoDB;

DROP TABLE IF EXISTS jobsToSubmit;
CREATE TABLE IF NOT EXISTS jobsToSubmit (
jobsToSubmitMJobsId INT UNSIGNED NOT NULL ,
jobsToSubmitClusterName VARCHAR( 100 ) NOT NULL ,
jobsToSubmitNumber INT NOT NULL ,
PRIMARY KEY (jobsToSubmitMJobsId,jobsToSubmitClusterName)
)TYPE = InnoDB;

DROP TABLE IF EXISTS users;
CREATE TABLE IF NOT EXISTS users (
userGridName VARCHAR( 50 ) NOT NULL ,
userClusterName VARCHAR( 100 ) NOT NULL ,
userLogin VARCHAR( 50 ) NOT NULL ,
PRIMARY KEY (userGridName,userClusterName)
)TYPE = InnoDB;

DROP TABLE IF EXISTS collectedJobs;
CREATE TABLE IF NOT EXISTS collectedJobs (
collectedJobsMJobsId INT UNSIGNED NOT NULL ,
collectedJobsId INT NOT NULL ,
collectedJobsFileName VARCHAR( 100 ) NOT NULL ,
PRIMARY KEY (collectedJobsMJobsId,collectedJobsId)
)TYPE = InnoDB;

#DROP TABLE IF EXISTS schedulers;
CREATE TABLE IF NOT EXISTS schedulers (
schedulerId INT UNSIGNED NOT NULL AUTO_INCREMENT ,
schedulerFile VARCHAR( 255 ) NOT NULL ,
schedulerPriority VARCHAR( 100 ) NOT NULL DEFAULT 0 ,
PRIMARY KEY (schedulerId)
)TYPE = InnoDB;

DROP TABLE IF EXISTS currentScheduler;
CREATE TABLE IF NOT EXISTS currentScheduler (
currentSchedulerId INT UNSIGNED NOT NULL ,
PRIMARY KEY (currentSchedulerId)
)TYPE = InnoDB;

DROP TABLE IF EXISTS semaphoreCollector;
CREATE TABLE IF NOT EXISTS semaphoreCollector (
semaphoreCollectorId INT UNSIGNED NOT NULL ,
PRIMARY KEY (semaphoreCollectorId)
)TYPE = InnoDB;


INSERT INTO clusters (clusterName,clusterAdmin,clusterBatch) VALUES ("pawnee", "", "OAR");
#INSERT INTO clusters (clusterName,clusterAdmin,clusterBatch) VALUES ("i4", "", "PBS");

INSERT INTO users (userGridName,userClusterName,userLogin) VALUES ("capitn", "pawnee", "capitn");

INSERT INTO schedulers (schedulerFile,schedulerPriority) VALUES ("sched_equitCigri",2);
INSERT INTO schedulers (schedulerFile,schedulerPriority) VALUES ("sched_fifoCigri.pl",1);

