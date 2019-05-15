CREATE OR REPLACE PACKAGE BODY TILEREFRESH
AS

    PROCEDURE INSERT_SDOGEOM_METADATA (
      p_table_name      IN VARCHAR2,
      p_column_name     IN VARCHAR2,
      p_srid            IN NUMBER,
      p_tolerance       IN NUMBER DEFAULT .0005,
      p_3d              IN VARCHAR2 DEFAULT 'N'
   )
   AS

    psql    VARCHAR2(4000);
    psql2   VARCHAR2(4000);


   BEGIN

      IF p_srid = 41088
      OR p_srid = 2263
      THEN

         --NAD 1983 StatePlane New York Long Island FIPS 3104 Feet
         --aka EPSG 102718 http://epsg.io/102718

         psql := 'INSERT INTO user_sdo_geom_metadata a '
              || '(table_name, column_name, srid, diminfo) '
              || 'VALUES '
              || '(:p1,:p2,:p3, '
              || 'SDO_DIM_ARRAY ('
              || 'MDSYS.SDO_DIM_ELEMENT (''X'', 900000, 1090000, :p4), '
              || 'MDSYS.SDO_DIM_ELEMENT (''Y'', 110000, 295000, :p5)';

         IF UPPER(p_3d) = 'Y'
         THEN

            --according to planimetrics elevation feature class
            --max elevation in NYC is ~1,500 feet
            --min is ~ -16 feet
            --in other words, these values are naive and waiting to be updated by an expert
            psql := psql || ', '
                         || 'MDSYS.SDO_DIM_ELEMENT (''Z'', -100, 2000, ' || p_tolerance || ')';

         END IF;

         psql := psql || ' )) ';

      ELSIF (p_srid = 8265
         OR  p_srid = 4269
         OR  p_srid = 4326)
      AND UPPER(p_3d) = 'N'
      THEN

         --GEODETIC

         psql := 'INSERT INTO user_sdo_geom_metadata a '
              || '(a.table_name, a.column_name, a.srid, a.diminfo) '
              || 'VALUES '
              || '(:p1,:p2,:p3, '
              || 'SDO_DIM_ARRAY (SDO_DIM_ELEMENT (''Longitude'',-180,180,:p4), '
              || 'SDO_DIM_ELEMENT(''Latitude'',-90,90,:p5) ))';

      ELSIF p_srid = 3857
      AND UPPER(p_3d) = 'N'
      THEN

         --Web Mercator
         --Values are lifted directly from bounds on http://epsg.io/3857
         --THE WORLD IS OURS
         --units are meters so caller should not be passing in .0005 as tolerance

         psql := 'INSERT INTO user_sdo_geom_metadata a '
              || '(table_name, column_name, srid, diminfo) '
              || 'VALUES '
              || '(:p1,:p2,:p3, '
              || 'SDO_DIM_ARRAY ('
              || 'MDSYS.SDO_DIM_ELEMENT (''X'', -20026376.39, 20026376.39, :p4), '
              || 'MDSYS.SDO_DIM_ELEMENT (''Y'', -20048966.10, 20048966.10, :p5) ))';


      ELSIF p_srid IS NULL
      AND UPPER(p_3d) = 'N'
      THEN

         --special NULLed out geodetic to cartesian working coordinate system
         --same SQL as geodetic, but separated for obvitude

         psql := 'INSERT INTO user_sdo_geom_metadata a '
              || '(a.table_name, a.column_name, a.srid, a.diminfo) '
              || 'VALUES '
              || '(:p1,:p2,:p3, '
              || 'SDO_DIM_ARRAY (SDO_DIM_ELEMENT (''Longitude'',-180,180,:p4), '
              || 'SDO_DIM_ELEMENT(''Latitude'',-90,90,:p5) ))';


      ELSE

         RAISE_APPLICATION_ERROR(-20001,'Sorry, no one taught me what to do with srid '
                                        || p_srid || ' with 3D = ' || p_3d);

      END IF;

      BEGIN

         --dbms_output.put_line(psql);
         --dbms_output.put_line(p_table_name || ',' || p_column_name || ',' || p_srid ||
                              --',' || p_tolerance || ',' || p_tolerance);

         EXECUTE IMMEDIATE psql USING p_table_name,
                                      p_column_name,
                                      p_srid,
                                      p_tolerance,
                                      p_tolerance;

      EXCEPTION
      WHEN OTHERS
      THEN

         psql2 := 'DELETE FROM user_sdo_geom_metadata a '
               || 'WHERE a.table_name = :p1 '
               || 'AND a.column_name = :p2 ';

         EXECUTE IMMEDIATE psql2 USING p_table_name,
                                       p_column_name;

         EXECUTE IMMEDIATE psql USING p_table_name,
                                      p_column_name,
                                      p_srid,
                                      p_tolerance,
                                      p_tolerance;

      END;

   END INSERT_SDOGEOM_METADATA;

   FUNCTION SPATIAL_INDEX_EXISTS (
      p_table_name         IN VARCHAR2
   ) RETURN BOOLEAN
   AS

      psql        VARCHAR2(4000);
      kount       PLS_INTEGER;

   BEGIN

      IF LENGTH(p_table_name) = 0
      THEN
         RETURN FALSE;
      END IF;

      psql := 'SELECT COUNT(*) '
           || 'FROM user_indexes u '
           || 'WHERE '
           || 'u.table_name = :p1 AND '
           || 'u.index_type = :p2';

      BEGIN

         EXECUTE IMMEDIATE psql INTO kount USING UPPER(p_table_name),
                                                 'DOMAIN';

      EXCEPTION
      WHEN OTHERS THEN

         RAISE_APPLICATION_ERROR(-20001, SQLERRM || ' , '
                                      || dbms_utility.format_error_backtrace);

      END;

      IF kount > 0
      THEN

         RETURN TRUE;

      ELSE

         RETURN FALSE;

      END IF;

   END SPATIAL_INDEX_EXISTS;

   PROCEDURE DROP_SPATIAL_INDEX (
      p_table_name      IN VARCHAR2,
      p_column_name     IN VARCHAR2 DEFAULT 'SHAPE',
      p_metadata        IN VARCHAR2 DEFAULT 'Y'
   )
   AS

      --make user sdo metadata deletion transparently handled

      psql          VARCHAR2(4000);
      sidx_name     VARCHAR2(32);

   BEGIN

      IF UPPER(p_metadata) = 'Y'
      THEN

         --may delete nothing, tis fine
         psql := 'DELETE FROM user_sdo_geom_metadata a '
              || 'WHERE '
              || 'a.table_name = :p1 AND '
              || 'a.column_name = :p2 ';

         EXECUTE IMMEDIATE psql USING UPPER(p_table_name),
                                      UPPER(p_column_name);

         COMMIT;

      END IF;

      psql := 'SELECT u.index_name '
           || 'FROM user_indexes u '
           || 'WHERE '
           || 'u.table_name = :p1 AND '
           || 'u.index_type = :p2';

      BEGIN

         EXECUTE IMMEDIATE psql INTO sidx_name USING UPPER(p_table_name),
                                                     'DOMAIN';

      EXCEPTION
      WHEN OTHERS
      THEN

          RAISE_APPLICATION_ERROR(-20001, SQLERRM || ' on ' || psql || ' USING '
                               || UPPER(p_table_name) || ',' || UPPER(p_column_name)
                               || ',' || 'DOMAIN');

      END;

      psql := 'DROP INDEX ' || sidx_name;

      BEGIN

         EXECUTE IMMEDIATE psql;

      EXCEPTION
      WHEN OTHERS
      THEN

         RAISE_APPLICATION_ERROR(-20001, SQLERRM || ' on ' || psql);

      END;

