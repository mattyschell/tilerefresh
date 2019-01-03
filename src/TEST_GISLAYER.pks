CREATE OR REPLACE PACKAGE TEST_GISLAYER
AUTHID CURRENT_USER
AS

   --mschell! 20170526
   --for now intended to be run as a single sql from gradle
   --call to sqlplus ala
   --\tilerefresh\src>sqlplus mschell/iluvdoitt247@giscmnt.doitt.nycnet @TEST_GISLAYER.sql
   

    PROCEDURE CREATE_FIXTURES (
       p_namestub     IN VARCHAR2 DEFAULT 'TEST_GISLAYER'
    );
    
    PROCEDURE TEARDOWN_FIXTURES (
       p_namestub    IN VARCHAR2 DEFAULT 'TEST_GISLAYER'
    );

   FUNCTION UNITTESTS (
      p_testregimen  IN VARCHAR2 DEFAULT 'ALL',
      p_namestub     IN VARCHAR2 DEFAULT 'TEST_GISLAYER'
   ) RETURN VARCHAR2;
    
    FUNCTION RUN_TESTS (
       p_namestub     IN VARCHAR2 DEFAULT 'TEST_GISLAYER' 
    ) RETURN VARCHAR2;
    
END TEST_GISLAYER;
/