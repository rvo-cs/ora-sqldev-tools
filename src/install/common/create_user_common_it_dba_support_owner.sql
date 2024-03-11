/*
 * SPDX-FileCopyrightText: 2023 R.Vassallo
 * SPDX-License-Identifier: Apache License 2.0
 */

whenever oserror exit failure rollback
whenever sqlerror exit failure rollback
/*
   ##########################################################################
   ###  IMPORTANT: some grants in this script require SYSDBA privileges.  ###
   ##########################################################################
*/

define it_dba_support_user = "CMN_IT_DBA_SUPPORT$OWNER"

create user &&it_dba_support_user 
identified by "&&it_dba_support_user" 
password expire account lock
;

/* ---vvv--- With SYSDBA privileges (begin) ---vvv--- */

/* inherit privileges: DB >= 12.1 */
whenever sqlerror continue none

/*
    IMPORTANT: the following system privilege means that the code
    in the &&it_dba_support_user schema is trusted: any user in the DB
    may call invoker's rights program units defined in that schema
    with all their roles and privileges enabled.
 */
grant inherit any privileges to &&it_dba_support_user;

/*
    Alternatively--but then this must done for each invoker--use
    the corresponding object privilege: trust is granted separately
    by each interested user, or on their behalf.

    grant inherit privileges on user sys to &&it_dba_support_user;
        ^                             ^
        |                             |
        +--- NOTE: 1 such GRANT for each invoker!
*/

whenever sqlerror exit failure rollback

grant execute on sys.utl_xml     to &&it_dba_support_user;
grant execute on sys.utl_xml_lib to &&it_dba_support_user;

/* ---^^^--- With SYSDBA privileges (end) ---^^^--- */


alter session set current_schema = &&it_dba_support_user;

/*----------------------------------------------------------------------------*/

@@pkg_dba_parse_util.pks
@@pkg_dba_parse_util.pkb

create or replace public synonym c##pkg_dba_parse_util for pkg_dba_parse_util;


/*----------------------------------------------------------------------------*/

undefine it_dba_support_user

/* -- End -- */
