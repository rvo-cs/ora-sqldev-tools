define def_echo = ""

whenever oserror exit failure rollback

set echo off
set verify off

@@it_session_helper-settings

whenever sqlerror continue none

prompt
prompt ============================
prompt Creating owner user + grants
prompt ---------------------------- 

@@it_session_helper/def_db_version

@@it_session_helper/create_owner_accnt

whenever sqlerror exit failure rollback

@@it_session_helper/grants_to_owner_accnt

prompt
prompt =======================
prompt Creating schema objects
prompt ----------------------- 

whenever sqlerror exit failure rollback

alter session set current_schema = "&&def_it_sess_helper_user";

create sequence seq_sess_helper start with 1 nomaxvalue cache 200;

@@it_session_helper/create_log_table

prompt
prompt ==========================
prompt Creating the main package
prompt --------------------------

@@it_session_helper/pkg_session_helper.pks
@@it_session_helper/pkg_session_helper.pkb

grant execute on "&&def_it_sess_helper_user"."PKG_SESSION_HELPER" to public;

prompt
prompt ======
prompt Roles
prompt ------

create role "&&def_it_role_end_session_self";
revoke "&&def_it_role_end_session_self" from "&&_USER";

prompt
prompt ================
prompt Public synonyms
prompt ----------------

@@it_session_helper/create_pubsyn&&def_it_sess_helper_create_pubsyn

prompt
prompt =============================
prompt Creating the weekly purge job
prompt -----------------------------

@@it_session_helper/pkg_purge_itsesshlplog.pks
@@it_session_helper/pkg_purge_itsesshlplog.pkb
@@it_session_helper/weekly_purge_job


/*--------------------------------------------------------------------------------------*/
/* Done */

prompt
prompt Installation complete.
prompt 

@@it_session_helper/cleanup

alter session set current_schema = "&&_USER";

set verify on

whenever oserror continue none
whenever sqlerror continue none
