set serveroutput on;
EXEC DBMS_UTILITY.compile_schema(schema => USER);
declare
   output varchar2(4000);    
begin
   output := test_gislayer.RUN_TESTS();
   dbms_output.put_line(output);
   output := test_tilerefresh.RUN_TESTS();
   dbms_output.put_line(output);
end;
/
exit