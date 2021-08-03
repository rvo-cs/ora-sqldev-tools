set verify on

create user &&def_ddl_capture_user
&&def_db_version_ge_18 no authentication
&&def_db_version_lt_18 identified by "sX8~63+pQ847!"
&&def_db_version_lt_18 password expire
&&def_db_version_lt_18 account lock
default tablespace "&&def_ddl_capture_tabspc"
temporary tablespace "&&def_ddl_capture_temp_tabspc"
&&def_common_ddl_capture_user container = all
;

set verify off
