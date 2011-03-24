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
CREATE TABLE clusters (
  id SERIAL NOT NULL,
  name VARCHAR(255) NOT NULL,
  api_url VARCHAR(255) NOT NULL,
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
CREATE TYPE campaign_state as ENUM('in_treatment','paused','terminated');
CREATE TABLE campaigns (
  id SERIAL NOT NULL,
  grid_user VARCHAR(255) NOT NULL,
  state campaign_state NOT NULL,
  type VARCHAR(255) NOT NULL,
  name VARCHAR(255),
  submission_time TIMESTAMP,
  jdl text,
  PRIMARY KEY (id)
);

DROP TABLE IF EXISTS campaign_properties;
CREATE TABLE campaign_properties (
  id SERIAL NOT NULL,
  name VARCHAR(255) NOT NULL,
  value VARCHAR(255) NOT NULL,
  cluster_id INTEGER, -- if NULL, then it's a global --
  campaign_id INTEGER NOT NULL,
  PRIMARY KEY (id)
);
CREATE INDEX campaign_properties_idx ON campaign_properties (name,campaign_id);