END DROP_SPATIAL_INDEX;


PROCEDURE ADD_SPATIAL_INDEX (
      p_table_name      IN VARCHAR2,
      p_column_name     IN VARCHAR2,
      p_srid            IN NUMBER,
      p_tolerance       IN NUMBER,
      p_local           IN VARCHAR2 DEFAULT NULL,
      p_parallel        IN NUMBER DEFAULT NULL,
      p_idx_name        IN VARCHAR2 DEFAULT NULL,
      p_3d              IN VARCHAR2 DEFAULT 'N',
      p_depth           IN PLS_INTEGER DEFAULT 1
   )
   AS

       psql          VARCHAR2(4000);
       psql2         VARCHAR2(4000);
       table_name    VARCHAR2(4000) := UPPER(p_table_name);
       column_name   VARCHAR2(4000) := UPPER(p_column_name);
       index_name    VARCHAR2(4000);
       v_3d          VARCHAR2(1) := UPPER(p_3d);

   BEGIN

      IF INSTR(p_table_name,'.') <> 0
      THEN

         RAISE_APPLICATION_ERROR(-20001,'Sorry database hero, I can''t '
                                     || 'index tables in remote schemas like ' || p_table_name);

      END IF;

      IF p_depth > 3
      THEN

         RAISE_APPLICATION_ERROR(-20001, 'Called recursively ' || p_depth || ' '
                                      || 'times attempting to index '
                                      || p_table_name);

      END IF;


      --performs deletes if already existing
      INSERT_SDOGEOM_METADATA(table_name,
                              column_name,
                              p_srid,
                              p_tolerance,
                              v_3d);

      IF p_idx_name IS NULL
      THEN
         index_name := p_table_name || 'SHAIDX';
      ELSE
         index_name := p_idx_name;
      END IF;

      IF length(index_name) > 30
      THEN
         index_name := substr(index_name,1,30);
      END IF;

      psql := 'CREATE INDEX '
           || index_name
           || ' ON ' || table_name || '(' || column_name || ')'
           || ' INDEXTYPE IS MDSYS.SPATIAL_INDEX ';

      --until something changes, we have no need for a true 3D spatial index
      --Adding this cuts off use of lots of non-3D supported operators.  Ex sdo_relate
      --ORA-13243: specified operator is not supported for 3- or higher-dimensional R-tree
      --IF UPPER(p_3d) = 'Y'
      --THEN

         --psql := psql || 'PARAMETERS (''sdo_indx_dims=3'') ';

      --END IF;

      IF p_local IS NOT NULL
      THEN
         psql := psql || 'LOCAL ';
      END IF;

      IF p_parallel IS NOT NULL
      THEN
         psql := psql || 'PARALLEL ' || TO_CHAR(p_parallel) || ' ';
      ELSE
         psql := psql || 'NOPARALLEL ';
      END IF;

      BEGIN

         --dbms_output.put_line(psql);
         EXECUTE IMMEDIATE psql;

      EXCEPTION
      WHEN OTHERS
      THEN

         IF SQLERRM LIKE '%layer dimensionality does not match geometry dimensions%'
         AND v_3d = 'N'
         THEN

            --Most likely 3D data.  Send us a clue to create diff metadata
            v_3d := 'Y';

            --probably created but busted
            IF SPATIAL_INDEX_EXISTS(table_name)
            THEN

               DROP_SPATIAL_INDEX(table_name,
                                  column_name,
                                  'Y'); --kill metadata, we'll try again

            END IF;

         ELSE

            DROP_SPATIAL_INDEX(table_name,
                               column_name,
                               'N'); --already killed and created metadata

         END IF;

         TILEREFRESH.ADD_SPATIAL_INDEX(table_name,
                                       column_name,
                                       p_srid,
                                       p_tolerance,
                                       p_local,
                                       p_parallel,
                                       p_idx_name,
                                       v_3d,
                                       (p_depth + 1));

      END;

   END ADD_SPATIAL_INDEX;


   PROCEDURE CREATE_TRPARAMS (
      p_tabname         IN VARCHAR2 DEFAULT 'TILEREFRESH_PARAMS',
      p_replace         IN VARCHAR2 DEFAULT 'N'
   )
   AS

      --mschell! 20170609
      --input parameters for tile refresh

      psql              VARCHAR2(4000);

   BEGIN

      psql := 'CREATE TABLE ' ||  p_tabname || ' ('
           || 'project_name         VARCHAR2(32), '
           || 'layer_name           VARCHAR2(32), '
           || 'table1               VARCHAR2(32), '
           || 'table2               VARCHAR2(32), '
           || 'synthkey             VARCHAR2(32), '
           || 'businesskey          VARCHAR2(32), '
           || 'srid                 NUMBER, '
           || 'cols                 VARCHAR2(4000), '
           || 'PRIMARY KEY (project_name, layer_name)) ';

      BEGIN

         EXECUTE IMMEDIATE psql;

      EXCEPTION
      WHEN OTHERS
      THEN

         IF SQLCODE = -955
         AND p_replace = 'Y'
         THEN

            EXECUTE IMMEDIATE 'DROP TABLE ' || p_tabname;

            TILEREFRESH.CREATE_TRPARAMS(p_tabname,
                                        'N');

         ELSE

            RAISE_APPLICATION_ERROR(-20001, SQLERRM || 'on ' || psql);

         END IF;

      END;

   END CREATE_TRPARAMS;

   PROCEDURE CREATE_TRSEEDS (
      p_tabname         IN VARCHAR2 DEFAULT 'TILEREFRESH_SEEDS',
      p_replace         IN VARCHAR2 DEFAULT 'N',
      p_srid            IN NUMBER DEFAULT 3857,
      p_tolerance       IN NUMBER DEFAULT .0001
   )
   AS

      --mschell! 20170612
      --output table to record seed calls

      psql              VARCHAR2(4000);

   BEGIN

      psql := 'CREATE TABLE ' ||  p_tabname || ' ('
           || 'seedid               INTEGER PRIMARY KEY, '
           || 'project_name         VARCHAR2(32), '
           || 'layer_name           VARCHAR2(32), '
           || 'shape                SDO_GEOMETRY, '
           || 'coords               VARCHAR2(4000), '
           || 'date_last_modified   DATE '
           || ') ';

      BEGIN

         EXECUTE IMMEDIATE psql;

      EXCEPTION
      WHEN OTHERS
      THEN

         IF SQLCODE = -955
         AND p_replace = 'Y'
         THEN

            TILEREFRESH.DROP_TRSEEDS(p_tabname);

            TILEREFRESH.CREATE_TRSEEDS(p_tabname,
                                       'N',
                                       p_srid,
                                       p_tolerance);

            RETURN;

         ELSE

            RAISE_APPLICATION_ERROR(-20001, SQLERRM || 'on ' || psql);

         END IF;

      END;

      psql := 'CREATE SEQUENCE ' || p_tabname || 'SEQ '
           || 'START WITH 1 INCREMENT BY 1 CACHE 1000 NOCYCLE';

      EXECUTE IMMEDIATE psql;

      psql := 'CREATE OR REPLACE TRIGGER ' || p_tabname || 'TRG '
           || 'BEFORE INSERT OR UPDATE ON ' || p_tabname || ' '
           || 'FOR EACH ROW '
           || 'BEGIN '
           || '   :NEW.date_last_modified := CURRENT_DATE; '
           || 'END; ';

      EXECUTE IMMEDIATE psql;

      TILEREFRESH.add_spatial_index(p_tabname,
                                    'SHAPE',
                                    p_srid,
                                    p_tolerance);

   END CREATE_TRSEEDS;


   PROCEDURE DROP_TRSEEDS (
      p_tabname         IN VARCHAR2 DEFAULT 'TILEREFRESH_SEEDS'
   )
   AS

      --mschell! 20170620
      --becuz sequence

   BEGIN

      EXECUTE IMMEDIATE 'DROP TABLE ' || p_tabname;

      EXECUTE IMMEDIATE 'DROP SEQUENCE ' || p_tabname || 'SEQ ';

   END DROP_TRSEEDS;

