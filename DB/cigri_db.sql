CREATE DATABASE IF NOT EXISTS cigri;
#CONNECT cigri;

# Creation de l utilisateur cigri
CONNECT mysql;
INSERT IGNORE INTO user (Host,User,Password) VALUES('localhost','cigri',PASSWORD('cigri'));

#INSERT IGNORE INTO user (Host,User,Password) VALUES('%.imag.fr','cigri',PASSWORD('cigri'));
INSERT IGNORE INTO db  (Host,Db,User,Select_priv,Insert_priv,Update_priv,Delete_priv, Create_priv,Drop_priv) VALUES
				('localhost','cigri','cigri','Y','Y','Y','Y','Y','Y');
#INSERT IGNORE INTO db  (Host,Db,User,Select_priv,Insert_priv,Update_priv,Delete_priv, Create_priv,Drop_priv) VALUES
#				('%.imag.fr','cigri','cigri','Y','Y','Y','Y','Y','Y');
FLUSH PRIVILEGES;

GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP ON cigri.* TO cigri@localhost;
#GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP ON cigri.* TO cigri@"%.imag.fr";
FLUSH PRIVILEGES;

CONNECT cigri;

DROP TABLE IF EXISTS events;
CREATE TABLE IF NOT EXISTS events (
eventId INT UNSIGNED NOT NULL AUTO_INCREMENT ,
eventType VARCHAR( 50 ) NOT NULL,
eventClass ENUM('CLUSTER','SCHEDULER','JOB','MJOB') NOT NULL ,
eventState ENUM('ToFIX','FIXED') DEFAULT 'ToFIX' NOT NULL ,
eventJobId BIGINT UNSIGNED ,
eventClusterName VARCHAR( 100 ) ,
eventSchedulerId INT UNSIGNED ,
eventMJobsId INT UNSIGNED ,
eventDate DATETIME NOT NULL ,
eventMessage TEXT ,
eventAdminNote VARCHAR( 255 ) ,
INDEX eventState (eventState),
PRIMARY KEY (eventId)
)TYPE = InnoDB;

DROP TABLE IF EXISTS clusters;
CREATE TABLE IF NOT EXISTS clusters (
clusterName VARCHAR( 100 ) NOT NULL ,
clusterAdmin VARCHAR( 100 ) NOT NULL ,
clusterBatch ENUM('OAR','OAR2') DEFAULT 'OAR' NOT NULL ,
clusterAlias VARCHAR( 20 ) ,
clusterPower FLOAT DEFAULT '1' NOT NULL ,
clusterResourceUnit VARCHAR( 20 ) ,
#clusterDefaultWeight INT UNSIGNED DEFAULT 1 ,
#clusterMysqlUser VARCHAR( 50 ) ,
#clusterMysqlPassword VARCHAR( 50 ) ,
#clusterMysqlDatabase VARCHAR( 50 ) ,
#clusterMysqlPort INT UNSIGNED ,
PRIMARY KEY (clusterName)
)TYPE = InnoDB;

DROP TABLE IF EXISTS nodes;
CREATE TABLE IF NOT EXISTS nodes (
nodeName VARCHAR( 100 ) NOT NULL ,
nodeClusterName VARCHAR( 100 ) NOT NULL ,
nodeFreeWeight INT UNSIGNED DEFAULT 0 NOT NULL ,
nodeMaxWeight INT UNSIGNED DEFAULT 0 NOT NULL ,
INDEX nodeClusterName (nodeClusterName),
PRIMARY KEY (nodeName,nodeClusterName)
)TYPE = InnoDB;

DROP TABLE IF EXISTS jobs;
CREATE TABLE IF NOT EXISTS jobs (
jobId BIGINT UNSIGNED NOT NULL AUTO_INCREMENT ,
jobState ENUM('toLaunch', 'Running', 'RemoteWaiting', 'Terminated', 'Event') NOT NULL ,
jobMJobsId INT UNSIGNED ,
#jobParam VARCHAR( 255 ) ,
jobParam TEXT ,
jobName VARCHAR( 255 ) ,
jobClusterName VARCHAR( 100 ) NOT NULL ,
jobNodeName VARCHAR( 100 ) ,
jobBatchId INT UNSIGNED ,
jobRetCode INT ,
jobCollectedJobId INT DEFAULT 0 NOT NULL ,
jobTSub DATETIME ,
jobTStart DATETIME ,
jobTStop DATETIME ,
jobCheckpointDate DATETIME ,
jobCheckpointStatus ENUM('ToTreat','InTreatment','Ok','Failed') ,
INDEX jobState (jobState),
INDEX jobMJobsId (jobMJobsId),
INDEX jobClusterName (jobClusterName),
INDEX jobCollectedJobId (jobCollectedJobId),
PRIMARY KEY (jobId)
)TYPE = InnoDB;

DROP TABLE IF EXISTS multipleJobs;
CREATE TABLE IF NOT EXISTS multipleJobs (
MJobsId INT UNSIGNED NOT NULL AUTO_INCREMENT ,
MJobsJDL MEDIUMBLOB ,
MJobsState ENUM('IN_TREATMENT','TERMINATED') NOT NULL DEFAULT 'IN_TREATMENT' ,
MJobsUser VARCHAR( 50 ) NOT NULL ,
MJobsName VARCHAR( 255 ) ,
MJobsTSub DATETIME ,
INDEX MJOBsState (MJobsState),
INDEX MJobsUser (MJobsUser),
INDEX MJOBsId (MJobsId),
PRIMARY KEY (MJobsId)
)TYPE = InnoDB;

