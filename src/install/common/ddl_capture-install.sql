define def_echo = ""

whenever oserror exit failure rollback

set echo off
set verify off

@@ddl_capture-settings

whenever sqlerror continue none

prompt
prompt ============================
prompt Creating owner user + grants
prompt ---------------------------- 

@@ddl_capture/def_db_version

@@ddl_capture/create_capture_owner

whenever sqlerror exit failure rollback

@@ddl_capture/grants_to_capture_owner

prompt
prompt =======================
prompt Creating schema objects
prompt ----------------------- 

whenever sqlerror exit failure rollback

set verify on
create role &&def_read_captured_ddl_role;
set verify off

alter session set current_schema = "&&def_ddl_capture_user";

create sequence seq_ddl_pre  start with 1 nomaxvalue cache 1000;
create sequence seq_ddl_post start with 1 nomaxvalue cache 1000;

@@ddl_capture/pre_ddl_table
@@ddl_capture/post_ddl_table
@@ddl_capture/pre_ddl_view
@@ddl_capture/post_ddl_view

prompt
prompt ==================================
prompt Creating the pre/post DDL triggers
prompt ----------------------------------

@@ddl_capture/pre_ddl_trig
@@ddl_capture/post_ddl_trig

alter trigger trig_ddl_pre enable;
alter trigger trig_ddl_post enable;

prompt
prompt =============================
prompt Creating the weekly purge job
prompt -----------------------------

@@ddl_capture/pkg_purge_captured_ddl.pks
@@ddl_capture/pkg_purge_captured_ddl.pkb
@@ddl_capture/weekly_purge_job


/*--------------------------------------------------------------------------------------*/
/* Done */

prompt
prompt Installation complete.
prompt 

alter session set current_schema = "&&_USER";

set verify on

undefine def_ddl_capture_user
undefine def_ddl_capture_tabspc
undefine def_ddl_capture_temp_tabspc
undefine def_read_captured_ddl_role
undefine def_common_ddl_capture_user
undefine def_pdb_aware
undefine def_pre_ddl_table
undefine def_post_ddl_table
undefine def_pre_ddl_view
undefine def_post_ddl_view
undefine def_purge_job_name
undefine def_purge_retention_weeks
undefine def_purge_retention_days
undefine def_purge_repeat_interval 
undefine def_drop_ddl_capture_user
undefine def_db_version_ge_12
undefine def_db_version_lt_12
undefine def_db_version_ge_18
undefine def_db_version_lt_18
undefine def_echo

whenever oserror continue none
whenever sqlerror continue none
