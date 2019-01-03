CREATE OR REPLACE
TYPE BODY GisLayer
AS

   --mschell! 20170524
   --SELECT GisLayer('BUILDING_SDO_2263_1',
   --                'objectid',
   --                'doitt_id').describe() FROM dual
   --lname: BUILDING_SDO_2263_1
   --synthkey: OBJECTID
   --businesskey: DOITT_ID
   --shapecol: SHAPE
   --lcolumns: OBJECTID,NAME,BIN,BBL,CONSTRUCTION_YEAR,GEOM_SOURCE,...
   --
   --subtract layer j from layer i
   --
   --declare
   --   tablei GisLayer;
   --   tablej GisLayer;
   --   diffids MDSYS.sdo_list_type := MDSYS.sdo_list_type();
   --begin
   --   tablei := GisLayer('BUILDING_SDO_2263_1', 'objectid', 'doitt_id');
   --   tablej := GisLayer('BUILDING_SDO_2263_2', 'objectid', 'doitt_id');
   --   diffids := tablei.LDiff(tablej);
   --end;


   ----------------------------------------------------------------------------
   ----------------------------------------------------------------------------
   --Default constructor

   CONSTRUCTOR FUNCTION GisLayer
   RETURN SELF AS RESULT
   AS
   BEGIN

      RETURN;

   END GisLayer;

   ----------------------------------------------------------------------------
   ----------------------------------------------------------------------------

   CONSTRUCTOR FUNCTION GisLayer (
      p_lname            IN VARCHAR2,
      p_lsynthkey        IN VARCHAR2,
      p_lbusinesskey     IN VARCHAR2
   ) RETURN SELF AS RESULT
   AS

      psql              VARCHAR2(4000);

   BEGIN

      self.lname :=  UPPER(p_lname);
      self.lsynthkey := UPPER(p_lsynthkey);
      self.lbusinesskey :=  UPPER(p_lbusinesskey);

      --columns that arent business id or synthetic key or shape
      self.SetLcolumns();

      self.SetLshapecol();
      self.SetLtolerance();

      RETURN;

   END GisLayer;

   ----------------------------------------------------------------------------
   ----------------------------------------------------------------------------

   MEMBER FUNCTION GetLname
   RETURN VARCHAR2
   AS

   BEGIN

     RETURN self.lname;

   END GetLname;

   ----------------------------------------------------------------------------
   ----------------------------------------------------------------------------

   MEMBER FUNCTION GetLsynthkey
   RETURN VARCHAR2
   AS

   BEGIN

     RETURN self.lsynthkey;

   END GetLSynthkey;


   ----------------------------------------------------------------------------
   ----------------------------------------------------------------------------

   MEMBER FUNCTION GetLbusinesskey
   RETURN VARCHAR2
   AS

   BEGIN

     RETURN self.lbusinesskey;

   END GetLbusinesskey;

   ----------------------------------------------------------------------------
   ----------------------------------------------------------------------------

   MEMBER FUNCTION GetLshapecol
   RETURN VARCHAR2
   AS

   BEGIN

      RETURN self.lshapecol;

   END GetLshapecol;

   MEMBER FUNCTION GetLcolumns (
      p_selectedcols    IN MDSYS.stringlist DEFAULT NULL
   ) RETURN MDSYS.stringlist
   AS

      psql              VARCHAR2(4000);
      selectedcols      MDSYS.stringlist := MDSYS.stringlist();

   BEGIN

      IF p_selectedcols IS NULL
      THEN

         RETURN self.lcolumns;

      ELSE

         psql := 'SELECT a.column_name '
              || 'FROM user_tab_cols a '
              || 'WHERE '
              || 'a.table_name = :p1 AND '
              || 'a.column_name IN (SELECT * FROM TABLE(:p2)) ';

         EXECUTE IMMEDIATE psql BULK COLLECT INTO selectedcols USING self.GetLname(),
                                                                     p_selectedcols;

         RETURN selectedcols;

      END IF;

   END GetLcolumns;

   MEMBER FUNCTION GetLcolumnsstring (
      p_separator       IN VARCHAR2 DEFAULT ','
   ) RETURN VARCHAR2
   AS

      output            VARCHAR2(8000) := '';

   BEGIN

      FOR i IN 1 .. self.lcolumns.COUNT
      LOOP

         output := output || self.lcolumns(i);

         IF i <> self.lcolumns.COUNT
         THEN
            output := output || p_separator;
         END IF;

      END LOOP;

      RETURN output;

   END GetLcolumnsstring;


   MEMBER FUNCTION GetLtolerance
   RETURN NUMBER
   AS

   BEGIN

      RETURN self.ltolerance;

   END GetLtolerance;

   MEMBER FUNCTION LDiff (
      p_GisLayer     IN GisLayer,
      p_Lcolumns     IN VARCHAR2 DEFAULT NULL
   ) RETURN MDSYS.stringlist
   AS

      --aka MINUS
      --LayerB diff LayerA will return
      --all LayerB records without a match in LayerA
      --
      --or in standard usage where layerB is an edited, future version of LayerA
      --B.diff(A) => Records in latest dataset that are new or edited
      --A.diff(B) => Records in old dataset that have been deleted or edited
      --
      --Reminder: Symmetric Difference (the tile refresh goal) is
      --A.diff(B) UNION B.diff(A)

      --optional p_Lcolumns is a comma-delimited list
      --in cases where only some columns are of interest

      psql           VARCHAR2(32000);
      psql2          VARCHAR2(4000);
      output         MDSYS.stringlist := MDSYS.stringlist();
      missingcols    MDSYS.stringlist := MDSYS.stringlist();
      missingcolst   VARCHAR2(4000);
      selfcols       MDSYS.stringlist := MDSYS.stringlist();

   BEGIN

      IF self.GetLbusinesskey() <> p_GisLayer.GetLBusinesskey()
      THEN
         --this might be OK.  doittid1 and doittid2 or something
         --but for now will disallow it
         RAISE_APPLICATION_ERROR(-20001, 'Different business keys: '
                                      || self.GetLbusinesskey() || ' - '
                                      || p_GisLayer.GetLBusinesskey() );
      END IF;


      IF p_Lcolumns IS NULL
      THEN

         --pull all relevant columns into local variable for looping
         selfcols := self.GetLcolumns();

      ELSE

         --split on commas, get selected columns only

         psql2 := 'SELECT '
               || 'REPLACE(UPPER(REGEXP_SUBSTR(:p1, :p2, :p3, LEVEL)), :p4, :p5) AS cols '
               || 'FROM dual '
               || 'CONNECT BY REGEXP_SUBSTR(:p6, :p7, :p8, LEVEL) IS NOT NULL ';

         EXECUTE IMMEDIATE psql2 BULK COLLECT INTO selfcols USING p_Lcolumns,
                                                                  '[^,]+',
                                                                  1,
                                                                  ' ',
                                                                  '',
                                                                  p_Lcolumns,
                                                                  '[^,]+',
                                                                  1;

      END IF;

      --self layer - other layer
      --other layer should have all cols in self layer
      --Could be a superset in other, but no symmetric difference in that case

      psql := 'SELECT * FROM TABLE(:p1) '
           || 'MINUS '
           || 'SELECT * FROM TABLE(:p2) ';

      EXECUTE IMMEDIATE psql BULK COLLECT INTO missingcols USING
                                                           selfcols,
                                                           p_GisLayer.GetLcolumns(selfcols);

      IF missingcols.COUNT > 0
      THEN

         FOR i IN 1 .. missingcols.COUNT
         LOOP

            missingcolst := missingcolst || missingcols(i) || ',';

         END LOOP;

         RAISE_APPLICATION_ERROR(-20001, p_GisLayer.GetLname() || ' is missing columns ('
                                      || missingcolst || ') that exist in '
                                      || self.GetLname());

      END IF;

      psql := 'SELECT a.' || self.GetLbusinesskey() || ' '
           || 'FROM ' || self.GetLname() || ' a '
           || 'MINUS '
           || 'SELECT ' || p_GisLayer.GetLBusinesskey() || ' '
           || 'FROM ' || p_GisLayer.GetLname() || ' b '
           || 'UNION ALL '
           || 'SELECT a.' || self.GetLbusinesskey() || ' '
           || 'FROM ' || self.GetLname() || ' a '
           || 'JOIN ' || p_GisLayer.GetLname() || ' b ON '
           || 'a.' || self.GetLbusinesskey() || ' = b.' || p_GisLayer.GetLBusinesskey() || ' '
           || 'WHERE ';

      FOR i IN 1 .. selfcols.COUNT
      LOOP

         psql :=
         psql || '( '
              || 'a.' || selfcols(i) || ' <> b.' || selfcols(i) || ' OR '
              || '(a.' || selfcols(i) || ' IS NULL AND b.' || selfcols(i) || ' IS NOT NULL) OR '
              || '(a.' || selfcols(i) || ' IS NOT NULL AND b.' || selfcols(i) || ' IS NULL) '
              || ') OR ';

      END LOOP;

      psql :=
      psql || '(sdo_geom.relate(a.' || self.GetLshapecol() || ', '
           || ':p1, '
           || 'b.' || p_GisLayer.GetLshapecol() || ', '
           || ':p2) = :p3 '
           || ' OR a.shape IS NULL and b.shape IS NOT NULL '
           || ' OR a.shape IS NOT NULL and b.shape IS NULL) ';

      --a snipped example.  Yes I will leave all this here for me to ogle later (thanks)
      --SELECT a.DOITT_ID
      --  FROM BUILDING_SDO_2263_1 a
      --MINUS
      --SELECT DOITT_ID
      --  FROM BUILDING_SDO_2263_2 b
      --UNION ALL
      --SELECT a.DOITT_ID
      --  FROM BUILDING_SDO_2263_1 a
      --       JOIN BUILDING_SDO_2263_2 b ON a.DOITT_ID = b.DOITT_ID
      -- WHERE    (   a.NAME <> b.NAME
      --           OR (a.NAME IS NULL AND b.NAME IS NOT NULL)
      --           OR (a.NAME IS NOT NULL AND b.NAME IS NULL))
      --       OR (   a.BIN <> b.BIN
      --           OR (a.BIN IS NULL AND b.BIN IS NOT NULL)
      --           OR (a.BIN IS NOT NULL AND b.BIN IS NULL))
      --       OR (   a.BBL <> b.BBL
      --           OR (a.BBL IS NULL AND b.BBL IS NOT NULL)
      --           OR (a.BBL IS NOT NULL AND b.BBL IS NULL))
      --       OR (SDO_GEOM.relate (a.SHAPE,'mask=EQUAL',b.SHAPE,.0005) = 'TRUE'
      --            OR a.shape IS NULL and b.shape IS NOT NULL
      --            OR a.shape IS NOT NULL and b.shape IS NULL)

      BEGIN

         --dbms_output.put_line(psql);
         --dbms_output.put_line('using mask=EQUAL,' || self.getLtolerance() || ',FALSE');
         EXECUTE IMMEDIATE psql BULK COLLECT INTO output USING 'mask=EQUAL',
                                                               self.GetLtolerance(),
                                                               'FALSE';

      EXCEPTION
      WHEN OTHERS
      THEN

         raise_application_error(-20001, SQLERRM || ' on ' || psql);

      END;

      RETURN output;

   END LDiff;


   MEMBER FUNCTION LIntersect (
      p_GisLayer     IN GisLayer
   ) RETURN MDSYS.stringlist
   AS

      --LayerA intersect LayerB
      --will return all records that are equal in both layers
      --Reminder: if  A.intersect(B) returns all records in A
      --          and B.intersect(A) returns all records in B
      --          then A = B

      psql           VARCHAR2(32000);
      output         MDSYS.stringlist := MDSYS.stringlist();
      missingcols    MDSYS.stringlist := MDSYS.stringlist();
      selfcols       MDSYS.stringlist := MDSYS.stringlist();

   BEGIN

      IF self.GetLbusinesskey() <> p_GisLayer.GetLBusinesskey()
      THEN
         --this might be OK.  doittid1 and doittid2 or something
         --but for now will disallow it
         RAISE_APPLICATION_ERROR(-20001, 'Different business keys: '
                                      || self.GetLbusinesskey() || ' - '
                                      || p_GisLayer.GetLBusinesskey() );
      END IF;

      --pull into local variable for looping
      selfcols := self.GetLcolumns();

      --self layer x other layer
      --other layer should have all cols in self layer
      --Could be a superset in other

      psql := 'SELECT * FROM TABLE(:p1) '
           || 'MINUS '
           || 'SELECT * FROM TABLE(:p2) ';

      EXECUTE IMMEDIATE psql BULK COLLECT INTO missingcols
                                               USING selfcols,
                                                     p_GisLayer.GetLcolumns();

      IF missingcols.COUNT > 0
      THEN

         RAISE_APPLICATION_ERROR(-20001, p_GisLayer.GetLname() || ' is missing '
                                      || missingcols.COUNT || ' columns that exist in '
                                      || self.GetLname());

      END IF;

      psql := 'SELECT a.' || self.GetLbusinesskey() || ' '
           || 'FROM ' || self.GetLname() || ' a '
           || 'JOIN ' || p_GisLayer.GetLname() || ' b ON '
           || 'a.' || self.GetLbusinesskey() || ' = b.' || p_GisLayer.GetLBusinesskey() || ' '
           || 'WHERE ';

      FOR i IN 1 .. selfcols.COUNT
      LOOP

         psql :=
         psql || '(a.' || selfcols(i) || ' = b.' || selfcols(i) || ' OR '
              || '(a.' || selfcols(i) || ' IS NULL AND b.' || selfcols(i) || ' IS NULL)) '
              || ' AND ';

      END LOOP;

      psql :=
      psql || 'sdo_geom.relate(a.' || self.GetLshapecol() || ', '
           || ':p1, '
           || 'b.' || p_GisLayer.GetLshapecol() || ', '
           || ':p2) <> :p3';

      --a snipped example
      --SELECT a.DOITT_ID
      --FROM BUILDING_SDO_2263_1 a
      --    JOIN BUILDING_SDO_2263_2 b ON a.DOITT_ID = b.DOITT_ID
      --WHERE     (a.NAME = b.NAME OR (a.NAME IS NULL AND b.NAME IS NULL))
      --    AND (a.BIN = b.BIN OR (a.BIN IS NULL AND b.BIN IS NULL))
      --    AND (a.BBL = b.BBL OR (a.BBL IS NULL AND b.BBL IS NULL))
      --    AND SDO_GEOM.relate (a.SHAPE,'mask=EQUAL',b.SHAPE,.0005) <> 'FALSE'

      BEGIN

         --dbms_output.put_line(psql);
         --dbms_output.put_line('using mask=EQUAL,' || self.getLtolerance() || ',FALSE');
         EXECUTE IMMEDIATE psql BULK COLLECT INTO output USING 'mask=EQUAL',
                                                               self.GetLtolerance(),
                                                               'FALSE';

      EXCEPTION
      WHEN OTHERS
      THEN

         RAISE_APPLICATION_ERROR(-20001, SQLERRM || ' on ' || psql);

      END;

      RETURN output;

   END LIntersect;

   ----------------------------------------------------------------------------
   ----------------------------------------------------------------------------

   MEMBER PROCEDURE SetLshapecol (
      p_lshapecol        IN VARCHAR2 DEFAULT NULL
   )
   AS

   BEGIN

      IF p_lshapecol IS NULL
      THEN
         self.lshapecol := 'SHAPE';
      ELSE
         self.lshapecol := UPPER(p_lshapecol);
      END IF;

   END SetLshapecol;


   MEMBER PROCEDURE SetLtolerance (
      p_ltolerance        IN NUMBER DEFAULT NULL
   )
   AS

   BEGIN

      IF p_ltolerance IS NULL
      THEN
         self.ltolerance := .0005;
      ELSE
         self.ltolerance := p_ltolerance;
      END IF;

   END SetLtolerance;

   ----------------------------------------------------------------------------
   ----------------------------------------------------------------------------

   MEMBER PROCEDURE SetLcolumns
   AS

      psql        VARCHAR2(4000);

   BEGIN

      psql := 'SELECT a.column_name '
           || 'FROM user_tab_cols a '
           || 'WHERE '
           || 'a.table_name = :p1 AND '
           || '(a.data_type = :p2 OR a.data_type = :p3 OR '
           || 'a.data_type LIKE :p4 OR a.data_type LIKE :p5) AND '
           || 'a.column_name NOT LIKE :p6 AND '
           || 'a.column_name NOT IN (:p7, :p8) '
           || 'ORDER BY column_id';

      EXECUTE IMMEDIATE psql BULK COLLECT INTO self.lcolumns USING self.lname,
                                                                   'NUMBER',
                                                                   'DATE',
                                                                   '%VARCHAR%',
                                                                   '%INTEGER%',
                                                                   'SYS%',
                                                                   self.lsynthkey,
                                                                   self.lbusinesskey;

      IF self.lcolumns.COUNT = 0
      THEN

         raise_application_error(-20001, 'Didnt get any columns.  Does '
                                      || self.lname || ' exist? ');


      END IF;

   END SetLcolumns;

   ----------------------------------------------------------------------------
   ----------------------------------------------------------------------------

   MEMBER FUNCTION Describe (
      p_indent             IN VARCHAR2 DEFAULT NULL
   ) RETURN VARCHAR2
   AS

      output         VARCHAR2(32000);

   BEGIN

      output := output || p_indent || 'lname: ' || self.GetLname || chr(10);
      output := output || p_indent || 'synthkey: ' || self.GetLsynthkey || chr(10);
      output := output || p_indent || 'businesskey: ' || self.GetLbusinesskey || chr(10);
      output := output || p_indent || 'shapecol: ' || self.GetLshapecol || chr(10);
      output := output || p_indent || 'lcolumns: ' || self.GetLcolumnsstring() || chr(10);

      RETURN output;

   END Describe;

   ----------------------------------------------------------------------------
   ----------------------------------------------------------------------------

   MEMBER PROCEDURE Describe (
      p_indent          IN VARCHAR2 DEFAULT NULL
   ) AS

   BEGIN

      dbms_output.put_line(Describe(p_indent));

   END Describe;

   ----------------------------------------------------------------------------
   ----------------------------------------------------------------------------

END;
/