#####add for rsync data synchronization of clusters####
DROP TABLE IF EXISTS data_synchron;
CREATE TABLE IF NOT EXISTS data_synchron(
data_synchronMJobsId INT UNSIGNED NOT NULL ,
data_synchronState ENUM('ISSUED','INITIATED','IN_TREATMENT','ERROR','TERMINATED') NOT NULL DEFAULT 'ISSUED' ,
#data_synchronUser VARCHAR( 100 ) NOT NULL ,
#data_synchronHost VARCHAR( 100 ) NOT NULL ,
data_synchronSrc VARCHAR( 255 ) DEFAULT "~" ,
data_synchronTimeout INT UNSIGNED NOT NULL DEFAULT 600,
INDEX data_synchronMJobsId (data_synchronMJobsId),
PRIMARY KEY (data_synchronMJobsId)
)TYPE = InnoDB;
#data_synchronDest VARCHAR( 255 ) DEFAULT "~" ,
##################################


DROP TABLE IF EXISTS parameters;
CREATE TABLE IF NOT EXISTS parameters (
parametersMJobsId INT UNSIGNED NOT NULL ,
#parametersParam VARCHAR( 255 )  NOT NULL ,
parametersParam TEXT  NOT NULL ,
parametersName VARCHAR( 255 ) ,
parametersPriority INT UNSIGNED DEFAULT 0 ,
INDEX parametersMJobsId (parametersMJobsId)
#,
#PRIMARY KEY (parametersMJobsId, parametersParam)
)TYPE = InnoDB;

DROP TABLE IF EXISTS properties;
CREATE TABLE IF NOT EXISTS properties (
propertiesClusterName VARCHAR( 100 ) NOT NULL ,
propertiesMJobsId INT UNSIGNED NOT NULL ,
propertiesJobCmd VARCHAR( 255 ) NOT NULL ,
propertiesJobWalltime TIME NOT NULL ,
propertiesJobWeight INT UNSIGNED NOT NULL , 
propertiesJobNcpus INT UNSIGNED NOT NULL ,
propertiesJobNnodes INT UNSIGNED NOT NULL ,
propertiesExecDirectory VARCHAR( 255 ) DEFAULT "~" ,
propertiesData_synchronState ENUM('','INITIATED','IN_TREATMENT','ERROR','TERMINATED') NOT NULL DEFAULT '' ,
propertiesCheckpointType VARCHAR(32) ,
propertiesCheckpointPeriod INT ,
propertiesClusterPriority INT UNSIGNED,
INDEX propertiesMJobsId (propertiesMJobsId),
PRIMARY KEY (propertiesClusterName,propertiesMJobsId)
)TYPE = InnoDB;

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
INDEX collectedJobsMJobsId (collectedJobsMJobsId),
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

#DROP TABLE IF EXISTS semaphoreCollector;
#CREATE TABLE IF NOT EXISTS semaphoreCollector (
#semaphoreCollectorId INT UNSIGNED NOT NULL ,
#PRIMARY KEY (semaphoreCollectorId)
#)TYPE = InnoDB;

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
nodeBlackListNodeName VARCHAR( 100 ) NOT NULL ,
nodeBlackListClusterName VARCHAR( 100 ) NOT NULL ,
nodeBlackListMJobsID INT UNSIGNED NOT NULL ,
nodeBlackListEventId INT UNSIGNED NOT NULL ,
PRIMARY KEY (nodeBlackListNodeName,nodeBlackListClusterName,nodeBlackListEventId)
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
collectBlackListEventId INT UNSIGNED NOT NULL
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

DROP TABLE IF EXISTS webusers;
CREATE TABLE IF NOT EXISTS webusers (
login varchar(20) NOT NULL default "",
pass varchar(20) default NULL,
PRIMARY KEY  (`login`)
)TYPE = InnoDB;


# Forecasting table
CREATE TABLE `forecasts` (
`MjobsId` INT( 10 ) NOT NULL ,
`average` FLOAT NOT NULL ,
`stddev` FLOAT NOT NULL ,
`throughput` FLOAT NOT NULL ,
`end` INT NOT NULL ,
PRIMARY KEY ( `MjobsId` )
);

# Gridstatus table
CREATE TABLE `gridstatus` (
`timestamp` INT NOT NULL ,
`clusterName` VARCHAR( 100 ) NOT NULL ,
`maxResources` INT NOT NULL ,
`freeResources` INT NOT NULL ,
`usedResources` INT NOT NULL ,
`blacklisted` BOOLEAN DEFAULT 0 ,
PRIMARY KEY ( `timestamp`,`clusterName` )
);

INSERT IGNORE INTO webusers VALUES ("admin", "");

#INSERT INTO clusters (clusterName,clusterAdmin,clusterBatch) VALUES ("pawnee", "", "OAR");
#INSERT INTO clusters (clusterName,clusterAdmin,clusterBatch) VALUES ("i4", "", "PBS");

#INSERT INTO users (userGridName,userClusterName,userLogin) VALUES ("capitn", "pawnee", "capitn");

INSERT IGNORE INTO schedulers (schedulerFile,schedulerPriority) VALUES ("sched_equitCigri",1);
INSERT IGNORE INTO schedulers (schedulerFile,schedulerPriority) VALUES ("sched_fifoCigri.pl",2);

