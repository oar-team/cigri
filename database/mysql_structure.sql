DROP TABLE IF EXISTS clusters;
CREATE TABLE clusters (
  id INT NOT NULL AUTO_INCREMENT,
  name VARCHAR(255) NOT NULL,
  api_url VARCHAR(255) NOT NULL,
  api_username VARCHAR(255) NOT NULL,
  api_password VARCHAR(255) NOT NULL,
  ssh_host VARCHAR(255),
  batch ENUM('oar2_5','g5k') NOT NULL,
  resource_unit VARCHAR(255) DEFAULT 'resource_id',
  power INT,
  properties VARCHAR(255),
  PRIMARY KEY (id)
);
