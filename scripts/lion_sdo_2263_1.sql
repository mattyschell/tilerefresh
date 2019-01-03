--faking the MBR run in master@giscmnt with hacked together data
--sqlplus master/iluvdoitt247@geocdev.doitt.nycnet @lion_sdo_2263_1.sql
DELETE FROM master.tilerefresh_params
      WHERE project_name = 'DTM' AND layer_name = 'LION';
INSERT INTO master.tilerefresh_params (
                                project_name,
                                layer_name,
                                table1,
                                table2,
                                synthkey,
                                businesskey,
                                srid,
                                cols)
     VALUES (  'DTM',
               'LION',
               'LION_SDO_2263_11B', --temp view rewired to geodatashare.building_sdo_2263_1
               'LION_SDO_2263_1',   --current.  points to geodatashare.building_sdo_2263_2
               'objectid',
               'segmentid',
               2263,
               'STREET');
COMMIT;
--remove previous seeds if run
--also dumb gradle build sets seeds srid to 3857
call TILEREFRESH.CREATE_TRSEEDS('TILEREFRESH_SEEDS','Y',2263,.0005);
COMMIT;
CALL tilerefresh.DUMPCALLS('DTM',
                           'LION');
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
SPOOL D:\matt_projects_data\mschell_data\tilerefresh\giscmnt\master\dtmlion.txt REPLACE
COLUMN coords FORMAT A32000
select coords as coords from tilerefresh_seeds where project_name = 'DTM' and layer_name = 'LION';
SPOOL OFF
EXIT