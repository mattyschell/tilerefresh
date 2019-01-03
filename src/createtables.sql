set serveroutput on;
begin
   TILEREFRESH.CREATE_TRPARAMS(); 
EXCEPTION
WHEN OTHERS THEN
   IF SQLERRM LIKE '%ORA-00955: name is already used%' 
   THEN 
      NULL;
   ELSE
      raise_application_error(-20001, SQLERRM);
   END IF;
END;
/
begin
   TILEREFRESH.CREATE_TRSEEDS();
EXCEPTION
WHEN OTHERS THEN
   IF SQLERRM LIKE '%ORA-00955: name is already used%' 
   THEN 
      NULL;
   ELSE
      raise_application_error(-20001, SQLERRM);
   END IF;
END;
/
exit


