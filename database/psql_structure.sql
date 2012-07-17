-- CIGRI-3 POSTGRESQL DATABASE SCHEMA --

DROP TABLE IF EXISTS schema;
CREATE TABLE schema (
  version VARCHAR( 255 ) NOT NULL,
  name VARCHAR( 255 ) NOT NULL
);
INSERT INTO schema VALUES ('3.0.0-alpha0','Cesium137');

DROP TABLE IF EXISTS clusters;
DROP TYPE IF EXISTS api;
CREATE TYPE api as ENUM('oar2_5','g5k');
CREATE TYPE auth_type as ENUM('none','password', 'cert');
CREATE TABLE clusters (
  id SERIAL NOT NULL,
  name VARCHAR(255) NOT NULL,
  api_url VARCHAR(255) NOT NULL,
  api_auth_type auth_type NOT NULL DEFAULT 'password',
  api_username VARCHAR(255),
  api_password VARCHAR(255),
  api_auth_header VARCHAR(255),
  ssh_host VARCHAR(255),
  batch api NOT NULL,
  resource_unit VARCHAR(255) DEFAULT 'resource_id',
  power INT,
  properties VARCHAR(255),
  PRIMARY KEY (id)
);

DROP TABLE IF EXISTS users;
DROP TYPE IF EXISTS auth;
CREATE TYPE auth as ENUM('ldap','mapping');
CREATE TABLE users (
  grid_login VARCHAR(255) NOT NULL,
  auth_type auth NOT NULL,
  cluster_login VARCHAR(255),
  cluster_id INTEGER,
  PRIMARY KEY (grid_login)
);

DROP TABLE IF EXISTS campaigns;
DROP TYPE IF EXISTS campaign_state;
CREATE TYPE campaign_state as ENUM('cancelled', 'in_treatment','paused','terminated');
CREATE TABLE campaigns (
  id SERIAL NOT NULL,
  grid_user VARCHAR(255) NOT NULL,
  state campaign_state NOT NULL,
  type VARCHAR(255) NOT NULL,
  name VARCHAR(255),
  submission_time TIMESTAMP,
  completion_time TIMESTAMP,
  nb_jobs INT,
  jdl text,
  PRIMARY KEY (id)
);
CREATE INDEX campaigns_idx_id ON campaigns (id);

DROP TABLE IF EXISTS campaign_properties;
CREATE TABLE campaign_properties (
  id SERIAL NOT NULL,
  cluster_id INTEGER, -- if NULL, then it's a global --
  campaign_id INTEGER NOT NULL,
  name VARCHAR(255) NOT NULL,
  value VARCHAR(255) NOT NULL,
  PRIMARY KEY (id)
);
CREATE INDEX campaign_properties_idx ON campaign_properties (name,campaign_id);

DROP TABLE IF EXISTS parameters;
CREATE TABLE parameters (
  id BIGSERIAL NOT NULL,
  campaign_id INTEGER NOT NULL,
  name VARCHAR(255),
  param TEXT,
  UNIQUE (campaign_id, name),
  PRIMARY KEY (id)
);
CREATE INDEX parameters_idx_id ON parameters (id);
CREATE INDEX parameters_idx_campaign_id ON parameters (campaign_id);

DROP TABLE IF EXISTS bag_of_tasks;
CREATE TABLE bag_of_tasks (
  id BIGSERIAL NOT NULL,
  campaign_id INTEGER NOT NULL,
  param_id INTEGER NOT NULL,
  PRIMARY KEY (id)
);
CREATE INDEX bag_of_tasks_idx_id ON bag_of_tasks (id);
CREATE INDEX bag_of_tasks_idx_campaign_id ON bag_of_tasks (campaign_id);

DROP TABLE IF EXISTS jobs_to_launch;
CREATE TABLE  jobs_to_launch (
  id BIGSERIAL NOT NULL,
  task_id BIGINT NOT NULL,
  cluster_id INTEGER NOT NULL,
  tag VARCHAR(255),
  runner_options TEXT
);
CREATE INDEX jobs_to_launch_idx_cluster_id ON jobs_to_launch (cluster_id);

DROP TABLE IF EXISTS jobs;
DROP TYPE IF EXISTS job_state;
CREATE TYPE job_state as ENUM('to_launch', 'launching','submitted', 'running','remote_waiting','terminated','event');
CREATE TABLE  jobs (
  id BIGSERIAL NOT NULL,
  campaign_id INTEGER NOT NULL,
  param_id INTEGER NOT NULL,
  batch_id INTEGER,
  cluster_id INTEGER,
  collect_id INTEGER,
  state job_state NOT NULL,
  return_code INTEGER,
  submission_time TIMESTAMP,
  start_time TIMESTAMP,
  stop_time TIMESTAMP,
  node_name varchar(255),
  resources_used INTEGER,
  remote_id BIGINT,
  PRIMARY KEY (id)
);
CREATE INDEX jobs_idx_id ON jobs (id);
CREATE INDEX jobs_idx_campaign_id ON jobs (campaign_id);
CREATE INDEX jobs_idx_batch_id ON jobs (batch_id);
CREATE INDEX jobs_idx_state ON jobs (state);
CREATE INDEX jobs_idx_cluster_id ON jobs (cluster_id);

DROP TABLE IF EXISTS events;
CREATE TYPE event_class as ENUM('cluster','job','campaign');
CREATE TYPE event_state as ENUM('open','closed');
CREATE TYPE checkbox as ENUM('yes','no');
CREATE TABLE  events (
  id BIGSERIAL NOT NULL,
  class event_class NOT NULL,
  code VARCHAR(32) NOT NULL,
  state event_state NOT NULL,
  job_id INTEGER,
  cluster_id INTEGER,
  campaign_id INTEGER,
  parent INTEGER,
  checked checkbox,
  date_open TIMESTAMP,
  date_closed TIMESTAMP,
  message TEXT,
  PRIMARY KEY (id)
);
CREATE INDEX events_idx_id ON events (id);
CREATE INDEX events_idx_class ON events (class);
CREATE INDEX events_idx_code ON events (code);
CREATE INDEX events_idx_job_id ON events (job_id);
CREATE INDEX events_idx_cluster_id ON events (cluster_id);
CREATE INDEX events_idx_campaign_id ON events (campaign_id);
