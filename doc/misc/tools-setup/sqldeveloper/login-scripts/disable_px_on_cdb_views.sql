-- disable_px_on_cdb_views.sql
--
-- This script sets "_px_cdb_view_enabled"=false at session-level on
-- multitenant DB, in order to prevent queries against Data Dictionary
-- views from running in parallel query mode automatically.
-- 
-- Reason: using parallel query for queries against Data Dictionary views is
-- usually a bad idea in the first place (and an unpleasant surprise in 12c);
-- further, it may cause errors due to issues in SQL tranformations when
-- parsing complex queries, e.g. per bug 32140800:
--
--    ORA-12801: error signaled in parallel query server Pxxx
--    ORA-32034: unsupported use of WITH clause
--
-- (This bug affects 19c RUs < 19.12; see MOS Doc ID 2750033.1)

set feedback off

declare
    e_invalid_userenv_param exception;
    pragma exception_init(e_invalid_userenv_param, -2003);

    l_con_id number;
begin
    select to_number(sys_context('USERENV', 'CON_ID')) into l_con_id from dual;
    if l_con_id = 0 then
        -- Release 12.1 or higher, non-CDB; do nothing
        null;
    else
        -- Release 12.1 or higher, in a PDB or CDB$ROOT: disable automatic
        -- parallel query for queries against Data Dictionary views
        execute immediate 'alter session set "_px_cdb_view_enabled"=false';
    end if;
exception
    when e_invalid_userenv_param then
        -- Release 11.2 or earlier, not multitenant capable; do nothing
        null;
end;
/

set feedback on