--    PROCEDURE TUNE_TRSEEDS (
--        p_tabname        IN VARCHAR DEFAULT 'TILEREFRESH_SEEDS'
--       ,p_srid           IN NUMBER DEFAULT 3857
--       ,p_tolerance      IN NUMBER DEFAULT .0001
--    )
--    AS
--
--        --tilerefresh_seeds becomes fragmented after
--        --   records get dissolved, often several times
--        --intent is to call this from a gradle task
--        --I think this only happens for reals when I blow up something and 
--        -- insert too many rows... revisit if necessary, need to deal with TRG
--        -- 
--
--    BEGIN
--
--        DROP_SPATIAL_INDEX( p_tabname
--                           ,'SHAPE')
--
--        EXECUTE IMMEDIATE 'ALTER TABLE ' || p_tabname || ' ENABLE ROW MOVEMENT';
--
--        EXECUTE IMMEDIATE 'ALTER TABLE ' || p_tabname || ' SHRINK SPACE COMPACT';
--
--        EXECUTE IMMEDIATE 'ALTER TABLE ' || p_tabname || ' SHRINK SPACE';
--
--        TILEREFRESH.add_spatial_index( p_tabname
--                                      ,'SHAPE',
--                                      ,p_srid,
--                                      ,p_tolerance);
--
--        DBMS_STATS.GATHER_TABLE_STATS( ownname => USER
--                                      ,tabname => p_tabname
--                                      ,granularity => 'AUTO'               
--                                      ,degree => 1                         
--                                      ,cascade => DBMS_STATS.AUTO_CASCADE);
--
--    END TUNE_TRSEEDS;


   FUNCTION GET_TRPARAMS (
      p_project_name     IN VARCHAR2,
      p_layer_name      IN VARCHAR2,
      p_tabname         IN VARCHAR2 DEFAULT 'TILEREFRESH_PARAMS'
   ) RETURN TILEREFRESH.TRPARAMS_REC
   AS

      --mschell! 20170612

      psql     VARCHAR2(4000);
      output   TILEREFRESH.TRPARAMS_REC;

   BEGIN

      psql := 'SELECT * FROM ' || p_tabname || ' a '
           || 'WHERE '
           || 'UPPER(a.project_name) = :p1 AND '
           || 'UPPER(a.layer_name) = :p2 ';

      BEGIN

         EXECUTE IMMEDIATE psql INTO output USING UPPER(p_project_name),
                                                  UPPER(p_layer_name);

      EXCEPTION
      WHEN OTHERS
      THEN

          RAISE_APPLICATION_ERROR(-20001, SQLERRM || ' on ' || psql ||
                                          ' using ' ||  UPPER(p_project_name) ||
                                          ',' || UPPER(p_layer_name));

      END;

      RETURN output;

   END GET_TRPARAMS;


    FUNCTION MBRPOINT (
         p_sdo           IN MDSYS.SDO_GEOMETRY
        ,p_bloat         IN NUMBER
    ) RETURN MDSYS.SDO_GEOMETRY
    AS

        -- private
        -- mschell! 201905015 refactoring
    
    BEGIN

        RETURN SDO_GEOMETRY(2003
                           ,p_sdo.sdo_srid
                           ,NULL
                           ,SDO_ELEM_INFO_ARRAY(1,1003,3)
                           ,SDO_ORDINATE_ARRAY(p_sdo.sdo_ordinates(1) - p_bloat
                                              ,p_sdo.sdo_ordinates(2) - p_bloat
                                              ,p_sdo.sdo_ordinates(1) + p_bloat
                                              ,p_sdo.sdo_ordinates(2) + p_bloat)
                            );

    END MBRPOINT;


   FUNCTION DUMPDIFFSSDO (
      p_tab1            IN VARCHAR2
     ,p_tab2            IN VARCHAR2
     ,p_synthkey        IN VARCHAR2
     ,p_businesskey     IN VARCHAR2
     ,p_srid            IN NUMBER DEFAULT 3857
     ,p_tolerance       IN VARCHAR2 DEFAULT .0001
     ,p_cols            IN VARCHAR2 DEFAULT NULL
   ) RETURN TILEREFRESH.MBRSDOTAB PIPELINED
   AS

        --mschell! 20170613

        -- dump diffs sdo kernel
        -- called by dumpdiffs
        -- can also use this one to populate a table with sdo_geometry
        -- for review in QGIS or Arcmap
        -- Executive Summary: Given two spatial tables and some columns that we 
        --                    care about, return MBRs of every location where
        --                    the tables differ

        --select * FROM
        --TABLE(tilerefresh.DUMPDIFFSSDO('BUILDING_SDO_2263_1',
        --                               'BUILDING_SDO_2263_2',
        --                               'objectid',
        --                               'doitt_id',
        --                               3857)) t

        --sample SQL fully expanded and pulled out as x1,y1,x2,y2 looks something like:
        --
        --SELECT sdo_geom.sdo_min_mbr_ordinate(SDO_CS.transform (SDO_GEOM.sdo_mbr (a.shape), 3857),1) || ',' ||
        --         sdo_geom.sdo_min_mbr_ordinate(SDO_CS.transform (SDO_GEOM.sdo_mbr (a.shape), 3857),2) || ',' ||
        --         sdo_geom.sdo_max_mbr_ordinate(SDO_CS.transform (SDO_GEOM.sdo_mbr (a.shape), 3857),1) || ',' ||
        --         sdo_geom.sdo_max_mbr_ordinate(SDO_CS.transform (SDO_GEOM.sdo_mbr (a.shape), 3857),2) coords
        --  FROM BUILDING_SDO_2263_2 a,
        --  TABLE (
        --          SELECT GisLayer ('BUILDING_SDO_2263_2', 'objectid', 'doitt_id').Ldiff (
        --                    GisLayer ('BUILDING_SDO_2263_1', 'objectid', 'doitt_id'))
        --            FROM DUAL) t
        -- WHERE t.COLUMN_VALUE = a.doitt_id
        --UNION ALL -- change to union to remove dupe mbrs
        --  SELECT sdo_geom.sdo_min_mbr_ordinate(SDO_CS.transform (SDO_GEOM.sdo_mbr (a.shape), 3857),1) || ',' ||
        --         sdo_geom.sdo_min_mbr_ordinate(SDO_CS.transform (SDO_GEOM.sdo_mbr (a.shape), 3857),2) || ',' ||
        --         sdo_geom.sdo_max_mbr_ordinate(SDO_CS.transform (SDO_GEOM.sdo_mbr (a.shape), 3857),1) || ',' ||
        --         sdo_geom.sdo_max_mbr_ordinate(SDO_CS.transform (SDO_GEOM.sdo_mbr (a.shape), 3857),2) coords
        --  FROM BUILDING_SDO_2263_1 a,
        --  TABLE (
        --          SELECT GisLayer ('BUILDING_SDO_2263_1', 'objectid', 'doitt_id').Ldiff (
        --                    GisLayer ('BUILDING_SDO_2263_2', 'objectid', 'doitt_id'))
        --            FROM DUAL) t
        -- WHERE t.COLUMN_VALUE = a.doitt_id

        psql1                   VARCHAR2(4000);
        psql2                   VARCHAR2(4000);
        psql3                   VARCHAR2(4000);
        psql1a                  VARCHAR2(4000);
        psql2a                  VARCHAR2(4000);
        fullsql                 VARCHAR2(8000);
        my_cursor               SYS_REFCURSOR;
        array_of_ringarrays     SDO_ARRAY_ARRAY := SDO_ARRAY_ARRAY();
        --TYPE                    SDO_ARRAY_ARRAY IS TABLE OF MDSYS.SDO_GEOMETRY_ARRAY 
        --                        INDEX BY PLS_INTEGER;
        --array_of_ringarrays     SDO_ARRAY_ARRAY;
        somembrs                TILEREFRESH.MBRSDOTAB := TILEREFRESH.MBRSDOTAB();
        verbose                 PLS_INTEGER := 1;
        kount                   PLS_INTEGER := 0;

    BEGIN

        -- not like this.  90% sure
        -- || 'SDO_CS.transform(SDO_GEOM.sdo_mbr(a.shape), :p1) '

        -- I liked this version because only 4 coordinates came back from 
        -- SQL to pl/sql context
        --psql1 := 'SELECT '
        --      || 'SDO_GEOM.sdo_mbr(SDO_CS.transform(a.shape, :p1)) '
        --      || 'FROM '; --tablename a,

        -- But its more important to bust up multipolygons and save cycles on
        -- the tile re-generation calls
        -- I dont think I can work with mdsys.sdo_geometry_array from extract_all
        -- in SQL, gotta pass the geoms back to the cursor then transform and mbr

        psql1 := 'SELECT '
              || 'SDO_UTIL.extract_all(a.shape, :p1) '
              || 'FROM '; --tablename a,

        psql2 := ' a, '
                || 'TABLE( '
                || '     SELECT GisLayer(:p2, :p3, :p4).Ldiff( '
                || '            GisLayer(:p5, :p6, :p7)';

        IF p_cols IS NOT NULL
        THEN

            psql2 := psql2 || ',:p8';

        END IF;

        psql3 := ') '
                || '     FROM DUAL) t '
                || 'WHERE '
                || 't.COLUMN_VALUE = a.' || p_businesskey || ' AND '
                || 'a.shape IS NOT NULL ';

        psql1a := 'SELECT '
              || 'SDO_UTIL.extract_all(a.shape, :p1a) '
              || 'FROM '; --tablename a,

        psql2a := ' a, '
                || 'TABLE( '
                || '     SELECT GisLayer(:p2a, :p3a, :p4a).Ldiff( '
                || '            GisLayer(:p5a, :p6a, :p7a)';

        IF p_cols IS NOT NULL
        THEN

            psql2a := psql2a || ',:p8a';

        END IF;

        fullsql := psql1 || p_tab2 || psql2 || psql3 || 
                   'UNION ALL ' ||
                   psql1a || p_tab1 || psql2a || psql3;

        IF verbose = 1
        THEN
            dbms_output.put_line (fullsql);
            dbms_output.put_line('using');
            dbms_output.put_line(0 || ',' || 
                                 p_tab2 || ',' ||
                                 p_synthkey || ',' || 
                                 p_businesskey || ',' ||
                                 p_tab1 || ',' || 
                                 p_synthkey || ',' || 
                                 p_businesskey || ',' ||
                                 0 || ',' ||
                                 p_tab1 || ',' || 
                                 p_synthkey || ',' || 
                                 p_businesskey || ',' ||
                                 p_tab2 || ',' ||
                                 p_synthkey || ',' ||
                                 p_businesskey);        
        END IF;

        IF p_cols IS NULL
        THEN

            OPEN my_cursor FOR fullsql
                         USING 0,
                               p_tab2, p_synthkey, p_businesskey,
                               p_tab1, p_synthkey, p_businesskey,
                               0,
                               p_tab1, p_synthkey, p_businesskey,
                               p_tab2, p_synthkey, p_businesskey;

        ELSE

            OPEN my_cursor FOR fullsql
                               USING 0,
                               p_tab2, p_synthkey, p_businesskey,
                               p_tab1, p_synthkey, p_businesskey,
                               p_cols,
                               0,
                               p_tab1, p_synthkey, p_businesskey,
                               p_tab2, p_synthkey, p_businesskey,
                               p_cols;

        END IF;

        LOOP

            FETCH my_cursor BULK COLLECT INTO array_of_ringarrays LIMIT 25;

            EXIT WHEN array_of_ringarrays.COUNT = 0;

            FOR i IN 1 .. array_of_ringarrays.COUNT
            LOOP

                FOR jj IN 1 .. array_of_ringarrays(i).COUNT 
                LOOP

                    kount := kount + 1;
                    somembrs.EXTEND(1);

                    IF array_of_ringarrays(i)(jj).sdo_gtype <> 2001
                    THEN

                        somembrs(kount).mbr := SDO_GEOM.sdo_mbr(
                                                    SDO_CS.transform(array_of_ringarrays(i)(jj)
                                                                    ,p_srid)
                                               );

                    ELSE

                        -- mbr of a point is a point, does not work for us
                        -- obvious fix: sdo_geom.sdo_mbr(sdo_geom.sdo_buffer) is too flakey with curves
                        -- make sure to bloat using input tolerance units
                        somembrs(kount).mbr := SDO_GEOM.sdo_mbr(
                                                    SDO_CS.transform(
                                                        MBRPOINT(array_of_ringarrays(i)(jj)
                                                                ,p_tolerance * 2)
                                                   ,p_srid)
                                               );

                    END IF;
                
                    IF somembrs(kount).mbr.get_gtype() = 1
                    THEN

                        -- mbr of a point is a point, does not work for us
                        -- obvious fix: sdo_geom.sdo_mbr(sdo_geom.sdo_buffer) is too flakey with curves
                        somembrs(kount).mbr := MBRPOINT(somembrs(kount).mbr
                                                       ,p_tolerance * 2);

                    END IF;

                END LOOP;

            END LOOP;

            array_of_ringarrays.DELETE;

            FOR i IN 1 .. somembrs.COUNT
            LOOP

                -- pop off son, pop off
                PIPE ROW(somembrs(i));

            END LOOP;

            somembrs.DELETE;

        END LOOP;

      RETURN;

   END DUMPDIFFSSDO;


   PROCEDURE DUMPCALLS (
      p_project_name    IN VARCHAR2,
      p_layer_name      IN VARCHAR2,
      p_params          IN VARCHAR2 DEFAULT 'TILEREFRESH_PARAMS',
      p_sequence        IN VARCHAR2 DEFAULT 'TILEREFRESH_SEEDSSEQ',
      p_tolerance       IN NUMBER DEFAULT .0001,
      p_seedtab         IN VARCHAR2 DEFAULT 'TILEREFRESH_SEEDS'
   )
   AS

     --mschell! 20170609
     --this is a wrapper to push MBRs into a table
     --it wraps DUMPDIFFSSDO which is the core MBR-producing code

     --CALL tilerefresh.DUMPCALLS('BASEMAP',
     --                           'centerline');

     params             TRPARAMS_REC;
     my_cursor          SYS_REFCURSOR;
     psql               VARCHAR2(4000);
     isql               VARCHAR2(4000);
     someids            tilerefresh.stringarray;
     somembrs           MDSYS.SDO_GEOMETRY_ARRAY := MDSYS.SDO_GEOMETRY_ARRAY();

   BEGIN

        params := TILEREFRESH.GET_TRPARAMS(p_project_name,
                                           p_layer_name,
                                           p_params);

        psql := 'SELECT'
             || ' ' || p_sequence || '.NEXTVAL' 
             || ', t.mbr'
             || ' FROM'
             || ' TABLE(tilerefresh.DUMPDIFFSSDO(:p1,:p2,:p3,:p4,:p5,:p6,:p7)) t';

         OPEN my_cursor FOR psql USING params.table1
                                      ,params.table2
                                      ,params.synthkey
                                      ,params.businesskey
                                      ,params.srid
                                      ,p_tolerance
                                      ,params.cols;

        LOOP

            -- rationale for sys_refcursor and commits in chunks of 50:
            -- I was running out of undo on bulk inserts
            -- appears to have been due to flubbed setup inserting hundreds of
            -- thousands of diffs, but Im gonna allow chunked this approach 
            -- to remain

            FETCH my_cursor BULK COLLECT INTO someids
                                             ,somembrs LIMIT 50;

            EXIT WHEN someids.COUNT = 0;

                isql := 'INSERT INTO ' || p_seedtab || ' '
                     || '(seedid, project_name, layer_name, shape) '
                     || 'VALUES '
                     || '(:p1,:p2,:p3,:p4)';

                FORALL ii in 1 .. someids.COUNT
                    EXECUTE IMMEDIATE isql USING someids(ii)
                                                ,params.project_name
                                                ,params.layer_name
                                                ,somembrs(ii);

                COMMIT;

        END LOOP;

      --Above almost always results in overlapping MBRs
      --Next: dissolve all MBRS that are fully contained or fully containing
      --      Columns other than shape are disrespected but at this point are meaningless
      --There will be overlapping MBRS at the conclusion of this call that are
      --   not dissolved.  This is intentional.  The alternative is to allow MBRs
      --   to agglomerate until in many cases until 1 MBR covers the full extent

      TILEREFRESH.DISSOLVETABLE(p_seedtab,
                                'a.project_name = ''' || params.project_name || ''' ' ||
                                'AND a.layer_name = ''' || params.layer_name || '''',
                                'SEEDID', --pkc
                                p_tolerance,
                                'INSIDE+COVEREDBY+CONTAINS+COVERS+EQUAL');

      --update final call with bounding box mbrs

      psql := 'UPDATE ' || p_seedtab || ' t '
           || 'SET '
           || 't.coords = '
           || 'TO_CHAR(sdo_geom.sdo_min_mbr_ordinate(t.shape, :p1)) || '','' || '
           || 'TO_CHAR(sdo_geom.sdo_min_mbr_ordinate(t.shape, :p2)) || '','' || '
           || 'TO_CHAR(sdo_geom.sdo_max_mbr_ordinate(t.shape, :p3)) || '','' || '
           || 'TO_CHAR(sdo_geom.sdo_max_mbr_ordinate(t.shape, :p4)) '
           || 'WHERE '
           || 't.project_name = :p5 AND '
           || 't.layer_name = :p6 ';

      EXECUTE IMMEDIATE psql USING 1,
                                   2,
                                   1,
                                   2,
                                   params.project_name,
                                   params.layer_name;

      COMMIT;

   END DUMPCALLS;

   PROCEDURE DISSOLVETABLE (
      p_target_table    IN VARCHAR2,
      p_target_clause   IN VARCHAR2 DEFAULT NULL,
      p_target_pkc      IN VARCHAR2 DEFAULT 'OBJECTID',
      p_tolerance       IN NUMBER DEFAULT .0005,
      p_mask            IN VARCHAR2 DEFAULT 'ANYINTERACT'
   )
   AS

      --mschell! 20160624

      --All indicated records that are not spatially disjoint (or specified mask)
      --will be combined.
      --Other columns will not be maintained and some records will disappear.
      --For ex
      --If record A dissolves with record B
      --   Record A spatial extent will grow to incorporate B extent
      --   Record A columns other than shape will be untouched
      --   Record B will be deleted.

      TYPE numberarray IS TABLE OF NUMBER
      INDEX BY PLS_INTEGER;
      allobjectids         numberarray;
      seedobjectid         NUMBER;
      bucketobjectids      numberarray;
      processedids         MDSYS.SDO_List_Type := MDSYS.SDO_List_Type();
      psql                 VARCHAR2(4000);
      bucketsql            VARCHAR2(4000);
      workingblob          SDO_GEOMETRY;
      kount                PLS_INTEGER;
      deadman              PLS_INTEGER := 0;
      deadman_switch       PLS_INTEGER := 999999;

   BEGIN

      --get all objectids ordered by complexity
      --all collected to avoid mutation
      psql := 'SELECT a.' || p_target_pkc || ' '
           || 'FROM ' || p_target_table || ' a ';

      IF p_target_clause IS NOT NULL
      THEN

         psql := psql || 'WHERE ' || p_target_clause;

      END IF;

      psql := psql || ' ORDER BY SDO_UTIL.getnumvertices(a.shape) ASC ';

      EXECUTE IMMEDIATE psql BULK COLLECT INTO allobjectids;

      --dbms_output.put_line(psql);
      --dbms_output.put_line('got ' || allobjectids.COUNT);

      FOR i IN 1 .. allobjectids.COUNT
      LOOP

         psql := 'SELECT COUNT(*) FROM TABLE(:p1) t '
              || 'WHERE t.column_value = :p2 ';

         EXECUTE IMMEDIATE psql INTO kount USING processedids,
                                                 allobjectids(i);

         IF kount = 1
         THEN

            --already processed into some other blob, skip
            CONTINUE;

         ELSE

            seedobjectid := allobjectids(i);
            processedids.EXTEND(1);
            processedids(processedids.COUNT) := allobjectids(i);

            psql := 'SELECT a.shape '
                 || 'FROM ' ||  p_target_table || ' a '
                 || 'WHERE a.' || p_target_pkc || ' = :p1 ';

            EXECUTE IMMEDIATE psql INTO workingblob USING seedobjectid;

         END IF;

         --get other objectids spatially related (may be zero)
         --what about touch at a point buster?

         bucketsql := 'SELECT a.' || p_target_pkc || ' '
                   || 'FROM ' || p_target_table || ' a '
                   || 'WHERE '
                   || 'SDO_RELATE(a.shape, :p1, :p2) = :p3 AND '
                   || 'a.' || p_target_pkc || ' <> :p4 '; --dont keep unioning with og seed

         IF p_target_clause IS NOT NULL
         THEN

            bucketsql := bucketsql || 'AND ' || p_target_clause || ' ';

         END IF;

         bucketsql := bucketsql || 'ORDER BY SDO_UTIL.getnumvertices(a.shape) ASC ';

         EXECUTE IMMEDIATE bucketsql BULK COLLECT INTO bucketobjectids USING workingblob,
                                                                             'mask=' || UPPER(p_mask),
                                                                             'TRUE',
                                                                             allobjectids(i);

         WHILE bucketobjectids.COUNT > 0
         LOOP

            FOR jj IN 1 .. bucketobjectids.COUNT
            LOOP

               --union these one by one, and remove unioned recs from the table

               psql := 'SELECT SDO_GEOM.sdo_union(a.shape, :p1, :p2) '
                    || 'FROM ' || p_target_table || ' a '
                    || 'WHERE a.' || p_target_pkc || ' = :p3 ';

               EXECUTE IMMEDIATE psql INTO workingblob USING workingblob,
                                                             p_tolerance,
                                                             bucketobjectids(jj);

               psql := 'DELETE FROM ' || p_target_table || ' a '
                    || 'WHERE a.' || p_target_pkc || ' = :p1 ';

               EXECUTE IMMEDIATE psql USING bucketobjectids(jj);

               --even though deleted from table must save these for skipping
               --in the outer loop
               processedids.EXTEND(1);
               processedids(processedids.COUNT) := bucketobjectids(jj);

            END LOOP;

            --dip back in for another bucket using expanded blob
            EXECUTE IMMEDIATE bucketsql BULK COLLECT INTO bucketobjectids USING workingblob,
                                                                                'mask=' || UPPER(p_mask),
                                                                                'TRUE',
                                                                                allobjectids(i);

            IF deadman < deadman_switch
            THEN

               deadman := deadman + 1;

            ELSE

               RAISE_APPLICATION_ERROR(-20001, 'Deadman switch, looped 1 million times on '
                                               || bucketsql);

            END IF;

         END LOOP;

         --finished growing outward from this original seed
         psql := 'UPDATE ' || p_target_table || ' a '
              || 'SET a.shape = :p1 '
              || 'WHERE a.' || p_target_pkc || ' = :p2 ';

         EXECUTE IMMEDIATE psql USING workingblob,
                                      allobjectids(i);
         COMMIT;

      END LOOP;

   END DISSOLVETABLE;

END TILEREFRESH;
/