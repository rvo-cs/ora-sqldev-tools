alias nulldefaults group=rvo-cs xplan_last=q'<set pagesize 5000
set trimout on
set heading off
set feedback off
set linesize 250
column plan_table_output format a250 wrapped
prompt __________________________________________________________________________________________
select * from table(dbms_xplan.display_cursor(
        null, 
        null, 
        nvl2( regexp_replace(:plan_opt, '[-+].*$')
            , regexp_replace(:plan_opt, '[-+].*$') || ' -projection ' || regexp_substr(:plan_opt, '[-+].*$')
            , 'Advanced -projection +iostats last ' || :plan_opt)));
column plan_table_output clear
set heading on
set feedback 6
>';

alias desc xplan_last : displays the plan of the previous SQL statement

set define off

alias nulldefaults group=rvo-cs plan_stats=q'<set feedback off
exec :sqlcl_alias_arg := upper(:sqlcl_alias_arg);
tosub def_param_value=:sqlcl_alias_arg
set define on
set verify off
alter session set statistics_level = "&&def_param_value";
define def_param_value = ""
column param_value format a20 noprint new_value def_param_value
set termout off
select
    case
        when :sqlcl_alias_arg in ('BASIC', 'TYPICAL', 'ALL')
        then :sqlcl_alias_arg
        else '? [unchanged]'
    end as param_value
from dual;
set termout on
prompt
prompt Plan statistics level : &&def_param_value
prompt
column param_value clear
undefine def_param_value
set verify on
set feedback 6
>';

set define on

alias desc plan_stats : sets statistics_level in the session

