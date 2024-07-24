-- CIGRI-3 POSTGRESQL DATABASE SCHEMA --

DROP TABLE IF EXISTS schema;
CREATE TABLE schema (
  version VARCHAR( 255 ) NOT NULL,
  name VARCHAR( 255 ) NOT NULL
);
INSERT INTO schema VALUES ('3.0.0-alpha0','Cesium137');

DROP TABLE IF EXISTS clusters;
DROP TYPE IF EXISTS api;
CREATE TYPE api as ENUM('oar2_5','g5k','oar3');
CREATE TYPE auth_type as ENUM('none','password', 'cert', 'jwt');
CREATE TABLE clusters (
  id SERIAL NOT NULL,
  name VARCHAR(255) NOT NULL,
  api_url VARCHAR(255) NOT NULL,
  api_auth_type auth_type NOT NULL DEFAULT 'password',
  api_username VARCHAR(255),
  api_password VARCHAR(255),
  api_auth_header VARCHAR(255),
  api_chunk_size INTEGER NOT NULL DEFAULT 0,
  ssh_host VARCHAR(255),
  batch api NOT NULL,
  resource_unit VARCHAR(255) DEFAULT 'resource_id',
  power INT,
  properties VARCHAR(255),
  stress_factor FLOAT DEFAULT 0,
  enabled BOOLEAN DEFAULT true,
  PRIMARY KEY (id)
);

DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS users_mapping;
DROP TYPE IF EXISTS auth;
CREATE TABLE users_mapping (
  id SERIAL NOT NULL,
  grid_login VARCHAR(255) NOT NULL,
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
  submission_time TIMESTAMP WITH TIME ZONE,
  completion_time TIMESTAMP WITH TIME ZONE,
  nb_jobs INT,
  jdl text,
  PRIMARY KEY (id)
);
CREATE INDEX campaigns_idx_id ON campaigns (id);
CREATE INDEX campaigns_idx_state ON campaigns (state);

DROP TABLE IF EXISTS campaign_properties;
CREATE TABLE campaign_properties (
  id SERIAL NOT NULL,
  cluster_id INTEGER, -- if NULL, then it's a global --
  campaign_id INTEGER NOT NULL,
  name VARCHAR(255) NOT NULL,
  value text NOT NULL,
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
  priority INTEGER NOT NULL DEFAULT 10,
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
  queuing_date TIMESTAMP WITH TIME ZONE,
  runner_options TEXT,
  order_num INTEGER NOT NULL DEFAULT 1,
  PRIMARY KEY (id)
);
CREATE INDEX jobs_to_launch_idx_cluster_id ON jobs_to_launch (cluster_id);

DROP TABLE IF EXISTS jobs;
DROP TYPE IF EXISTS job_state;
CREATE TYPE job_state as ENUM('to_launch', 'launching','submitted', 'running','remote_waiting','terminated','event','batch_waiting');
CREATE TABLE  jobs (
  id BIGSERIAL NOT NULL,
  campaign_id INTEGER NOT NULL,
  param_id INTEGER NOT NULL,
  batch_id INTEGER,
  cluster_id INTEGER,
  collect_id INTEGER,
  state job_state NOT NULL,
  return_code INTEGER,
  submission_time TIMESTAMP WITH TIME ZONE,
  start_time TIMESTAMP WITH TIME ZONE,
  stop_time TIMESTAMP WITH TIME ZONE,
  node_name varchar(255),
  resources_used INTEGER,
  remote_id BIGINT,
  tag VARCHAR(255),
  runner_options TEXT,
  PRIMARY KEY (id)
);
CREATE INDEX jobs_idx_id ON jobs (id);
CREATE INDEX jobs_idx_campaign_id ON jobs (campaign_id);
CREATE INDEX jobs_idx_batch_id ON jobs (batch_id);
CREATE INDEX jobs_idx_state ON jobs (state);
CREATE INDEX jobs_idx_cluster_id ON jobs (cluster_id);
CREATE INDEX jobs_idx_tag ON jobs (tag);
CREATE INDEX jobs_idx_param_id ON jobs (param_id);

