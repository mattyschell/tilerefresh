--sqlplus basemap/iluvdoitt247@geocdev.doitt.nycnet @scripts/park_clip_sdo.sql
DELETE FROM basemap.tilerefresh_params
      WHERE project_name = 'BASEMAP' AND layer_name = 'PARK_CLIP_SDO';
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
--               'PARK_CLIP_SDO',
--              'PARK_CLIP_SDO_OLD', --temp view rewired to geodatashare.park_sdo_2263_1
--               'PARK_CLIP_SDO',     --current.  points to geodatashare.park_sdo_2263_3
--               'objectid',
--               'parknum',
--               3857,
--               'PARKNUM');
--COMMIT;
--CALL tilerefresh.DUMPCALLS('BASEMAP',
--                           'PARK_CLIP_SDO');
--remove previous seeds if run
DELETE FROM tilerefresh_seeds
      WHERE project_name = 'BASEMAP' AND layer_name = 'PARK_CLIP_SDO';
COMMIT;
-- there is no business key in this dataset
-- parknum is not unique, a baseball field in the middle of PARK Q123
-- also has overlapping territory with parknum Q123
-- since we were already headed toward a total replacement of tiles, (every shape
-- is slightly different) just brute force it all
-- then dissolve back to a more reasonable count
INSERT INTO tilerefresh_seeds 
   (seedid
   ,project_name
   ,layer_name
   ,shape)
SELECT tilerefresh_seedsseq.nextval
      ,'BASEMAP'
      ,'PARK_CLIP_SDO'
      ,SDO_CS.transform(SDO_GEOM.sdo_mbr(a.shape),3857) 
FROM park_clip_sdo_old a;
COMMIT;
INSERT INTO tilerefresh_seeds 
   (seedid
   ,project_name
   ,layer_name
   ,shape)
SELECT tilerefresh_seedsseq.nextval
      ,'BASEMAP'
      ,'PARK_CLIP_SDO'
      ,SDO_CS.transform(SDO_GEOM.sdo_mbr(a.shape),3857) 
FROM park_clip_sdo a;
COMMIT;
CALL TILEREFRESH.DISSOLVETABLE('TILEREFRESH_SEEDS'
                              ,'a.project_name = ''BASEMAP'' AND a.layer_name = ''PARK_CLIP_SDO'' '
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
t.layer_name = 'PARK_CLIP_SDO';
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
SPOOL D:\matt_projects_data\mschell_data\tilerefresh\basemap\park_clip_sdo.txt REPLACE
COLUMN coords FORMAT A32000
select coords as coords from tilerefresh_seeds where project_name = 'BASEMAP' and layer_name = 'PARK_CLIP_SDO';
SPOOL OFF
EXIT