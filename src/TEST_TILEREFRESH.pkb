CREATE OR REPLACE PACKAGE BODY TEST_TILEREFRESH
AS

   --mschell! 20170620


   PROCEDURE CREATE_FIXTURES (
       p_namestub     IN VARCHAR2 DEFAULT 'TEST_TILEREFRESH'
    )
   AS

      -- mschell! 20170620
      -- dependent on gislayer object type and test_gislayer package
      -- 1. create a test TILEREFRESH_PARAMS parameter table (inputs)
      -- 2. create a test TILEREFRESH_SEEDS table (outputs)
      -- 3. create gislayer test fixtures

      psql              VARCHAR2(4000);
      testseedcall      VARCHAR2(4000);

   BEGIN

      --dont permit drop and recreation of test data
      --responsibility of teardown
      TILEREFRESH.CREATE_TRPARAMS(p_namestub || '_PARAMS',
                                  'N');

      TILEREFRESH.CREATE_TRSEEDS(p_namestub || '_SEEDS',
                                 'N',
                                  2263,
                                  .0005);
                                 
      TILEREFRESH.CREATE_TRSEEDS(p_namestub || '3857_SEEDS',
                                 'N',
                                 3857,
                                 .0001);

      TEST_GISLAYER.CREATE_FIXTURES();
      --creates TEST_GISLAYER1, TEST_GISLAYER2, TEST_GISLAYER3
      --TEST_GISLAYER1 and TEST_GISLAYER2 are equal
      --2==>3 (polys), 4==>5 (lines), and 6==>7 (points) differ as follows
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


      psql := 'INSERT INTO ' || p_namestub || '_PARAMS ('
           || 'project_name, '
           || 'layer_name, '
           || 'table1, '
           || 'table2, '
           || 'synthkey, '
           || 'businesskey, '
           || 'srid, '
           || 'cols '
           || ') '
           || 'VALUES (:p1,:p2,:p3,:p4,:p5,:p6,:p7,:p8) ';

      --should produce no seed calls, TEST_GISLAYER1 and TEST_GISLAYER2 are equal
      EXECUTE IMMEDIATE psql USING 'TESTEQUAL',
                                   'TEST_SDO',
                                   'TEST_GISLAYER1',
                                   'TEST_GISLAYER2',
                                   'objectid',
                                   'businessid',
                                   2263,
                                   '';

      --should produce several seed calls to interrogate
      EXECUTE IMMEDIATE psql USING 'TESTDIFF',
                                   'TEST_SDO',
                                   'TEST_GISLAYER2',
                                   'TEST_GISLAYER3',
                                   'objectid',
                                   'businessid',
                                   2263,
                                   '';

      --should produce same several seed calls with web mercator MBRs
      EXECUTE IMMEDIATE psql USING 'TESTDIFFSRID',
                                   'TEST_SDO',
                                   'TEST_GISLAYER2',
                                   'TEST_GISLAYER3',
                                   'objectid',
                                   'businessid',
                                   3857,
                                   '';

      --should produce same several seed calls with web mercator MBRs
      EXECUTE IMMEDIATE psql USING 'TESTLINES',
                                   'TEST_SDO',
                                   'TEST_GISLAYER4',
                                   'TEST_GISLAYER5',
                                   'objectid',
                                   'businessid',
                                   3857,
                                   '';

      --should produce same several seed calls with web mercator MBRs
      EXECUTE IMMEDIATE psql USING 'TESTPOINTS',
                                   'TEST_SDO',
                                   'TEST_GISLAYER6',
                                   'TEST_GISLAYER7',
                                   'objectid',
                                   'businessid',
                                   3857,
                                   '';

      --limit to 2 columns of interest, producing several seed calls to interrogate
      EXECUTE IMMEDIATE psql USING 'TESTCOLS',
                                   'TEST_SDO',
                                   'TEST_GISLAYER2',
                                   'TEST_GISLAYER3',
                                   'objectid',
                                   'businessid',
                                   2263,
                                   'esriname,last_edited';

      COMMIT;

   END CREATE_FIXTURES;


   FUNCTION SPLIT (
      p_str   IN VARCHAR2,
      p_regex IN VARCHAR2 DEFAULT NULL,
      p_match IN VARCHAR2 DEFAULT NULL,
      p_end   IN NUMBER DEFAULT 0
   ) RETURN TEST_TILEREFRESH.stringarray DETERMINISTIC
   AS
      int_delim      PLS_INTEGER;
      int_position   PLS_INTEGER := 1;
      int_counter    PLS_INTEGER := 1;
      ary_output     TEST_TILEREFRESH.stringarray;
   BEGIN

      IF p_str IS NULL
      THEN
         RETURN ary_output;
      END IF;

      --Split byte by byte
      --split('ABCD',NULL) gives back A  B  C  D
      IF p_regex IS NULL
      OR p_regex = ''
      THEN
         FOR i IN 1 .. LENGTH(p_str)
         LOOP
            ary_output(i) := SUBSTR(p_str,i,1);
         END LOOP;
         RETURN ary_output;
      END IF;

      LOOP
         EXIT WHEN int_position = 0;
         int_delim  := REGEXP_INSTR(p_str,p_regex,int_position,1,0,p_match);
         IF  int_delim = 0
         THEN
            -- no more matches found
            ary_output(int_counter) := SUBSTR(p_str,int_position);
            int_position  := 0;
         ELSE
            IF int_counter = p_end
            THEN
               -- take the rest as is
               ary_output(int_counter) := SUBSTR(p_str,int_position);
               int_position  := 0;
            ELSE
               ary_output(int_counter) := SUBSTR(p_str,int_position,int_delim-int_position);
               int_counter := int_counter + 1;
               int_position := REGEXP_INSTR(p_str,p_regex,int_position,1,1,p_match);
               IF int_position > length(p_str)
               THEN
                  int_position := 0;
               END IF;
            END IF;
         END IF;
      END LOOP;

     RETURN ary_output;

   END SPLIT;


   FUNCTION UNITTESTS (
      p_testregimen  IN VARCHAR2 DEFAULT 'ALL',
      p_namestub     IN VARCHAR2 DEFAULT 'TEST_TILEREFRESH'
   ) RETURN VARCHAR2
   AS

      --mschell! 20170620

      psql              VARCHAR2(4000);
      params            TILEREFRESH.TRPARAMS_REC;
      output            VARCHAR2(8000);
      kount             PLS_INTEGER;
      kount2            PLS_INTEGER;
      checklist         TEST_TILEREFRESH.stringarray;
      xystrings         TEST_TILEREFRESH.stringarray;
      ageom             MDSYS.SDO_GEOMETRY;
      coordarray        TEST_TILEREFRESH.stringarray;
      extentmbr         MDSYS.SDO_GEOMETRY;
      failflag          PLS_INTEGER := 0;

      -- lets only F this up one time (well many times, but in one location ftw)
      --   optional -
      --   followed by some amount of numbers
      --   then an optional literal dot followed by more numbers
      --   then a comma
      -- repeat 3 times with the comma {3}
      -- then one time same pattern but no comma. Yeah, I know
      --2263  =1000500,250500.000000004,1000600,250600.000000001
      --3857  =-8231264.39462775,4990702.03884623,-8231224.12888567,4990742.45984547
      coordregexp       VARCHAR2(256) := '(-?[0-9]+(\.[0-9]+)?,){3}-?[0-9]+(\.[0-9]+)?';

   BEGIN

      --not a test, rolls error back to run_tests and fails
      --cant continue if no parameters
      params := TILEREFRESH.GET_TRPARAMS('TESTEQUAL',
                                         'TEST_SDO',
                                         p_namestub || '_PARAMS');

      IF p_testregimen = 'ALL'
      OR p_testregimen = 'A'
      THEN

         output := output || 'TESTA DUMPDIFFSSDO of equals: ';

         --low level, returns mbr sdo_geometry, not x1,y1,x2,y2
         --TESTEQUAL project should return no mbrs
         psql := 'SELECT COUNT(*) FROM '
              || 'TABLE(tilerefresh.DUMPDIFFSSDO(:p1,:p2,:p3,:p4,:p5)) t ';

         EXECUTE IMMEDIATE psql INTO kount USING params.table1,
                                                 params.table2,
                                                 params.synthkey,
                                                 params.businesskey,
                                                 params.srid;

         --reverse table1 and table2.  Commutative equal
         EXECUTE IMMEDIATE psql INTO kount2 USING params.table2,
                                                  params.table1,
                                                  params.synthkey,
                                                  params.businesskey,
                                                  params.srid;

         IF  kount = 0
         AND kount2 = 0
         THEN

            output := output || 'PASS ' || CHR(10);

         ELSE

            output := output || 'FAIL ' || CHR(10);

         END IF;

      END IF;

      

      IF p_testregimen = 'ALL'
      OR p_testregimen = 'B'
      THEN

         output := output || 'TESTB DUMPCALLS of equals: ';

         --returns x1,y1,x2,y2 for each diff
         --TESTEQUAL should return nothing however
         --so should do some basic parsing and whatnot without error
         --but insert nothing into the seeds table
         psql := 'CALL tilerefresh.DUMPCALLS(:p1,:p2,:p3,:p4,:p5,:p6) ';

         EXECUTE IMMEDIATE psql USING params.project_name,
                                      params.layer_name,
                                      p_namestub || '_PARAMS',   --last two only
                                      p_namestub || '_SEEDSSEQ', --need for test
                                      .0005,
                                      p_namestub || '_SEEDS';

         COMMIT;

         psql := 'SELECT COUNT(*) '
              || 'FROM ' || p_namestub || '_seeds a '
              || 'WHERE '
              || 'a.project_name = :p1 AND '
              || 'a.layer_name = :p2 ';

         EXECUTE IMMEDIATE psql INTO kount USING params.project_name,
                                                 params.layer_name;

         IF kount = 0
         THEN

            output := output || 'PASS ' || CHR(10);

         ELSE

            output := output || 'FAIL ' || CHR(10);

         END IF;

      END IF;

      --table2 and table3 are different
      params := TILEREFRESH.GET_TRPARAMS('TESTDIFF',
                                         'TEST_SDO',
                                         p_namestub || '_PARAMS');

      --2 <==> 3 differ as follows.
      --sloppy, carrying these factoids over from test_gislayer.*
      --_2_|_3_ expected shapes output : difference description
      --
      -- 1 | x : businessid 1 is deleted
      -- 3 | 3 : businessid 3 esriname is updated
      -- 5 | 5 : businessid 5 nomalname is populated instead of null
      -- 7 | 7 : businessid 7 yearbuilt (NUMBER) is updated
      -- 8 | 8 : businessid 8 last_edited (DATE) is updated
      -- 9 | 9 : businessid 9 shape is edited. In case of points shape is moved
      -- 10| x : businessid 10 shape is NULLed (we do not return null shapes)
      -- x | 11: businessid 11 added as a new record
      --Total: 13 diffs originally from DUMPDIFFSSDO
      --3,5,7,8 are equivalent MBRs, will be dissolved
      --9s edited MBR for polys and lines fully contains its predecessor, will be dissolved
      --13 - 5 = 8 final MBRs from DUMPCALLS polys and lines
      --13 - 4 = 9 final MBRs from DUMPCALLS for points

      --4 ==> 5 will differ the same as 2=>3 but shapes are lines
      --6 ==> 7 will differ the same as 2=>3 but shapes are points

      --_2_|_3_ expected shapes output : difference description
      --limit columns to esriname,last_edited
      --
      -- 1 | x : businessid 1 is deleted
      -- 3 | 3 : businessid 3 esriname is updated
      -- 8 | 8 : businessid 8 last_edited (DATE) is updated
      -- 9 | 9 : businessid 9 shape is edited. In case of points moved to a new location
      -- 10| x : businessid 10 shape is NULLed (we do not return null shapes)
      -- x | 11: businessid 11 added as a new record
      --Total: 9 diffs
      --3,8,9 for polys and lines, MBRs are equal and will be dissolved
      --9-3 = 6


      IF p_testregimen = 'ALL'
      OR p_testregimen = 'C'
      THEN

         output := output || 'TESTC DUMPDIFFSSDO of different tables: ';

         --returns the sdo for each diff
         --see above for explanation of lucky 13
         psql := 'SELECT COUNT(*) FROM '
              || 'TABLE(tilerefresh.DUMPDIFFSSDO(:p1,:p2,:p3,:p4,:p5)) t ';

         EXECUTE IMMEDIATE psql INTO kount USING params.table1,
                                                 params.table2,
                                                 params.synthkey,
                                                 params.businesskey,
                                                 params.srid;

         --commutative
         EXECUTE IMMEDIATE psql INTO kount2 USING params.table2,
                                                  params.table1,
                                                  params.synthkey,
                                                  params.businesskey,
                                                  params.srid;



         IF  kount = 13
         AND kount2 = 13
         THEN

            output := output || 'PASS ' || CHR(10);

         ELSE

            output := output || 'FAIL ' || CHR(10);

         END IF;

      END IF;


      IF p_testregimen = 'ALL'
      OR p_testregimen = 'D'
      THEN

         output := output || 'TESTD DUMPCALLS of different tables: ';

         failflag := 0;

         --returns the full seed call for each diff
         -- not messing with URI or username
         psql := 'CALL tilerefresh.DUMPCALLS(:p1,:p2,:p3,:p4,:p5,:p6) ';

         EXECUTE IMMEDIATE psql USING params.project_name,
                                      params.layer_name,
                                      p_namestub || '_PARAMS',   --last two only
                                      p_namestub || '_SEEDSSEQ', --need for test
                                      .0005,
                                      p_namestub || '_SEEDS';

         COMMIT;

         psql := 'SELECT COUNT(*) '
              || 'FROM ' || p_namestub || '_seeds a '
              || 'WHERE '
              || 'a.project_name = :p1 AND '
              || 'a.layer_name = :p2 ';

         EXECUTE IMMEDIATE psql INTO kount USING params.project_name,
                                                 params.layer_name;

         IF kount <> 8
         THEN

            --cant continue
            output := output || 'FAIL ' || CHR(10);

         ELSE

            --interrogate specific expected results in the seed calls

            psql := 'SELECT COUNT(*) '
                 || 'FROM ' || p_namestub || '_seeds a '
                 || 'WHERE '
                 || 'a.project_name = :p1 AND '
                 || 'a.layer_name = :p2 AND '
                 || 'REGEXP_LIKE(a.coords, :p3)';


            EXECUTE IMMEDIATE psql INTO kount USING params.project_name,
                                                    params.layer_name,
                                                    coordregexp;

            IF kount <> 8
            THEN

               failflag := 1;
               output := output || 'FAIL ' || coordregexp ||
                                   ' not REGEXP_LIKEd in seedcalls ' || CHR(10);

            END IF;

            -- validate that x,y strings can be reconsitituted
            -- into valid and reasonable geoms

            --get the entire extent of all input geoms
            psql := 'SELECT SDO_AGGR_MBR(mbrs.shape) '
                 || 'FROM ('
                 || 'SELECT SDO_AGGR_MBR(a.shape) shape '
                 || 'FROM ' || params.table1 || ' a '
                 || 'UNION ALL '
                 || 'SELECT SDO_AGGR_MBR(b.shape) shape '
                 || 'FROM ' || params.table2 || ' b '
                 || ') mbrs ';

            EXECUTE IMMEDIATE psql INTO extentmbr;

            --get all the x1,y1,x2,y2
            --stripping off equals and spaces
            psql := 'SELECT a.coords '
                 || 'FROM ' || p_namestub || '_seeds a '
                 || 'WHERE '
                 || 'a.project_name = :p1 AND '
                 || 'a.layer_name = :p2 ';

            EXECUTE IMMEDIATE psql
                    BULK COLLECT INTO xystrings
                                      USING params.project_name,
                                            params.layer_name;

            FOR i IN 1 .. xystrings.COUNT
            LOOP

               coordarray := TEST_TILEREFRESH.split(xystrings(i),',');

               ageom := SDO_GEOMETRY
                           (2003,
                            params.srid,
                            NULL,
                            SDO_ELEM_INFO_ARRAY(1,1003,3),  --3 for optimized rectangle
                            MDSYS.SDO_ORDINATE_ARRAY(
                               TO_NUMBER(coordarray(1)),
                               TO_NUMBER(coordarray(2)),
                               TO_NUMBER(coordarray(3)),
                               TO_NUMBER(coordarray(4))
                        ));

               IF sdo_geom.validate_geometry_with_context(ageom, .0005) <> 'TRUE'
               THEN

                  failflag := 1;
                  --this one is 2263 - tolerance is in meters
                  output := output || 'FAIL ' || xystrings(i) || ' is not a valid rectangle ' || CHR(10);

               ELSIF sdo_geom.relate(extentmbr, 'determine', ageom, .0005) NOT IN ('COVERS',
                                                                                   'CONTAINS')
               THEN

                  --dbms_output.put_line(sdo_geom.relate(extentmbr, 'determine', ageom, .0005));
                  failflag := 1;
                  output := output || 'FAIL ' || xystrings(i) ||
                                      ' is not within the extent of the project layers ' || CHR(10);

               ELSIF i = xystrings.COUNT
               AND failflag = 0
               THEN

                  --we made it!
                  output := output || 'PASS ' || CHR(10);

               END IF;

            END LOOP;

         END IF;

      END IF;

      --table2 and table3 are different
      --AND we want output mbrs in web mercator
      params := TILEREFRESH.GET_TRPARAMS('TESTDIFFSRID',
                                         'TEST_SDO',
                                         p_namestub || '_PARAMS');

      IF p_testregimen = 'ALL'
      OR p_testregimen = 'E'
      THEN

         failflag := 0;

         output := output || 'TESTE DUMPCALLS of a reprojection: ';

         --returns the full seed call for each diff
         -- not messing with URI or username
         psql := 'CALL tilerefresh.DUMPCALLS(:p1,:p2,:p3,:p4,:p5,:p6) ';

         EXECUTE IMMEDIATE psql USING params.project_name,
                                      params.layer_name,
                                      p_namestub || '_PARAMS',   --last two only
                                      p_namestub || '_SEEDSSEQ', --need for test
                                      .0001,
                                      p_namestub || '3857_SEEDS';

         COMMIT;

         psql := 'SELECT COUNT(*) '
              || 'FROM ' || p_namestub || '3857_seeds a '
              || 'WHERE '
              || 'a.project_name = :p1 AND '
              || 'a.layer_name = :p2 ';

         EXECUTE IMMEDIATE psql INTO kount USING params.project_name,
                                                 params.layer_name;

         IF kount <> 8
         THEN

            --cant continue
            output := output || 'FAIL ' || CHR(10);

         ELSE

            --interrogate seed calls for x1,y1,x2,y2

            psql := 'SELECT COUNT(*) '
                 || 'FROM ' || p_namestub || '3857_seeds a '
                 || 'WHERE '
                 || 'a.project_name = :p1 AND '
                 || 'a.layer_name = :p2 AND '
                 || 'REGEXP_LIKE(a.coords, :p3)';

            --see declarations at top for coordregexp

            EXECUTE IMMEDIATE psql INTO kount USING params.project_name,
                                                    params.layer_name,
                                                    coordregexp;

            IF kount <> 8
            THEN

               failflag := 1;
               output := output || 'FAIL ' || coordregexp ||
                                   ' not REGEXP_LIKEd in seedcalls ' || CHR(10);

            END IF;

            -- validate that x,y strings can be reconsitituted
            -- into valid and reasonable geoms

            --get the entire extent of all input geoms
            --transorm to web mercator
            psql := 'SELECT SDO_CS.TRANSFORM(SDO_AGGR_MBR(mbrs.shape), :p1) '
                 || 'FROM ('
                 || 'SELECT SDO_AGGR_MBR(a.shape) shape '
                 || 'FROM ' || params.table1 || ' a '
                 || 'UNION ALL '
                 || 'SELECT SDO_AGGR_MBR(b.shape) shape '
                 || 'FROM ' || params.table2 || ' b '
                 || ') mbrs ';

            EXECUTE IMMEDIATE psql INTO extentmbr USING params.srid;

            --get all the x1,y1,x2,y2
            --stripping off equals and spaces
            psql := 'SELECT a.coords '
                 || 'FROM ' || p_namestub || '3857_seeds a '
                 || 'WHERE '
                 || 'a.project_name = :p4 AND '
                 || 'a.layer_name = :p5 ';

            EXECUTE IMMEDIATE psql
                    BULK COLLECT INTO xystrings
                                      USING params.project_name,
                                            params.layer_name;

            FOR i IN 1 .. xystrings.COUNT
            LOOP

               coordarray := TEST_TILEREFRESH.split(xystrings(i),',');

               ageom := SDO_GEOMETRY
                           (2003,
                            params.srid,
                            NULL,
                            SDO_ELEM_INFO_ARRAY(1,1003,3),  --3 for optimized rectangle
                            MDSYS.SDO_ORDINATE_ARRAY(
                               TO_NUMBER(coordarray(1)),
                               TO_NUMBER(coordarray(2)),
                               TO_NUMBER(coordarray(3)),
                               TO_NUMBER(coordarray(4))
                        ));

               IF sdo_geom.validate_geometry_with_context(ageom, .0001) <> 'TRUE'
               THEN

                  --meters, go with roughly 1/3 tolerance
                  failflag := 1;
                  output := output || 'FAIL ' || xystrings(i) || ' is not a valid rectangle ' || CHR(10);

               ELSIF sdo_geom.relate(extentmbr,
                                     'determine',
                                     ageom,
                                     .05) NOT IN ('COVERS', 'CONTAINS')
               THEN

                  -- .05 tolerance since reprojection can cause some sub-meter sloppiness
                  -- (ring ring. Do I hear the CLUEPHONE?)

                  failflag := 1;
                  output := output || 'FAIL ' || xystrings(i) ||
                                      ' is not within the extent of the project layers ' || CHR(10);

               ELSIF i = xystrings.COUNT
               AND failflag = 0
               THEN

                  --we made it again!
                  output := output || 'PASS ' || CHR(10);

               END IF;

            END LOOP;

         END IF;

      END IF;

      --table4 and table5 are lines and are different
      --and we want output mbrs in web mercator and we want some respect
      params := TILEREFRESH.GET_TRPARAMS('TESTLINES',
                                         'TEST_SDO',
                                         p_namestub || '_PARAMS');

      IF p_testregimen = 'ALL'
      OR p_testregimen = 'F'
      THEN

         failflag := 0;

         output := output || 'TESTF DUMPCALLS of reprojected lines: ';

         --returns the full seed call for each diff
         -- not messing with URI or username
         psql := 'CALL tilerefresh.DUMPCALLS(:p1,:p2,:p3,:p4,:p5,:p6) ';

         EXECUTE IMMEDIATE psql USING params.project_name,
                                      params.layer_name,
                                      p_namestub || '_PARAMS',   --last two only
                                      p_namestub || '_SEEDSSEQ', --need for test
                                      .0001,
                                      p_namestub || '3857_SEEDS';

         COMMIT;

         psql := 'SELECT COUNT(*) '
              || 'FROM ' || p_namestub || '3857_seeds a '
              || 'WHERE '
              || 'a.project_name = :p1 AND '
              || 'a.layer_name = :p2 ';

         EXECUTE IMMEDIATE psql INTO kount USING params.project_name,
                                                 params.layer_name;

         IF kount <> 8
         THEN

            --cant continue
            output := output || 'FAIL ' || CHR(10);

         ELSE

            --interrogate seed calls for x1,y1,x2,y2

            psql := 'SELECT COUNT(*) '
                 || 'FROM ' || p_namestub || '3857_seeds a '
                 || 'WHERE '
                 || 'a.project_name = :p1 AND '
                 || 'a.layer_name = :p2 AND '
                 || 'REGEXP_LIKE(a.coords, :p3)';

            --see declarations at top for coordregexp

            EXECUTE IMMEDIATE psql INTO kount USING params.project_name,
                                                    params.layer_name,
                                                    coordregexp;

            IF kount <> 8
            THEN

               failflag := 1;
               output := output || 'FAIL ' || coordregexp ||
                                   ' not REGEXP_LIKEd in seedcalls ' || CHR(10);

            END IF;

            -- validate that x,y strings can be reconsitituted
            -- into valid and reasonable geoms

            --get the entire extent of all input geoms
            --transorm to web mercator
            psql := 'SELECT SDO_CS.TRANSFORM(SDO_AGGR_MBR(mbrs.shape), :p1) '
                 || 'FROM ('
                 || 'SELECT SDO_AGGR_MBR(a.shape) shape '
                 || 'FROM ' || params.table1 || ' a '
                 || 'UNION ALL '
                 || 'SELECT SDO_AGGR_MBR(b.shape) shape '
                 || 'FROM ' || params.table2 || ' b '
                 || ') mbrs ';

            EXECUTE IMMEDIATE psql INTO extentmbr USING params.srid;

            --get all the x1,y1,x2,y2
            --stripping off equals and spaces
            psql := 'SELECT a.coords '
                 || 'FROM ' || p_namestub || '3857_seeds a '
                 || 'WHERE '
                 || 'a.project_name = :p4 AND '
                 || 'a.layer_name = :p5 ';

            EXECUTE IMMEDIATE psql
                    BULK COLLECT INTO xystrings
                                      USING
                                      params.project_name,
                                      params.layer_name;

            FOR i IN 1 .. xystrings.COUNT
            LOOP

               coordarray := TEST_TILEREFRESH.split(xystrings(i),',');

               ageom := SDO_GEOMETRY
                           (2003,
                            params.srid,
                            NULL,
                            SDO_ELEM_INFO_ARRAY(1,1003,3),  --3 for optimized rectangle
                            MDSYS.SDO_ORDINATE_ARRAY(
                               TO_NUMBER(coordarray(1)),
                               TO_NUMBER(coordarray(2)),
                               TO_NUMBER(coordarray(3)),
                               TO_NUMBER(coordarray(4))
                        ));

               IF sdo_geom.validate_geometry_with_context(ageom, .0001) <> 'TRUE'
               THEN

                  --meters tolerance
                  failflag := 1;
                  output := output || 'FAIL ' || xystrings(i) || ' is not a valid rectangle ' || CHR(10);

               ELSIF sdo_geom.relate(extentmbr,
                                     'determine',
                                     ageom,
                                     .05) NOT IN ('COVERS', 'CONTAINS', 'OVERLAPBDYINTERSECT')
               THEN

                  -- add overlapbdyintersect since MBRs of vertical and horizontal lines
                  -- will be automatically widened by SDO_GEOM.sdo_mbr to be valid
                  -- .05 tolerance since reprojection can cause some sub-meter sloppiness
                  -- (ring ring. Do I hear the CLUEPHONE?)

                  failflag := 1;
                  output := output || 'FAIL ' || xystrings(i) ||
                                      ' is not within the extent of the project layers ' || CHR(10);

               ELSIF i = xystrings.COUNT
               AND failflag = 0
               THEN

                  --we made it again!
                  output := output || 'PASS ' || CHR(10);

               END IF;

            END LOOP;

         END IF;

      END IF;

      --table5 and table6 are lines and points and are different
      --and we want output mbrs in web mercator
      
      params := TILEREFRESH.GET_TRPARAMS('TESTPOINTS',
                                         'TEST_SDO',
                                         p_namestub || '_PARAMS');

      IF p_testregimen = 'ALL'
      OR p_testregimen = 'G'
      THEN

         failflag := 0;

         output := output || 'TESTG DUMPDIFFS of reprojected points: ';

         --returns the full seed call for each diff
         -- not messing with URI or username
         psql := 'CALL tilerefresh.DUMPCALLS(:p1,:p2,:p3,:p4,:p5,:p6) ';

         EXECUTE IMMEDIATE psql USING params.project_name,
                                      params.layer_name,
                                      p_namestub || '_PARAMS',   --last two only
                                      p_namestub || '_SEEDSSEQ', --need for test;
                                      .0001,
                                      p_namestub || '3857_SEEDS';

         COMMIT;

         psql := 'SELECT COUNT(*) '
              || 'FROM ' || p_namestub || '3857_seeds a '
              || 'WHERE '
              || 'a.project_name = :p1 AND '
              || 'a.layer_name = :p2 ';

         EXECUTE IMMEDIATE psql INTO kount USING params.project_name,
                                                 params.layer_name;

         IF kount <> 9
         THEN

            --cant continue
            output := output || 'FAIL ' || CHR(10);

         ELSE

            --interrogate seed calls for x1,y1,x2,y2

            psql := 'SELECT COUNT(*) '
                 || 'FROM ' || p_namestub || '3857_seeds a '
                 || 'WHERE '
                 || 'a.project_name = :p1 AND '
                 || 'a.layer_name = :p2 AND '
                 || 'REGEXP_LIKE(a.coords, :p3)';

            --see declarations at top for coordregexp

            EXECUTE IMMEDIATE psql INTO kount USING params.project_name,
                                                    params.layer_name,
                                                    coordregexp;

            IF kount <> 9
            THEN

               failflag := 1;
               output := output || 'FAIL ' || coordregexp ||
                                   ' not REGEXP_LIKEd in seedcalls ' || CHR(10);

            END IF;

            -- validate that x,y strings can be reconsitituted
            -- into valid and reasonable geoms

            --get the entire extent of all input geoms
            --transorm to web mercator
            psql := 'SELECT SDO_CS.TRANSFORM(SDO_AGGR_MBR(mbrs.shape), :p1) '
                 || 'FROM ('
                 || 'SELECT SDO_AGGR_MBR(a.shape) shape '
                 || 'FROM ' || params.table1 || ' a '
                 || 'UNION ALL '
                 || 'SELECT SDO_AGGR_MBR(b.shape) shape '
                 || 'FROM ' || params.table2 || ' b '
                 || ') mbrs ';

            EXECUTE IMMEDIATE psql INTO extentmbr USING params.srid;

            --get all the x1,y1,x2,y2
            --stripping off equals and spaces
            psql := 'SELECT a.coords '
                 || 'FROM ' || p_namestub || '3857_seeds a '
                 || 'WHERE '
                 || 'a.project_name = :p1 AND '
                 || 'a.layer_name = :p2 ';

            EXECUTE IMMEDIATE psql
                    BULK COLLECT INTO xystrings
                                      USING
                                      params.project_name,
                                      params.layer_name;

            FOR i IN 1 .. xystrings.COUNT
            LOOP

               coordarray := TEST_TILEREFRESH.split(xystrings(i),',');

               ageom := SDO_GEOMETRY
                           (2003,
                            params.srid,
                            NULL,
                            SDO_ELEM_INFO_ARRAY(1,1003,3),  --3 for optimized rectangle
                            MDSYS.SDO_ORDINATE_ARRAY(
                               TO_NUMBER(coordarray(1)),
                               TO_NUMBER(coordarray(2)),
                               TO_NUMBER(coordarray(3)),
                               TO_NUMBER(coordarray(4))
                        ));

               IF sdo_geom.validate_geometry_with_context(ageom, .0001) <> 'TRUE'
               THEN

                  --meters tolerance
                  failflag := 1;
                  output := output || 'FAIL ' || xystrings(i) || ' is not a valid rectangle ' || CHR(10);

               ELSIF sdo_geom.relate(extentmbr,
                                     'determine',
                                     ageom,
                                     .05) NOT IN ('COVERS','CONTAINS','OVERLAPBDYINTERSECT')
               THEN

                  -- .05 tolerance since reprojection can cause some sub-meter sloppiness
                  -- (ring ring. Do I hear the CLUEPHONE?)
                  -- we will be back
                  -- dbms_output.put_line(sdo_geom.relate(extentmbr,'determine',ageom,.05));

                  failflag := 1;
                  output := output || 'FAIL ' || xystrings(i) ||
                                      ' is not within the extent of the project layers ' || CHR(10);

               ELSIF i = xystrings.COUNT
               AND failflag = 0
               THEN

                  --we made it again!
                  output := output || 'PASS ' || CHR(10);

               END IF;

            END LOOP;

         END IF;

      END IF;

      --back to tables 2 and 3
      --restrict columns of interest, getting fewer differences
      params := TILEREFRESH.GET_TRPARAMS('TESTCOLS',
                                         'TEST_SDO',
                                         p_namestub || '_PARAMS');

      IF p_testregimen = 'ALL'
      OR p_testregimen = 'H'
      THEN

         output := output || 'TESTH DUMPCALLS of restricted columns: ';


         -- returns the full seed call for each diff
         psql := 'CALL tilerefresh.DUMPCALLS(:p1,:p2,:p3,:p4,:p5,:p6) ';

         EXECUTE IMMEDIATE psql USING params.project_name,
                                      params.layer_name,
                                      p_namestub || '_PARAMS',   --last two only
                                      p_namestub || '_SEEDSSEQ', --need for test
                                      .0005,
                                      p_namestub || '_SEEDS';

         COMMIT;

         --just do basic check of counts, not the rest

         psql := 'SELECT COUNT(*) '
              || 'FROM ' || p_namestub || '_seeds a '
              || 'WHERE '
              || 'a.project_name = :p1 AND '
              || 'a.layer_name = :p2 ';

         EXECUTE IMMEDIATE psql INTO kount USING params.project_name,
                                                 params.layer_name;

         IF kount <> 6
         THEN

            --cant continue
            output := output || 'FAIL ' || CHR(10);

         ELSE

            output := output || 'PASS ' || CHR(10);

         END IF;

      END IF;

      RETURN output;

   END UNITTESTS;


   PROCEDURE TEARDOWN_FIXTURES (
       p_namestub    IN VARCHAR2 DEFAULT 'TEST_TILEREFRESH'
   )
   AS

      psql       VARCHAR2(4000);

   BEGIN

      BEGIN
         psql := 'DROP TABLE ' || p_namestub || '_PARAMS';
         EXECUTE IMMEDIATE psql;
      EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
      END;

      BEGIN
         --wrapped to include sequence
         TILEREFRESH.DROP_TRSEEDS(p_namestub || '_SEEDS');
      EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
      END;
      
      BEGIN
         --wrapped to include sequence
         TILEREFRESH.DROP_TRSEEDS(p_namestub || '3857_SEEDS');
      EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
      END;

      BEGIN
         TEST_GISLAYER.TEARDOWN_FIXTURES();
      EXCEPTION
      WHEN OTHERS
      THEN
         NULL;
      END;

   END TEARDOWN_FIXTURES;


   FUNCTION RUN_TESTS (
      p_namestub     IN VARCHAR2 DEFAULT 'TEST_TILEREFRESH',
      p_teardown     IN VARCHAR2 DEFAULT 'Y'
   ) RETURN VARCHAR2
   AS

      output VARCHAR2(8000);

   BEGIN

      TEST_TILEREFRESH.CREATE_FIXTURES(p_namestub);

      BEGIN
         output := TEST_TILEREFRESH.UNITTESTS('ALL',
                                              p_namestub);
      EXCEPTION
      WHEN OTHERS
      THEN

         output := 'FAIL.  Tests bombed without reporting details:  '
                   || SQLERRM || ' '|| dbms_utility.format_error_backtrace;

      END;

      IF UPPER(p_teardown) = 'Y'
      THEN

         TEST_TILEREFRESH.TEARDOWN_FIXTURES(p_namestub);

      END IF;

      RETURN output;

   END RUN_TESTS;



END TEST_TILEREFRESH;
/