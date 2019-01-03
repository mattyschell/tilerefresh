--sqlplus basemap/iluvdoitt247@geocdev.doitt.nycnet @building_sdo.sql
DELETE FROM basemap.tilerefresh_params
      WHERE project_name = 'BASEMAP' AND layer_name = 'BUILDING_SDO';
INSERT INTO basemap.tilerefresh_params (
                                project_name,
                                layer_name,
                                table1,
                                table2,
                                synthkey,
                                businesskey,
                                srid,
                                cols)
     VALUES (  'BASEMAP',
               'BUILDING_SDO',   --layer name in geowebcache
               'BUILDING_SDO_X', --temp view rewired to geodatashare.building_sdo_2263_<previous>
               'BUILDING_SDO',   --current.  points to geodatashare.building_sdo_2263_<latest>
               'objectid',
               'doitt_id',
               3857,
               'DOITT_ID');
COMMIT;
--remove previous seeds on rerun
DELETE FROM tilerefresh_seeds
      WHERE project_name = 'BASEMAP' AND layer_name = 'BUILDING_SDO';
COMMIT;
CALL tilerefresh.DUMPCALLS('BASEMAP',
                           'BUILDING_SDO');
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
SPOOL D:\matt_projects_data\mschell_data\tilerefresh\basemap\building_sdo.txt REPLACE
COLUMN coords FORMAT A32000
select coords as coords from tilerefresh_seeds where project_name = 'BASEMAP' and layer_name = 'BUILDING_SDO';
SPOOL OFF
EXIT