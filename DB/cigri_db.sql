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


DROP TABLE IF EXISTS events;
CREATE TABLE IF NOT EXISTS events (
eventId INT UNSIGNED NOT NULL AUTO_INCREMENT ,
eventType VARCHAR( 50 ) NOT NULL,
eventClass ENUM('CLUSTER','SCHEDULER','JOB','MJOB') NOT NULL ,
eventState ENUM('ToFIX','FIXED') DEFAULT 'ToFIX' NOT NULL ,
eventJobId BIGINT UNSIGNED ,
eventClusterName VARCHAR( 100 ) ,
#eventNodeId INT UNSIGNED ,
eventSchedulerId INT UNSIGNED ,
eventMJobsId INT UNSIGNED ,
eventDate DATETIME NOT NULL ,
eventMessage VARCHAR( 255 ) ,
eventAdminNote VARCHAR( 255 ) ,
PRIMARY KEY (eventId)
)TYPE = InnoDB;

DROP TABLE IF EXISTS clusters;
CREATE TABLE IF NOT EXISTS clusters (
clusterName VARCHAR( 100 ) NOT NULL ,
clusterAdmin VARCHAR( 100 ) NOT NULL ,
clusterBatch ENUM('PBS','OAR','OAR_mysql') DEFAULT 'OAR' NOT NULL ,
clusterAlias VARCHAR( 20 ) ,
clusterDefaultWeight INT UNSIGNED DEFAULT 1 ,
clusterMysqlUser VARCHAR( 50 ) ,
clusterMysqlPassword VARCHAR( 50 ) ,
clusterMysqlDatabase VARCHAR( 50 ) ,
clusterMysqlPort INT UNSIGNED ,
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
jobState ENUM('toLaunch', 'Running', 'RemoteWaiting', 'Terminated', 'Event') NOT NULL ,
jobMJobsId INT UNSIGNED ,
jobParam VARCHAR( 255 ) ,
jobName VARCHAR( 255 ) ,
jobClusterName VARCHAR( 100 ) NOT NULL ,
#jobNodeId INT UNSIGNED ,
jobNodeName VARCHAR( 100 ) ,
jobBatchId INT UNSIGNED ,
jobRetCode INT ,
jobCollectedJobId INT DEFAULT 0 NOT NULL ,
jobTSub DATETIME ,
jobTStart DATETIME ,
jobTStop DATETIME ,
PRIMARY KEY (jobId)
)TYPE = InnoDB;

DROP TABLE IF EXISTS multipleJobs;
CREATE TABLE IF NOT EXISTS multipleJobs (
MJobsId INT UNSIGNED NOT NULL ,
MJobsJDL MEDIUMBLOB ,
MJobsState ENUM('IN_TREATMENT','TERMINATED') NOT NULL DEFAULT 'IN_TREATMENT' ,
MJobsUser VARCHAR( 50 ) NOT NULL ,
MJobsName VARCHAR( 255 ) ,
MJobsTSub DATETIME ,
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
PRIMARY KEY (propertiesClusterName,propertiesMJobsId)
)TYPE = InnoDB;

#DROP TABLE IF EXISTS clusterFreeNodes;
#CREATE TABLE IF NOT EXISTS clusterFreeNodes (
#clusterFreeNodesClusterName VARCHAR( 100 ) NOT NULL ,
#clusterFreeNodesNumber INT UNSIGNED NOT NULL ,
#PRIMARY KEY (clusterFreeNodesClusterName)
#)TYPE = InnoDB;

#DROP TABLE IF EXISTS multipleJobsRemained;
#CREATE TABLE IF NOT EXISTS multipleJobsRemained (
#multipleJobsRemainedMJobsId INT UNSIGNED NOT NULL ,
#multipleJobsRemainedNumber INT NOT NULL ,
#PRIMARY KEY (multipleJobsRemainedMJobsId)
#)TYPE = InnoDB;

