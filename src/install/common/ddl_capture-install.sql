/*
 * SPDX-FileCopyrightText: 2021-2024 R.Vassallo
 * SPDX-License-Identifier: BSD Zero Clause License
 */

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
revoke &&def_read_captured_ddl_role from "&&_USER";
set verify off

alter session set current_schema = "&&def_ddl_capture_user";

create sequence seq_ddl_pre  start with 1 nomaxvalue cache 1000;
create sequence seq_ddl_post start with 1 nomaxvalue cache 1000;

@@ddl_capture/pre_ddl_table
@@ddl_capture/post_ddl_table
@@ddl_capture/pre_ddl_view
@@ddl_capture/post_ddl_view

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

@@ddl_capture/weekly_purge_job


/*--------------------------------------------------------------------------------------*/
/* Done */

prompt
prompt Installation complete.
prompt 

alter session set current_schema = "&&_USER";

set verify on

@@ddl_capture/undef_ddl_capture_settings
@@ddl_capture/undef_db_version
undefine def_echo

whenever oserror continue none
whenever sqlerror continue none
