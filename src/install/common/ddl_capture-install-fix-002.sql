/*
 * SPDX-FileCopyrightText: 2024 R.Vassallo
 * SPDX-License-Identifier: BSD Zero Clause License
 */

define def_echo = ""

whenever oserror exit failure rollback
whenever sqlerror exit failure rollback

set echo off
set verify off

@@ddl_capture-settings

@@ddl_capture/def_db_version

alter session set current_schema = "&&def_ddl_capture_user";

alter trigger trig_ddl_pre disable;
alter trigger trig_ddl_post disable;

prompt
prompt =======================
prompt Creating schema objects
prompt ----------------------- 

@@ddl_capture/pre_grant_table&&def_ddl_capture_grant_details..sql
@@ddl_capture/post_grant_table&&def_ddl_capture_grant_details..sql
@@ddl_capture/pre_grant_view&&def_ddl_capture_grant_details..sql
@@ddl_capture/post_grant_view&&def_ddl_capture_grant_details..sql

begin
    execute immediate 
        'alter session set plsql_ccflags = "ddl_capture_grant_details:'
            || case 
                   when '&&def_ddl_capture_grant_details' is null then 'true' 
                   else 'false' 
               end
            || '"';
end;
/

@@ddl_capture/pkg_capture_ddl.pks
@@ddl_capture/pkg_capture_ddl.pkb

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

prompt
prompt ================================
prompt Re-creating the weekly purge job
prompt --------------------------------

begin
    dbms_scheduler.drop_job(
        job_name => sys_context('USERENV', 'CURRENT_SCHEMA') || '.' || '&&def_purge_job_name'
    );
end;
/

@@ddl_capture/weekly_purge_job

/*--------------------------------------------------------------------------------------*/
/* Done */

prompt
prompt Completed.
prompt 

alter session set current_schema = "&&_USER";

set verify on

@@ddl_capture/undef_ddl_capture_settings
@@ddl_capture/undef_db_version
undefine def_echo

whenever oserror continue none
whenever sqlerror continue none
