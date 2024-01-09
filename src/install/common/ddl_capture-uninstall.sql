whenever oserror exit failure rollback

set echo off
set verify off

@@ddl_capture-settings

whenever sqlerror continue none

prompt
prompt =============================
prompt Dropping the weekly purge job
prompt -----------------------------

begin
    dbms_scheduler.drop_job(job_name => '&&def_ddl_capture_user..&&def_purge_job_name');
end;
/

prompt
prompt =========================
prompt Dropping the DDL triggers
prompt -------------------------

alter trigger "&&def_ddl_capture_user".trig_ddl_pre disable;
alter trigger "&&def_ddl_capture_user".trig_ddl_post disable;

drop trigger "&&def_ddl_capture_user".trig_ddl_pre;
drop trigger "&&def_ddl_capture_user".trig_ddl_post;

prompt
prompt =======================
prompt Dropping schema objects
prompt -----------------------

drop package "&&def_ddl_capture_user".pkg_purge_captured_ddl;

drop view "&&def_ddl_capture_user"."&&def_pre_ddl_view";
drop view "&&def_ddl_capture_user"."&&def_post_ddl_view";

drop table "&&def_ddl_capture_user"."&&def_pre_ddl_table" purge;
drop table "&&def_ddl_capture_user"."&&def_post_ddl_table" purge;

drop sequence "&&def_ddl_capture_user".seq_ddl_pre;
drop sequence "&&def_ddl_capture_user".seq_ddl_post;

set verify on
drop role &&def_read_captured_ddl_role;
set verify off

-- ==============================
-- Drop the owner user, if needed
-- ------------------------------

@@ddl_capture/drop_capture_owner&&def_drop_ddl_capture_user..sql


/*--------------------------------------------------------------------------------------*/
/* Done */

prompt
prompt Uninstallation done.
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

whenever oserror continue none
whenever sqlerror continue none
