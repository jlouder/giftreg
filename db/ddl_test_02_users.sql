CREATE ROLE GIFTREG_TEST_ROLE;

CREATE USER GIFTREG_TEST_SCHEMA IDENTIFIED BY "tkMHrqixXn8GyAr5ghnvvVykw"
	DEFAULT TABLESPACE GIFTREG_TEST_DTS
	TEMPORARY TABLESPACE GIFTREG_TEST_TEMP
	QUOTA UNLIMITED ON GIFTREG_TEST_DTS
	ACCOUNT LOCK
/
GRANT RESOURCE TO GIFTREG_TEST_SCHEMA
/

CREATE USER GIFTREG_TEST_APP IDENTIFIED BY "sv0z7cACeOlOyhpF7Y4JbmqtN"
	DEFAULT TABLESPACE GIFTREG_TEST_USERS
	TEMPORARY TABLESPACE GIFTREG_TEST_TEMP
	ACCOUNT UNLOCK
/
GRANT CONNECT TO GIFTREG_TEST_APP
/