DROP TABLE IF EXISTS events;
DROP TYPE IF EXISTS event_class;
DROP TYPE IF EXISTS event_state;
DROP TYPE IF EXISTS checkbox;
CREATE TYPE event_class as ENUM('cluster','job','campaign','notify','log');
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
  notified boolean NOT NULL DEFAULT false,
  date_open TIMESTAMP WITH TIME ZONE,
  date_closed TIMESTAMP WITH TIME ZONE,
  date_update TIMESTAMP WITH TIME ZONE,
  message TEXT,
  PRIMARY KEY (id)
);
CREATE INDEX events_idx_id ON events (id);
CREATE INDEX events_idx_class ON events (class);
CREATE INDEX events_idx_code ON events (code);
CREATE INDEX events_idx_job_id ON events (job_id);
CREATE INDEX events_idx_cluster_id ON events (cluster_id);
CREATE INDEX events_idx_campaign_id ON events (campaign_id);
CREATE INDEX events_idx_state ON events (state);
CREATE INDEX events_idx_notified ON events (notified);

DROP TABLE IF EXISTS queue_counts;
CREATE TABLE queue_counts (
  date TIMESTAMP WITH TIME ZONE,
  campaign_id INTEGER,
  cluster_id INTEGER,
  jobs_count INTEGER
);
CREATE INDEX queue_counts_campaign_cluster ON queue_counts (campaign_id,cluster_id);

DROP TABLE IF EXISTS admission_rules;
CREATE TABLE admission_rules (
  id SERIAL NOT NULL,
  code TEXT
);

DROP TABLE IF EXISTS user_notifications;
DROP TYPE IF EXISTS notifications;
CREATE TYPE notifications as ENUM('mail','xmpp','log','irc');
CREATE TABLE user_notifications (
  id SERIAL NOT NULL,
  grid_user VARCHAR(255) NOT NULL,
  type notifications,
  identity VARCHAR(255),
  severity VARCHAR(32),
  UNIQUE (grid_user, identity, type)
);
CREATE INDEX user_notifications_idx_grid_user ON user_notifications (grid_user);

DROP TABLE IF EXISTS grid_usage;
CREATE TABLE grid_usage (
  id BIGSERIAL NOT NULL,
  date TIMESTAMP WITH TIME ZONE NOT NULL,
  cluster_id INTEGER,
  max_resources INTEGER,
  used_resources INTEGER,
  unavailable_resources INTEGER,
  used_by_cigri INTEGER
);
CREATE INDEX grid_usage_idx_date ON grid_usage (date);

DROP TABLE IF EXISTS users_priority;
CREATE TABLE users_priority (
  id SERIAL NOT NULL,
  grid_user VARCHAR(255) NOT NULL,
  cluster_id INTEGER NOT NULL,
  priority INTEGER NOT NULL
);
CREATE INDEX users_priority_idx_grid_user ON users_priority(grid_user);
CREATE INDEX users_priority_idx_cluster_id ON users_priority(cluster_id);

DROP TABLE IF EXISTS tasks_affinity;
CREATE TABLE tasks_affinity (
  id BIGSERIAL NOT NULL,
  param_id INTEGER NOT NULL,
  cluster_id INTEGER NOT NULL,
  priority INTEGER NOT NULL
);
CREATE INDEX tasks_affinity_idx ON tasks_affinity(id);
CREATE INDEX tasks_affinity_idx_param_id ON tasks_affinity(param_id);
CREATE INDEX tasks_affinity_idx_cluster_id ON tasks_affinity(cluster_id);

DROP TABLE IF EXISTS taps;
CREATE TYPE tap_state as ENUM('open','closed');
CREATE TABLE taps (
  id BIGSERIAL NOT NULL,
  cluster_id INTEGER NOT NULL,
  campaign_id INTEGER NOT NULL,
  state tap_state NOT NULL DEFAULT 'open',
  rate INTEGER NOT NULL,
  close_date TIMESTAMP WITH TIME ZONE
);
CREATE INDEX taps_idx ON taps(cluster_id,campaign_id);
CREATE INDEX taps_idx_id ON taps (id);

INSERT INTO admission_rules VALUES (1, '# Title : Filtering users for normal mode on clusters 
# Description : This rule rejects campaigns for which the user requests non best-effort (normal) mode on non-authorized cluster. The list of users is maintained into the /etc/cigri/user_lists file.

user_lists = JSON.parse(File.read(''/etc/cigri/user_lists''))
jdl["clusters"].each do |cluster_name,cluster|
  if cluster["type"] != "best-effort"
    if not (user_lists["normal_authorized"][cluster_name] || []).include?(user)
      raise Cigri::Error, "You are not authorized to launch non best-effort jobs on cluster #{cluster_name}!"
    end
  end
end
');

