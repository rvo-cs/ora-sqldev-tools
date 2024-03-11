/*
 * SPDX-FileCopyrightText: 2023 R.Vassallo
 * SPDX-License-Identifier: BSD Zero Clause License
 */

whenever oserror exit failure rollback
whenever sqlerror continue none

set echo off
set verify off

@@it_session_helper-settings

prompt
prompt =============================
prompt Dropping the weekly purge job
prompt -----------------------------

begin
    dbms_scheduler.drop_job(job_name => '&&def_it_sess_helper_user..&&def_purge_job_name');
end;
/

prompt
prompt ======
prompt Roles
prompt ------

drop role "&&def_it_role_view_session_self";
drop role "&&def_it_role_end_session_self";

prompt
prompt ================
prompt Public synonyms
prompt ----------------

@@it_session_helper/drop_pubsyn&&def_it_sess_helper_with_pubsyn..sql

prompt
prompt =======================
prompt Dropping schema objects
prompt -----------------------

drop package "&&def_it_sess_helper_user".pkg_session_helper;
drop package "&&def_it_sess_helper_user".pkg_purge_itsesshlplog;

drop table "&&def_it_sess_helper_user"."&&def_it_sess_helper_log_table" purge;

drop sequence "&&def_it_sess_helper_user".seq_sess_helper;

-- ==============================
-- Drop the owner user, if needed
-- ------------------------------

@@it_session_helper/drop_owner_accnt&&def_drop_it_sess_helper_user..sql


/*--------------------------------------------------------------------------------------*/
/* Done */

prompt
prompt Uninstallation done.
prompt 

@@it_session_helper/cleanup

set verify on

whenever oserror continue none
whenever sqlerror continue none
