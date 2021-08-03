prompt
prompt ==============================
prompt Dropping the DDL capture owner
prompt ------------------------------

set verify on

drop user "&&def_ddl_capture_user";

set verify off
