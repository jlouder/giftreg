CREATE TABLE gift (
  gift_id             INTEGER         NOT NULL AUTO_INCREMENT,
  short_desc          VARCHAR(1024)   NOT NULL,
  long_desc           VARCHAR(4000)   NULL,
  location            VARCHAR(1024)   NULL,
  wanted_by_person_id INTEGER         NOT NULL,
  bought_by_person_id INTEGER         NULL,
  priority_nbr        INTEGER         NOT NULL,
  PRIMARY KEY (gift_id)
) ENGINE=InnoDB;

CREATE TABLE person (
  person_id         INTEGER         NOT NULL AUTO_INCREMENT,
  email_address     VARCHAR(100)    NOT NULL,
  password          VARCHAR(100)    NOT NULL,
  last_update_dt    INTEGER         NULL,
  PRIMARY KEY (person_id),
  UNIQUE EMAIL_IX (email_address)
) ENGINE=InnoDB;

CREATE TABLE password_reset (
  person_id         INTEGER         NOT NULL,
  secret            VARCHAR(100)    NOT NULL,
  expire_dt         INTEGER         NOT NULL,
  PRIMARY KEY (secret)
) ENGINE=InnoDB;

