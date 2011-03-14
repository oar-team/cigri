DROP TABLE IF EXISTS clusters;
CREATE TABLE clusters (
  cluster_name VARCHAR(255) NOT NULL,
  cluster_is_homogeneous boolean DEFAULT FALSE,
  PRIMARY KEY (cluster_name)
);