DROP TABLE IF EXISTS jobsToSubmit;
CREATE TABLE IF NOT EXISTS jobsToSubmit (
jobsToSubmitMJobsId INT UNSIGNED NOT NULL ,
jobsToSubmitClusterName VARCHAR( 100 ) NOT NULL ,
jobsToSubmitNumber INT UNSIGNED NOT NULL ,
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

DROP TABLE IF EXISTS schedulers;
CREATE TABLE IF NOT EXISTS schedulers (
schedulerId INT UNSIGNED NOT NULL AUTO_INCREMENT ,
schedulerFile VARCHAR( 255 ) NOT NULL ,
schedulerPriority INT NOT NULL DEFAULT 0 ,
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

DROP TABLE IF EXISTS clusterBlackList;
CREATE TABLE IF NOT EXISTS clusterBlackList (
clusterBlackListNum INT UNSIGNED NOT NULL ,
clusterBlackListClusterName VARCHAR( 100 ) NOT NULL ,
clusterBlackListMJobsID INT UNSIGNED NOT NULL ,
clusterBlackListEventId INT UNSIGNED NOT NULL ,
PRIMARY KEY (clusterBlackListClusterName,clusterBlackListEventId)
)TYPE = InnoDB;

DROP TABLE IF EXISTS nodeBlackList;
CREATE TABLE IF NOT EXISTS nodeBlackList (
nodeBlackListNum INT UNSIGNED NOT NULL ,
nodeBlackListNodeId INT UNSIGNED NOT NULL ,
nodeBlackListMJobsID INT UNSIGNED NOT NULL ,
nodeBlackListEventId INT UNSIGNED NOT NULL ,
PRIMARY KEY (nodeBlackListNodeId,nodeBlackListEventId)
)TYPE = InnoDB;

DROP TABLE IF EXISTS userBlackList;
CREATE TABLE IF NOT EXISTS userBlackList (
userBlackListNum INT UNSIGNED NOT NULL ,
userBlackListUserGridName VARCHAR( 50 ) NOT NULL ,
userBlackListClusterName VARCHAR( 100 ) NOT NULL ,
userBlackListEventId INT UNSIGNED NOT NULL ,
PRIMARY KEY (userBlackListUserGridName,userBlackListEventId)
)TYPE = InnoDB;

DROP TABLE IF EXISTS collectBlackList;
CREATE TABLE IF NOT EXISTS collectBlackList (
collectBlackListNum INT UNSIGNED NOT NULL ,
collectBlackListMJobsID INT UNSIGNED ,
collectBlackListClusterName VARCHAR( 100 ) ,
collectBlackListEventId INT UNSIGNED NOT NULL ,
#PRIMARY KEY ()
)TYPE = InnoDB;

DROP TABLE IF EXISTS schedulerBlackList;
CREATE TABLE IF NOT EXISTS schedulerBlackList (
schedulerBlackListNum INT UNSIGNED NOT NULL ,
schedulerBlackListSchedulerId INT UNSIGNED NOT NULL ,
schedulerBlackListEventId INT UNSIGNED NOT NULL ,
PRIMARY KEY (schedulerBlackListSchedulerId,schedulerBlackListEventId)
)TYPE = InnoDB;

DROP TABLE IF EXISTS resubmissionLog;
CREATE TABLE IF NOT EXISTS resubmissionLog (
resubmissionLogEventId INT UNSIGNED NOT NULL ,
PRIMARY KEY (resubmissionLogEventId)
)TYPE = InnoDB;

DROP TABLE IF EXISTS fragLog;
CREATE TABLE IF NOT EXISTS fragLog (
fragLogEventId INT UNSIGNED NOT NULL ,
PRIMARY KEY (fragLogEventId)
)TYPE = InnoDB;

INSERT INTO clusters (clusterName,clusterAdmin,clusterBatch) VALUES ("pawnee", "", "OAR");
#INSERT INTO clusters (clusterName,clusterAdmin,clusterBatch) VALUES ("i4", "", "PBS");

INSERT INTO users (userGridName,userClusterName,userLogin) VALUES ("capitn", "pawnee", "capitn");

INSERT INTO schedulers (schedulerFile,schedulerPriority) VALUES ("sched_equitCigri",2);
INSERT INTO schedulers (schedulerFile,schedulerPriority) VALUES ("sched_fifoCigri.pl",1);

