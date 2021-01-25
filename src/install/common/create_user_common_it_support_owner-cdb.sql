whenever sqlerror exit failure rollback


create user c##it_support$owner
no authentication  /* <-- NOTE: schema-only account */
/*
identified by "c##it_support$owner" 
password expire account lock
*/
container = all
;

grant inherit privileges on user sys to c##it_support$owner;
/*  ^                             ^
    |                             |
    +--- NOTE: 1 such GRANT for each invoker! */


alter session set current_schema = c##it_support$owner;

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

@@cr_function_clob_as_varchar2list.sql

grant execute on clob_as_varchar2list to public;

create or replace public synonym c##clob_as_varchar2list for clob_as_varchar2list;


/* -- End -- */
