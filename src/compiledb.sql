set serveroutput on;
@src/GISLAYER.tps;
@src/GISLAYER.tpb;
@src/TILEREFRESH.pks;
@src/TILEREFRESH.pkb;
EXEC DBMS_UTILITY.compile_schema(schema => USER);
/
exit