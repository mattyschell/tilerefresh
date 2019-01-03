CREATE OR REPLACE PACKAGE TEST_TILEREFRESH
AUTHID CURRENT_USER
AS

   --mschell! 20170620
   --for now intended to be run as a single sql from gradle
   --call to sqlplus ala
   --\tilerefresh\src>sqlplus mschell/iluvdoitt247@giscmnt.doitt.nycnet @TEST_TILEREFRESH.sql
   --which in turn calls TEST_TILEREFRESH.RUN_TESTS


   TYPE stringarray IS TABLE OF VARCHAR2(4000)
   INDEX BY PLS_INTEGER;

    PROCEDURE CREATE_FIXTURES (
       p_namestub     IN VARCHAR2 DEFAULT 'TEST_TILEREFRESH'
    );

    PROCEDURE TEARDOWN_FIXTURES (
       p_namestub    IN VARCHAR2 DEFAULT 'TEST_TILEREFRESH'
    );

   FUNCTION SPLIT (
      p_str   IN VARCHAR2,
      p_regex IN VARCHAR2 DEFAULT NULL,
      p_match IN VARCHAR2 DEFAULT NULL,
      p_end   IN NUMBER DEFAULT 0
   ) RETURN TEST_TILEREFRESH.stringarray DETERMINISTIC;

   FUNCTION UNITTESTS (
      p_testregimen  IN VARCHAR2 DEFAULT 'ALL',
      p_namestub     IN VARCHAR2 DEFAULT 'TEST_TILEREFRESH'
   ) RETURN VARCHAR2;

    FUNCTION RUN_TESTS (
       p_namestub     IN VARCHAR2 DEFAULT 'TEST_TILEREFRESH',
       p_teardown     IN VARCHAR2 DEFAULT 'Y'
    ) RETURN VARCHAR2;



END TEST_TILEREFRESH;
/