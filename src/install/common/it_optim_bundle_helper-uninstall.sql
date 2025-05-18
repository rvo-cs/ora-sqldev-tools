/*
 * SPDX-FileCopyrightText: 2025 R.Vassallo
 * SPDX-License-Identifier: BSD Zero Clause License
 */

whenever oserror exit failure rollback
whenever sqlerror continue none

set echo off
set verify off

@@it_optim_bundle_helper-settings

prompt
prompt ================
prompt Public synonyms
prompt ----------------

prompt

@@it_optim_bundle_helper/drop_pubsyn&&def_fix_cntrl_hlpr_with_pubsyn..sql

prompt
prompt ========================
prompt Dropping schema objects
prompt ------------------------

prompt

drop package "&&def_fix_cntrl_hlpr_user".pkg_optim_bundle_helper;
drop type "&&def_fix_cntrl_hlpr_user".tab_fixctl;
drop type "&&def_fix_cntrl_hlpr_user".obj_fixctl;

prompt
prompt ======
prompt Roles
prompt ------

prompt

drop role "&&def_fix_cntrl_hlpr_pkg_role";

-- ==============================
-- Drop the owner user, if needed
-- ------------------------------

@@it_optim_bundle_helper/drop_owner_accnt&&def_drop_fix_cntrl_hlpr_user..sql


/*--------------------------------------------------------------------------------------*/
/* Done */

prompt
prompt Uninstallation done.
prompt 

@@it_optim_bundle_helper/cleanup

set verify on

whenever oserror continue none
whenever sqlerror continue none
