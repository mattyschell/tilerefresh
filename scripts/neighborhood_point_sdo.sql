--sqlplus basemap/iluvdoitt247@geocdev.doitt.nycnet @scripts/neighborhood_point_sdo.sql
DELETE FROM basemap.tilerefresh_params
      WHERE project_name = 'BASEMAP' AND layer_name = 'NEIGHBORHOOD_POINT_SDO';
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
               'NEIGHBORHOOD_POINT_SDO',
               'NEIGHBORHOOD_POINT_SDO_OLD', --temp view wired to old dataset
               'NEIGHBORHOOD_POINT_SDO',   --current
               'objectid',
               'pjareaname',  --name is the business key. Almost all changed
               3857, 
               'PJAREANAME'
               );  
               COMMIT;
--remove previous seeds if run
DELETE FROM tilerefresh_seeds
      WHERE project_name = 'BASEMAP' AND layer_name = 'NEIGHBORHOOD_POINT_SDO';
COMMIT;
CALL tilerefresh.DUMPCALLS('BASEMAP',
                           'NEIGHBORHOOD_POINT_SDO');
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
SPOOL D:\matt_projects_data\mschell_data\tilerefresh\basemap\neighborhood_point_sdo.txt REPLACE
COLUMN coords FORMAT A32000
select coords as coords from tilerefresh_seeds where project_name = 'BASEMAP' and layer_name = 'NEIGHBORHOOD_POINT_SDO';
SPOOL OFF
EXIT