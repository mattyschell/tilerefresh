CREATE OR REPLACE PACKAGE BODY TEST_GISLAYER
AS

   --mschell! 20170526

   PROCEDURE CREATE_FIXTURES (
       p_namestub     IN VARCHAR2 DEFAULT 'TEST_GISLAYER'
    )
   AS

      psql        VARCHAR2(4000);
      shape       SDO_GEOMETRY;

   BEGIN

      FOR i IN 1 .. 7
      LOOP

         psql := 'CREATE TABLE ' || p_namestub || TO_CHAR(i) || '( '
              || 'objectid INTEGER, '
              || 'businessid NUMBER, '
              || 'esriname NVARCHAR2(50), '
              || 'normalname VARCHAR2(64), '
              || 'yearbuilt NUMBER, '
              || 'last_edited DATE, '
              || 'shape sdo_geometry, '
              || 'CONSTRAINT ' || p_namestub || i || 'pkc PRIMARY KEY (objectid))';

         BEGIN
            EXECUTE IMMEDIATE psql;
         EXCEPTION
         WHEN OTHERS
         THEN
            IF sqlcode = -955
            THEN
               EXECUTE IMMEDIATE 'DROP TABLE ' || p_namestub || i;
               EXECUTE IMMEDIATE psql;
            ELSE
               RAISE_APPLICATION_ERROR(-20001, SQLERRM);
            END IF;
         END;

         psql := 'CREATE INDEX ' || p_namestub || i || 'idx ON '
              || p_namestub || i || ' (businessid) ';

         EXECUTE IMMEDIATE psql;

      END LOOP;

      FOR i IN 1 .. 7
      LOOP

         psql := 'INSERT INTO ' || p_namestub || TO_CHAR(i) || ' '
              || '(objectid, businessid, esriname, normalname, yearbuilt, last_edited, shape) '
              || 'VALUES '
              || '(:p1,:p2,:p3,NULL,:p5,:p6,:p7) ';

         FOR j IN 1 .. 10
         LOOP
         
            IF i <= 3
            THEN
              
               --shapes are rectangles ascending to the NE in a chain []
               --                                                   []
               --                                                 []
               
               shape := SDO_GEOMETRY(2003,2263,NULL,
                                         SDO_ELEM_INFO_ARRAY(1,1003,1),
                                         SDO_ORDINATE_ARRAY(
                                            1000100 + (j * 100), 250000 + (j * 100),
                                            1000100 + (j * 100), 250100 + (j * 100),
                                            1000000 + (j * 100), 250100 + (j * 100),
                                            1000000 + (j * 100), 250000 + (j * 100),
                                            1000100 + (j * 100), 250000 + (j * 100)
                                            )
                                      );
                                      
            ELSIF i IN (4,5)
            THEN
            
               --shapes are horizontal lines ascending to the NE  --- 
               --                                                ---
               --                                               ---
               
               shape := SDO_GEOMETRY(2002,2263,NULL,
                                          SDO_ELEM_INFO_ARRAY(1,2,1),
                                          SDO_ORDINATE_ARRAY(
                                             1010000 + (j * 100), 265000 + (j * 100),
                                             1011000 + (j * 100), 265000 + (j * 100)
                                             )
                                    );

            ELSIF i IN (6,7)
            THEN
            
               shape := SDO_GEOMETRY(2001,2263,
                                          SDO_POINT_TYPE(
                                             1010000 + (j * 100),
                                             265000 + (j * 100),
                                             NULL),
                                     NULL,NULL);
                                     
                                     
            END IF;
                    
            EXECUTE IMMEDIATE psql USING j,
                                         j,
                                         CHR(64 + j),
                                         2000,
                                         SYSDATE,
                                         shape;
                                          
            IF  j = 10
            AND (i = 3 OR i = 5 OR i = 7)
            THEN
            
               --3, 5 and 7 get one more record
            
               IF i = 3
               THEN
               
                  shape := SDO_GEOMETRY(2003,2263,NULL,
                                            SDO_ELEM_INFO_ARRAY(1,1003,1),
                                            SDO_ORDINATE_ARRAY(
                                               1000100 + ((j+1) * 100), 250000 + ((j+1) * 100),
                                               1000100 + ((j+1) * 100), 250100 + ((j+1) * 100),
                                               1000000 + ((j+1) * 100), 250100 + ((j+1) * 100),
                                               1000000 + ((j+1) * 100), 250000 + ((j+1) * 100),
                                               1000100 + ((j+1) * 100), 250000 + ((j+1) * 100)
                                               )
                                       );
                    
               ELSIF i = 5
               THEN
               
                  shape := SDO_GEOMETRY(2002,2263,NULL,
                                          SDO_ELEM_INFO_ARRAY(1,2,1),
                                          SDO_ORDINATE_ARRAY(
                                             1010000 + ((j+1) * 100), 265000 + ((j+1) * 100),
                                             1011000 + ((j+1) * 100), 265000 + ((j+1) * 100)
                                             )
                                       );
              
               ELSIF i = 7
               THEN
               
                  shape := SDO_GEOMETRY(2001,2263,
                                             SDO_POINT_TYPE(
                                                1010000 + ((j+1) * 100),
                                                265000 + ((j+1) * 100),
                                                NULL),
                                        NULL,NULL);
               
               
               END IF;
            
               EXECUTE IMMEDIATE psql USING (j+1),
                                            (j+1),
                                            CHR(64 + (j+1)),
                                            2000,
                                            SYSDATE,
                                            shape;
            
            END IF;

         END LOOP;

      END LOOP;

      COMMIT;

      --1 and 2 will be equal
      --TestA: 1 intersect 2 ==> (1..10)
      --TestB: 2 diff 1 ==> ()
      --TestC: 1 diff 2 ==> ()

      --2 ==> 3 (polys) and 
      --4 ==> 5 (lines) and
      --6 ==> 7 (points) will differ as follows
      --businessid 1 will be deleted
      --businessid 2 will be unchanged
      --businessid 3 will have its esriname updated
      --businessid 4 will be unchanged
      --businessid 5 will have its nomalname populated instead of null
      --businessid 6 will be unchanged
      --businessid 7 will have its yearbuilt (NUMBER) updated
      --businessid 8 will have its last_edited (DATE) updated
      --businessid 9 will have its shape edited
      --businessid 10 will have its shape NULLed
      --businessid 11 will be added as a new record

      --TestD: 3 diff 2 ==> (3, 5, 7, 8, 9, 10, 11)
      --TestE: 2 diff 3 ==> (1, 3, 5, 7, 8, 9, 10)
      --TestF: (2 diff 3) + (2 intersect 3) = (original set, 1..10)
      --TestG: lines (2 diff 3) + (2 intersect 3) = (original set, 1..10)
      --TestH: points (2 diff 3) + (2 intersect 3) = (original set, 1..10)
      --TestI: 3 diff 2 esriname, last_edited columns only ==> (3, 8, 9, 10, 11)

      FOR i IN 1 .. 7
      LOOP

         IF i = 3
         OR i = 5
         OR i = 7
         THEN
         
            psql := 'DELETE FROM ' || p_namestub || i || ' a '
                 || 'WHERE a.businessid = :p1 ';
            EXECUTE IMMEDIATE psql USING 1;

            psql := 'UPDATE ' || p_namestub || i || ' a '
                 || 'SET a.esriname = :p1 '
                 || 'WHERE a.businessid = :p2 ';
            EXECUTE IMMEDIATE psql USING 'ZZZ',
                                         3;

            psql := 'UPDATE ' || p_namestub || i || ' a '
                 || 'SET a.normalname = :p1 '
                 || 'WHERE a.businessid = :p2 ';
            EXECUTE IMMEDIATE psql USING 'ZZZ',
                                         5;

            psql := 'UPDATE ' || p_namestub || i || ' a '
                 || 'SET a.yearbuilt = :p1 '
                 || 'WHERE a.businessid = :p2 ';
            EXECUTE IMMEDIATE psql USING 3000,
                                         7;

            psql := 'UPDATE ' || p_namestub || i || ' a '
                 || 'SET a.last_edited = :p1 '
                 || 'WHERE a.businessid = :p2 ';
            EXECUTE IMMEDIATE psql USING SYSDATE + 1,
                                         8;

            IF i = 3
            THEN
               
               --poly morph
               psql := 'UPDATE ' || p_namestub || i || ' a '
                    || 'SET a.shape = sdo_geom.sdo_arc_densify(sdo_geom.sdo_buffer(a.shape, :p1, :p2),:p3,:p4) '
                    || 'WHERE a.businessid = :p5 ';
               EXECUTE IMMEDIATE psql USING 1,
                                            .0005,
                                            .0005,
                                            'arc_tolerance=0.05',
                                            9;
                                            
            ELSIF i = 5
            THEN
            
               --line edit
               psql := 'UPDATE ' || p_namestub || i || ' a '
                    || 'SET '
                    || 'a.shape = '
                    || 'sdo_util.polygontoline(sdo_geom.sdo_arc_densify(sdo_geom.sdo_buffer(a.shape, :p1, :p2),:p3,:p4)) '
                    || 'WHERE a.businessid = :p5 ';
               EXECUTE IMMEDIATE psql USING 1,
                                            .0005,
                                            .0005,
                                            'arc_tolerance=0.05',
                                            9;
                                            
            ELSIF i = 7
            THEN
            
               --point edit set equal to lower left 
               psql := 'UPDATE ' || p_namestub || i || ' a '
                    || 'SET '
                    || 'a.shape = '
                    || '(select shape from ' || p_namestub || i || ' WHERE businessid = :p1) '
                    || 'WHERE a.businessid = :p2 ';
               EXECUTE IMMEDIATE psql USING 2,
                                            9;
            
            END IF;

            psql := 'UPDATE ' || p_namestub || i || ' a '
                 || 'SET a.shape = NULL '
                 || 'WHERE a.businessid = :p1 ';
            EXECUTE IMMEDIATE psql USING 10;
            
         END IF;
         
      END LOOP;

      COMMIT;

   END CREATE_FIXTURES;


    PROCEDURE TEARDOWN_FIXTURES (
       p_namestub    IN VARCHAR2 DEFAULT 'TEST_GISLAYER'
    )
    AS

       psql       VARCHAR2(4000);

    BEGIN

       FOR i IN 1 .. 7
       LOOP

          EXECUTE IMMEDIATE 'DROP TABLE ' || p_namestub || i;

       END LOOP;

    END TEARDOWN_FIXTURES;

   FUNCTION UNITTESTS (
      p_testregimen  IN VARCHAR2 DEFAULT 'ALL',
      p_namestub     IN VARCHAR2 DEFAULT 'TEST_GISLAYER'
   ) RETURN VARCHAR2
   AS

      --testfixture 1 and 2 are identical sets of polygons
      --3 differs from 2 for specific tests. See create_fixtures
      --4 differs from 5 in the same manner but in 2D
      --6 differs from 7 in the same manner but in 1D 

      --TestA: 1 intersect 2 ==> (1..10)
      --TestB: 2 diff 1 ==> ()
      --TestC: 1 diff 2 ==> ()
      --TestD: 3 diff 2 ==> (3, 5, 7, 8, 9, 10, 11)
      --TestE: 2 diff 3 ==> (1, 3, 5, 7, 8, 9, 10)
      --TestF: (2 diff 3) + (2 intersect 3) = (original set, 1..10)
      --TestG: (4 diff 5) + (4 intersect 5) = (original set, 1..10)
      --TestH: (6 diff 7) + (6 intersect 7) = (original set, 1..10)
      --TestI: 3 diff 2 with esriname, last_edited cols ==> (3, 8, 9, 10, 11)

      output         VARCHAR2(8000) := '';
      psql           VARCHAR2(4000);
      kount          PLS_INTEGER;
      expectedset    MDSYS.stringlist := MDSYS.stringlist();
      limitcols      VARCHAR2(64) := 'esriname,last_edited';

   BEGIN

      IF p_testregimen = 'ALL'
      OR p_testregimen = 'A'
      THEN

         --TestA: 1 intersect 2 ==> (1..10)
         --       Because 1 and 2 are the same
         --below should return 0
         --intersectset will be (1..10)
         --test (intersectset 1..10) minus (testfixture1 1..10)
         --     union
         --     (testfixture1 1..10) minus (intersectset 1..10)

         psql := 'WITH intersectset '
              || 'AS (SELECT * '
              || '       FROM TABLE ( '
              || '           SELECT GisLayer (:p1,:p2,:p3).Lintersect ( '
              || '                  GisLayer (:p4,:p5,:p6)) '
              || '           FROM DUAL)) '
              || 'SELECT COUNT (*) '
              || 'FROM ( (SELECT COLUMN_VALUE FROM intersectset '
              || '        MINUS '
              || '        SELECT to_char(businessid) FROM ' || p_namestub || '1) '
              || '  UNION ALL '
              || '       (SELECT to_char(businessid) FROM ' || p_namestub || '1 '
              || '        MINUS '
              || '        SELECT COLUMN_VALUE FROM intersectset) '
              || '  ) ';

         --dbms_output.put_line(psql);
         EXECUTE IMMEDIATE psql INTO kount
                                USING  p_namestub || '1', 'objectid', 'businessid',
                                       p_namestub || '2', 'objectid', 'businessid';

         output := output || 'TESTA Lintersect identical: ';

         IF kount = 0
         THEN

            output := output || 'PASS ' || CHR(10);

         ELSE

            output := output || 'FAIL ' || CHR(10);

         END IF;

      END IF;

      --sql for B and C
      psql := 'SELECT COUNT (*) '
           || 'FROM TABLE ( '
           || '     SELECT GisLayer (:p1, :p2, :p3).Ldiff ( '
           || '            GisLayer (:p4, :p5, :p6)) '
           || '     FROM DUAL) ';

      IF p_testregimen = 'ALL'
      OR p_testregimen = 'B'
      THEN

         --TestB: 2 diff 1 ==> ()
         --       Because 2 and 1 are the same

         --dbms_output.put_line(psql);
         EXECUTE IMMEDIATE psql INTO kount
                                USING  p_namestub || '2', 'objectid', 'businessid',
                                       p_namestub || '1', 'objectid', 'businessid';

         output := output || 'TESTB Ldiff identical: ';

         IF kount = 0
         THEN

            output := output || 'PASS ' || CHR(10);

         ELSE

            output := output || 'FAIL ' || CHR(10);

         END IF;

      END IF;

      IF p_testregimen = 'ALL'
      OR p_testregimen = 'C'
      THEN

         --TestC: 1 diff 2 ==> ()
         --       Because 2 and 1 are the same

         --dbms_output.put_line(psql);
         EXECUTE IMMEDIATE psql INTO kount
                                USING  p_namestub || '1', 'objectid', 'businessid',
                                       p_namestub || '2', 'objectid', 'businessid';

         output := output || 'TESTC Ldiff identical reverse: ';

         IF kount = 0
         THEN

            output := output || 'PASS ' || CHR(10);

         ELSE

            output := output || 'FAIL ' || CHR(10);

         END IF;

      END IF;

      --SQL shared for D and E
      psql := 'WITH diffset '
           || 'AS (SELECT * '
           || '    FROM TABLE ( '
           || '         SELECT GisLayer (:p1, :p2, :p3).Ldiff ( '
           || '                GisLayer (:p4, :p5, :p6)) '
           || '         FROM DUAL)) '
           || 'SELECT COUNT (*) '
           || '   FROM ( (SELECT column_value FROM diffset '
           || '           MINUS '
           || '           SELECT column_value FROM TABLE(:p7)) '
           || '        UNION ALL '
           || '          (SELECT column_value FROM TABLE(:p8) '
           || '           MINUS '
           || '          SELECT column_value FROM diffset)) ';

      IF p_testregimen = 'ALL'
      OR p_testregimen = 'D'
      THEN

         --TestD: 3 diff 2 ==> (3, 5, 7, 8, 9, 10, 11)

         expectedset.EXTEND(7);
         expectedset(1) := '3';
         expectedset(2) := '5';
         expectedset(3) := '7';
         expectedset(4) := '8';
         expectedset(5) := '9';
         expectedset(6) := '10';
         expectedset(7) := '11';

         --dbms_output.put_line(psql);
         EXECUTE IMMEDIATE psql INTO kount
                                USING p_namestub || '3', 'objectid', 'businessid',
                                      p_namestub || '2', 'objectid', 'businessid',
                                      expectedset,
                                      expectedset;

         output := output || 'TESTD Ldiff all combos: ';

         IF kount = 0
         THEN

            output := output || 'PASS ' || CHR(10);

         ELSE

            output := output || 'FAIL ' || CHR(10);

         END IF;


      END IF;

      IF p_testregimen = 'ALL'
      OR p_testregimen = 'E'
      THEN

          --TestE: 2 diff 3 ==> (1, 3, 5, 7, 8, 9, 10)

         expectedset.DELETE;
         expectedset.EXTEND(7);
         expectedset(1) := '1';
         expectedset(2) := '3';
         expectedset(3) := '5';
         expectedset(4) := '7';
         expectedset(5) := '8';
         expectedset(6) := '9';
         expectedset(7) := '10';

         --dbms_output.put_line(psql);
         EXECUTE IMMEDIATE psql INTO kount
                                USING p_namestub || '2', 'objectid', 'businessid',
                                      p_namestub || '3', 'objectid', 'businessid',
                                      expectedset,
                                      expectedset;

         output := output || 'TESTE Ldiff all combos reverse: ';

         IF kount = 0
         THEN

            output := output || 'PASS ' || CHR(10);

         ELSE

            output := output || 'FAIL ' || CHR(10);

         END IF;

      END IF;

      IF p_testregimen = 'ALL'
      OR p_testregimen = 'F'
      OR p_testregimen = 'G'
      OR p_testregimen = 'H'
      THEN

          psql := 'WITH fullset '
               || ' AS (SELECT * '
               || '     FROM TABLE ( '
               || '             SELECT GisLayer (:p1,:p2,:p3).Ldiff ( '
               || '                    GisLayer (:p4,:p5,:p6)) '
               || '             FROM DUAL) '
               || '     UNION '
               || '     SELECT * '
               || '     FROM TABLE ( '
               || '             SELECT GisLayer (:p7,:p8,:p9).Lintersect ( '
               || '                    GisLayer (:p10,:p11,:p12)) '
               || '             FROM DUAL)) '
               || 'SELECT COUNT (*) '
               || '  FROM ( (SELECT COLUMN_VALUE FROM fullset '
               || '          MINUS '
               || '          SELECT to_char(businessid) FROM ' || p_namestub || '2) '
               || '          UNION ALL '
               || '         (SELECT to_char(businessid) FROM ' || p_namestub || '2 '
               || '          MINUS '
               || '          SELECT COLUMN_VALUE FROM fullset)) ';

         IF p_testregimen = 'F'
         OR p_testregimen = 'ALL'
         THEN
         
            --TestF: (2 diff 3) + (2 intersect 3) = (original set, 1..10)
            
            EXECUTE IMMEDIATE psql INTO kount
                                   USING p_namestub || '2', 'objectid', 'businessid',
                                         p_namestub || '3', 'objectid', 'businessid',
                                         p_namestub || '2', 'objectid', 'businessid',
                                         p_namestub || '3', 'objectid', 'businessid';

            output := output || 'TESTF Ldiff + Lintersect: ';

            IF kount = 0
            THEN

               output := output || 'PASS ' || CHR(10);

            ELSE

               output := output || 'FAIL ' || CHR(10);

            END IF;
            
         END IF;
         
         IF p_testregimen = 'G'
         OR p_testregimen = 'ALL'
         THEN
         
            --TestF: (4 diff 5) + (4 intersect 5) = (original set, 1..10)
            
            EXECUTE IMMEDIATE psql INTO kount
                                   USING p_namestub || '4', 'objectid', 'businessid',
                                         p_namestub || '5', 'objectid', 'businessid',
                                         p_namestub || '4', 'objectid', 'businessid',
                                         p_namestub || '5', 'objectid', 'businessid';

            output := output || 'TESTG lines Ldiff + Lintersect: ';

            IF kount = 0
            THEN

               output := output || 'PASS ' || CHR(10);

            ELSE

               output := output || 'FAIL ' || CHR(10);

            END IF;
            
         END IF;
         
         IF p_testregimen = 'H'
         OR p_testregimen = 'ALL'
         THEN
         
            --TestF: (4 diff 5) + (4 intersect 5) = (original set, 1..10)
            
            EXECUTE IMMEDIATE psql INTO kount
                                   USING p_namestub || '6', 'objectid', 'businessid',
                                         p_namestub || '7', 'objectid', 'businessid',
                                         p_namestub || '6', 'objectid', 'businessid',
                                         p_namestub || '7', 'objectid', 'businessid';

            output := output || 'TESTH points Ldiff + Lintersect: ';

            IF kount = 0
            THEN

               output := output || 'PASS ' || CHR(10);

            ELSE

               output := output || 'FAIL ' || CHR(10);

            END IF;
            
         END IF;
         
      END IF;
      

      IF p_testregimen = 'ALL'
      OR p_testregimen = 'I'
      THEN

         -- TestI: 3 diff 2 with esriname, last_edited cols ==> (3, 8, 9, 10, 11)
         -- the limitcols variable is set in this functions declaration
         -- :p7, the optional final argument to .Ldiff is the test here         

         psql := 'WITH diffset '
              || 'AS (SELECT * '
              || '    FROM TABLE ( '
              || '         SELECT GisLayer (:p1, :p2, :p3).Ldiff ( '
              || '                GisLayer (:p4, :p5, :p6), '
              || '                :p7) '
              || '         FROM DUAL)) '
              || 'SELECT COUNT (*) '
              || '   FROM ( (SELECT column_value FROM diffset '
              || '           MINUS '
              || '           SELECT column_value FROM TABLE(:p8)) '
              || '        UNION ALL '
              || '          (SELECT column_value FROM TABLE(:p9) '
              || '           MINUS '
              || '          SELECT column_value FROM diffset)) ';

         expectedset.DELETE;
         expectedset.EXTEND(5);
         expectedset(1) := '3';
         expectedset(2) := '8';
         expectedset(3) := '9';
         expectedset(4) := '10';
         expectedset(5) := '11';

         --dbms_output.put_line(psql);
         EXECUTE IMMEDIATE psql INTO kount
                                USING p_namestub || '3', 'objectid', 'businessid',
                                      p_namestub || '2', 'objectid', 'businessid',
                                      limitcols,
                                      expectedset,
                                      expectedset;

         output := output || 'TESTI Ldiff with limited columns: ';

         IF kount = 0
         THEN

            output := output || 'PASS ' || CHR(10);

         ELSE

            output := output || 'FAIL ' || CHR(10);

         END IF;


      END IF;

      RETURN output;

   END UNITTESTS;

   FUNCTION RUN_TESTS (
      p_namestub     IN VARCHAR2 DEFAULT 'TEST_GISLAYER'
   ) RETURN VARCHAR2
   AS

      output VARCHAR2(8000);

   BEGIN

      TEST_GISLAYER.CREATE_FIXTURES(p_namestub);

      output := TEST_GISLAYER.UNITTESTS('ALL',
                                        p_namestub);

      TEST_GISLAYER.TEARDOWN_FIXTURES(p_namestub);

      RETURN output;

   END RUN_TESTS;

END TEST_GISLAYER;
/
