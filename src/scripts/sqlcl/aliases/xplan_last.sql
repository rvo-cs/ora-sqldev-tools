alias nulldefaults group=rvo-cs xplan_last=q'<set pagesize 5000
set trimout on
set heading off
set feedback off
column plan_table_output format a200 wrapped
prompt __________________________________________________________________________________________
select * from table(dbms_xplan.display_cursor(
        null, 
        null, 
        nvl2( regexp_replace(:plan_opt, '[-+].*$')
            , regexp_replace(:plan_opt, '[-+].*$') || ' -projection ' || regexp_substr(:plan_opt, '[-+].*$')
            , 'Advanced -projection +allstats last ' || :plan_opt)));
column plan_table_output clear
set heading on
set feedback 6
>';

alias desc xplan_last : displays the plan of the previous SQL statement
