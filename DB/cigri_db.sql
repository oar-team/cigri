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
errorId INT UNSIGNED NOT NULL,
errorType ENUM('SYSTEM','TOO_FAST','TOO_SLOW','CHECKED','CLUSTER') NOT NULL ,
errorState ENUM('ToFIX','FIXED') DEFAULT 'ToFIX'NOT NULL ,
errorJobId BIGINT UNSIGNED ,
errorDate DATETIME NOT NULL ,
errorMessage VARCHAR( 255 ) ,
PRIMARY KEY (errorId)
);

DROP TABLE IF EXISTS clusters;
CREATE TABLE IF NOT EXISTS clusters (
clusterName VARCHAR( 100 ) NOT NULL ,
clusterAdmin VARCHAR( 100 ) NOT NULL ,
clusterBatch ENUM('PBS','OAR') NOT NULL ,
#nbFreeNodes INT UNSIGNED NOT NULL DEFAULT 0 ,
#clusterState ENUM('VALID','NOTVALID') DEFAULT 'VALID' NOT NULL ,
#clusterCpu VARCHAR( 100 ) NOT NULL ,
#clusterMem INT UNSIGNED ,
#clusterDisk INT UNSIGNED ,
#clusterBandwidth INT UNSIGNED,
PRIMARY KEY (clusterName)
);

DROP TABLE IF EXISTS nodes;
CREATE TABLE IF NOT EXISTS nodes (
nodeId INT UNSIGNED NOT NULL AUTO_INCREMENT ,
nodeName VARCHAR( 100 ) NOT NULL ,
nodeClusterName VARCHAR( 100 ) NOT NULL ,
nodeState ENUM('BUSY','FREE') DEFAULT 'BUSY' NOT NULL ,
PRIMARY KEY (nodeId),
INDEX nom (nodeName,nodeClusterName)
);

#DROP TABLE IF EXISTS jobTypes;
#CREATE TABLE IF NOT EXISTS jobTypes (
#jobTypeName VARCHAR( 100 ) NOT NULL ,
#jobTypeJDL MEDIUMBLOB NOT NULL,
#PRIMARY KEY (jobTypeName)
#);

DROP TABLE IF EXISTS jobs;
CREATE TABLE IF NOT EXISTS jobs (
jobId BIGINT UNSIGNED NOT NULL AUTO_INCREMENT ,
#jobType VARCHAR( 100 ) ,
#jobJDL MEDIUMBLOB ,
jobState ENUM('toLaunch', 'Waiting', 'Running', 'RemoteWaiting', 'Terminated', 'Error', 'Killed') NOT NULL ,
#jobUser VARCHAR( 50 ) NOT NULL ,
jobMJobsId INT UNSIGNED ,
#jobCmd VARCHAR( 255 ) ,
jobParam TEXT ,
jobNodeId INT UNSIGNED NOT NULL ,
jobBatchId INT UNSIGNED ,
jobRetCode INT ,
jobTSub DATETIME ,
jobTStart DATETIME ,
jobTStop DATETIME ,
jobTStat VARCHAR( 100 ) ,
PRIMARY KEY (jobId)
);

DROP TABLE IF EXISTS multipleJobs;
CREATE TABLE IF NOT EXISTS multipleJobs (
MJobsId INT UNSIGNED NOT NULL ,
#MJobsType VARCHAR( 100 ) ,
MJobsJDL MEDIUMBLOB ,
#MJobsParamFile MEDIUMBLOB ,
MJobsState ENUM('IN_TREATMENT','ERROR','TERMINATED') NOT NULL DEFAULT 'IN_TREATMENT' ,
MJobsUser VARCHAR( 50 ) NOT NULL ,
#MJobsNbTotalJobs BIGINT NOT NULL ,
#MJobsNbCompletedJobs BIGINT DEFAULT 0 ,
MJobsTSub DATETIME ,
MJobsTStart DATETIME ,
MJobsTStop DATETIME ,
MJOBSMessage VARCHAR( 255 ) ,
PRIMARY KEY (MJobsId)
);

#DROP TABLE IF EXISTS jobNode;
#CREATE TABLE IF NOT EXISTS jobNode (
#jobNodeJobId BIGINT UNSIGNED NOT NULL ,
#jobNodeNodeId INT UNSIGNED NOT NULL ,
#PRIMARY KEY (jobNodeJobId, jobNodeNodeId)
#);

DROP TABLE IF EXISTS potentialJobNode;
#CREATE TABLE IF NOT EXISTS potentialJobNode (
#potentialJobNodeMJobsId INT UNSIGNED NOT NULL ,
#potentialJobNodeNodeId INT UNSIGNED NOT NULL ,
#PRIMARY KEY (potentialJobNodeMJobsId, potentialJobNodeNodeId)
#);

DROP TABLE IF EXISTS parameters;
CREATE TABLE IF NOT EXISTS parameters (
parametersMJobsId INT UNSIGNED NOT NULL ,
parametersParam TEXT NOT NULL ,
INDEX param (parametersMJobsId)
#PRIMARY KEY (parametersMJobsId, parametersParam)
);

DROP TABLE IF EXISTS properties;
CREATE TABLE IF NOT EXISTS properties (
propertiesClusterName VARCHAR( 100 ) NOT NULL ,
propertiesMJobsId INT UNSIGNED NOT NULL ,
propertiesJobCmd VARCHAR( 255 ) NOT NULL ,
propertiesErrorChecker VARCHAR( 255 ) ,
propertiesActivated ENUM('ON','OFF') NOT NULL DEFAULT 'ON',
PRIMARY KEY (propertiesClusterName,propertiesMJobsId)
);

DROP TABLE IF EXISTS clusterFreeNodes;
CREATE TABLE IF NOT EXISTS clusterFreeNodes (
clusterFreeNodesClusterName VARCHAR( 100 ) NOT NULL ,
clusterFreeNodesNumber INT UNSIGNED NOT NULL ,
PRIMARY KEY (clusterFreeNodesClusterName)
);

DROP TABLE IF EXISTS multipleJobsRemained;
CREATE TABLE IF NOT EXISTS multipleJobsRemained (
multipleJobsRemainedMJobsId INT UNSIGNED NOT NULL ,
multipleJobsRemainedNumber INT NOT NULL ,
PRIMARY KEY (multipleJobsRemainedMJobsId)
);

DROP TABLE IF EXISTS jobsToSubmit;
CREATE TABLE IF NOT EXISTS jobsToSubmit (
jobsToSubmitMJobsId INT UNSIGNED NOT NULL ,
jobsToSubmitClusterName VARCHAR( 100 ) NOT NULL ,
jobsToSubmitNumber INT NOT NULL ,
PRIMARY KEY (jobsToSubmitMJobsId,jobsToSubmitClusterName)
);

INSERT INTO clusters (clusterName,clusterAdmin,clusterBatch) VALUES ("pawnee", "", "OAR");
#INSERT INTO clusters (clusterName,clusterAdmin,clusterBatch) VALUES ("i4", "", "PBS");
