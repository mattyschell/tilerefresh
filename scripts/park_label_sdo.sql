--sqlplus basemap/iluvdoitt247@geocdev.doitt.nycnet @scripts/park_label_sdo.sql
DELETE FROM basemap.tilerefresh_params
      WHERE project_name = 'BASEMAP' AND layer_name = 'PARK_LABEL_SDO';
-- this aint it, leaving placeholder reminder for future dumb me
--INSERT INTO basemap.tilerefresh_params (
--                                project_name,
--                                layer_name,
--                                table1,
--                                table2,
--                                synthkey,
--                                businesskey,
--                                srid,
--                                cols)
--     VALUES (  'BASEMAP',
--               'PARK_LABEL_SDO',
--              'PARK_LABEL_SDO_OLD', --temp view rewired to geodatashare.park_sdo_2263_1
--               'PARK_LABEL_SDO',     --current.  points to geodatashare.park_sdo_2263_3
--               'objectid',
--               'parknum',
--               3857,
--               'PARKNUM');
--COMMIT;
--CALL tilerefresh.DUMPCALLS('BASEMAP',
--                           'PARK_LABEL_SDO');
--remove previous seeds if run
DELETE FROM tilerefresh_seeds
      WHERE project_name = 'BASEMAP' AND layer_name = 'PARK_LABEL_SDO';
COMMIT;
-- there is no business key in the old dataset
-- planimetrics divvied up many parks (parknum A###) 
--   into separate records based on some sort of capture rules
-- however unlike park_clp_sdo, which includes all shapes in a park,
--   park_label_sdo (the new) is a single outline for each park
--   and parknum going forward on this layer should be unique
-- since we were already headed toward a total replacement of tiles, (every shape
-- is slightly different) just brute force it all like park_clip_sdo
-- then dissolve back to a more reasonable count
INSERT INTO tilerefresh_seeds 
   (seedid
   ,project_name
   ,layer_name
   ,shape)
SELECT tilerefresh_seedsseq.nextval
      ,'BASEMAP'
      ,'PARK_LABEL_SDO'
      ,SDO_CS.transform(SDO_GEOM.sdo_mbr(a.shape),3857) 
FROM park_label_sdo_old a;
COMMIT;
INSERT INTO tilerefresh_seeds 
   (seedid
   ,project_name
   ,layer_name
   ,shape)
SELECT tilerefresh_seedsseq.nextval
      ,'BASEMAP'
      ,'PARK_LABEL_SDO'
      ,SDO_CS.transform(SDO_GEOM.sdo_mbr(a.shape),3857) 
FROM park_label_sdo a;
COMMIT;
CALL TILEREFRESH.DISSOLVETABLE('TILEREFRESH_SEEDS'
                              ,'a.project_name = ''BASEMAP'' AND a.layer_name = ''PARK_LABEL_SDO'' '
                              ,'SEEDID'
                              ,.0005
                              ,'INSIDE+COVEREDBY+CONTAINS+COVERS+EQUAL');
UPDATE TILEREFRESH_SEEDS t 
SET t.coords = TO_CHAR(sdo_geom.sdo_min_mbr_ordinate(t.shape, 1)) || ',' 
            || TO_CHAR(sdo_geom.sdo_min_mbr_ordinate(t.shape, 2)) || ',' 
            || TO_CHAR(sdo_geom.sdo_max_mbr_ordinate(t.shape, 1)) || ',' 
            || TO_CHAR(sdo_geom.sdo_max_mbr_ordinate(t.shape, 2)) 
WHERE 
t.project_name = 'BASEMAP' AND 
t.layer_name = 'PARK_LABEL_SDO';
COMMIT;
SET ECHO OFF
SET FEEDBACK OFF
SET VERIFY OFF
SET HEADING OFF
SET TERMOUT OFF
SET TRIMOUT ON
SET TRIMSPOOL ON
SET WRAP OFF
SET LINESIZE 32000
SET LONG 32000
SET LONGCHUNKSIZE 32000
SET SERVEROUT OFF
SET RECSEP OFF
SET PAGES 0
SPOOL D:\matt_projects_data\mschell_data\tilerefresh\basemap\park_label_sdo.txt REPLACE
COLUMN coords FORMAT A32000
select coords as coords from tilerefresh_seeds where project_name = 'BASEMAP' and layer_name = 'PARK_LABEL_SDO';
SPOOL OFF
EXIT