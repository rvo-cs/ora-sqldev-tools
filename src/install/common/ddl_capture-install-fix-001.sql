define def_echo = ""

whenever oserror exit failure rollback
whenever sqlerror exit failure rollback

set echo off
set verify off

@@ddl_capture-settings

prompt
prompt =======================
prompt Updating schema objects
prompt ----------------------- 

alter session set current_schema = "&&def_ddl_capture_user";

alter trigger trig_ddl_pre disable;
alter trigger trig_ddl_post disable;

@@ddl_capture/alter-pre_ddl_table-001
@@ddl_capture/alter-post_ddl_table-001

@@ddl_capture/pkg_purge_captured_ddl.pks
@@ddl_capture/pkg_purge_captured_ddl.pkb

prompt
prompt =====================================
prompt Re-creating the pre/post DDL triggers
prompt -------------------------------------

@@ddl_capture/pre_ddl_trig
@@ddl_capture/post_ddl_trig

alter trigger trig_ddl_pre enable;
alter trigger trig_ddl_post enable;

/*--------------------------------------------------------------------------------------*/
/* Done */

prompt
prompt Completed.
prompt 

alter session set current_schema = "&&_USER";

set verify on

@@ddl_capture/undef_ddl_capture_settings
undefine def_echo

whenever oserror continue none
whenever sqlerror continue none
