whenever sqlerror exit failure rollback


create user cmn_it_support$owner 
identified by "cmn_it_support$owner" 
password expire account lock
;


/* inherit privileges: DB >= 12.1 */
whenever sqlerror continue none

grant inherit privileges on user sys to cmn_it_support$owner;
/*  ^                             ^
    |                             |
    +--- NOTE: 1 such GRANT for each invoker! */

whenever sqlerror exit failure rollback


alter session set current_schema = cmn_it_support$owner;

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

@@cr_function_clob_as_varchar2list.sql

grant execute on clob_as_varchar2list to public;

create or replace public synonym c##clob_as_varchar2list for clob_as_varchar2list;


/* -- End -- */
