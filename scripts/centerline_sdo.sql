--sqlplus basemap/iluvdoitt247@geocdev.doitt.nycnet @centerline_sdo.sql
DELETE FROM basemap.tilerefresh_params
      WHERE project_name = 'BASEMAP' AND layer_name = 'CENTERLINE_SDO';
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
               'CENTERLINE_SDO',
               'CENTERLINE_SDO_X', --temp view to old data 
               'CENTERLINE_SDO',   --current view
               'objectid',
               'physicalid',
               3857,
               'STNAME_LABEL,RW_TYPE,TRAFDIR,CARTO_DISPLAY_LEVEL');
COMMIT;
--remove previous seeds if run
DELETE FROM tilerefresh_seeds
      WHERE project_name = 'BASEMAP' AND layer_name = 'CENTERLINE_SDO';
COMMIT;
CALL tilerefresh.DUMPCALLS('BASEMAP',
                           'CENTERLINE_SDO');
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
SPOOL D:\matt_projects_data\mschell_data\tilerefresh\basemap\centerline_sdo.txt REPLACE
COLUMN coords FORMAT A32000
select coords as coords from tilerefresh_seeds where project_name = 'BASEMAP' and layer_name = 'CENTERLINE_SDO';
SPOOL OFF
EXIT