whenever oserror exit failure rollback
whenever sqlerror exit failure rollback
/*
   ##########################################################################
   ###  IMPORTANT: some grants in this script require SYSDBA privileges.  ###
   ##########################################################################
*/

define it_support_user = "CMN_IT_SUPPORT$OWNER"

create user &&it_support_user 
identified by "&&it_support_user" 
password expire account lock
;

/* ---vvv--- With SYSDBA privileges (begin) ---vvv--- */

/* inherit privileges: DB >= 12.1 */
whenever sqlerror continue none

/*
    IMPORTANT: the following system privilege means that the code
    in the &&it_support_user schema is trusted: any user in the DB
    may call invoker's rights program units defined in that schema
    with all their roles and privileges enabled.
 */
grant inherit any privileges to &&it_support_user;

/*
    Alternatively--but then this must done for each invoker--use
    the corresponding object privilege: trust is granted separately
    by each interested user, or on their behalf.

    grant inherit privileges on user sys to &&it_support_user;
        ^                             ^
        |                             |
        +--- NOTE: 1 such GRANT for each invoker!
*/

whenever sqlerror exit failure rollback


grant select on sys.v_$latch    to &&it_support_user;
grant select on sys.v_$sesstat  to &&it_support_user;
grant select on sys.v_$statname to &&it_support_user;

/* ---^^^--- With SYSDBA privileges (end) ---^^^--- */


alter session set current_schema = &&it_support_user;

/*----------------------------------------------------------------------------*/

@@pkg_pub_stats_helper.pks
@@pkg_pub_stats_helper.pkb

grant execute on pkg_pub_stats_helper to public;

create or replace public synonym c##pkg_pub_stats_helper for pkg_pub_stats_helper;

/*----------------------------------------------------------------------------*/

@@pkg_pub_partition_helper.pks
@@pkg_pub_partition_helper.pkb

grant execute on pkg_pub_partition_helper to public;

create or replace public synonym c##pkg_pub_partition_helper for pkg_pub_partition_helper;

/*----------------------------------------------------------------------------*/

@@pkg_pub_call_stack_helper.pks
@@pkg_pub_call_stack_helper.pkb

grant execute on pkg_pub_call_stack_helper to public;

create or replace public synonym c##pkg_pub_call_stack_helper for pkg_pub_call_stack_helper;

/*----------------------------------------------------------------------------*/

/* Not a mistake, must create this synonym first! */
create or replace public synonym c##pkg_pub_sesstat_helper for pkg_pub_sesstat_helper;

@@pkg_pub_sesstat_helper.pks
@@pkg_pub_sesstat_helper.pkb

grant execute on pkg_pub_sesstat_helper to public;

/*----------------------------------------------------------------------------*/

@@cr_function_clob_as_varchar2list.sql

grant execute on clob_as_varchar2list to public;

create or replace public synonym c##clob_as_varchar2list for clob_as_varchar2list;


/* -- End -- */
