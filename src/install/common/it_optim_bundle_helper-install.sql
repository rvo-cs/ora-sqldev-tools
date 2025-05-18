/*
 * SPDX-FileCopyrightText: 2025 R.Vassallo
 * SPDX-License-Identifier: BSD Zero Clause License
 */

whenever oserror exit failure rollback
whenever sqlerror exit failure rollback

define def_echo = ""

set echo off
set verify off

@@it_optim_bundle_helper-settings

@@it_optim_bundle_helper/def_db_version

prompt
prompt ============================
prompt Creating owner user + grants
prompt ---------------------------- 

prompt

@@it_optim_bundle_helper/create_owner_accnt

---vvv--- SYSDBA privs required ---vvv---
whenever sqlerror continue none
@@it_optim_bundle_helper/grants_to_owner_accnt
whenever sqlerror exit failure rollback
---^^^--- SYSDBA privs required ---^^^---

prompt
prompt ============================
prompt Creating the helper package
prompt ----------------------------

prompt

alter session set current_schema = "&&def_fix_cntrl_hlpr_user";

@@it_optim_bundle_helper/obj_fixctl.sql
@@it_optim_bundle_helper/tab_fixctl.sql

@@it_optim_bundle_helper/pkg_optim_bundle_helper.pks
show errors

@@it_optim_bundle_helper/pkg_optim_bundle_helper.pkb
show errors

grant execute on "&&def_fix_cntrl_hlpr_user"."TAB_FIXCTL" to public;
grant execute on "&&def_fix_cntrl_hlpr_user"."OBJ_FIXCTL" to public;
grant execute on "&&def_fix_cntrl_hlpr_user"."PKG_OPTIM_BUNDLE_HELPER" to public;

prompt =========================================
prompt Creating and granting the package's role
prompt -----------------------------------------

prompt

create role "&&def_fix_cntrl_hlpr_pkg_role";
whenever sqlerror continue none
revoke "&&def_fix_cntrl_hlpr_pkg_role" from "&&_USER";
whenever sqlerror exit failure rollback

---vvv--- SYSDBA privs required ---vvv---
whenever sqlerror continue none
@@it_optim_bundle_helper/grant_to_pkg_only_role
set verify on
grant "&&def_fix_cntrl_hlpr_pkg_role" to  "&&def_fix_cntrl_hlpr_user";
grant "&&def_fix_cntrl_hlpr_pkg_role" to package "&&def_fix_cntrl_hlpr_user"."PKG_OPTIM_BUNDLE_HELPER";
set verify off
whenever sqlerror exit failure rollback
---^^^--- SYSDBA privs required ---^^^---

prompt
prompt ================
prompt Public synonyms
prompt ----------------

prompt

@@it_optim_bundle_helper/create_pubsyn&&def_fix_cntrl_hlpr_with_pubsyn..sql

/*--------------------------------------------------------------------------------------*/
/* Done */

prompt
prompt Installation complete.
prompt 

@@it_optim_bundle_helper/cleanup

alter session set current_schema = "&&_USER";

set verify on

whenever oserror continue none
whenever sqlerror continue none
