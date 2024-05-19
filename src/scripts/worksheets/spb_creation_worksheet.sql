-- SPDX-FileCopyrightText: 2024 R.Vassallo
-- SPDX-License-Identifier: BSD Zero Clause License

/*=========================================
 * Manual creation of a SQL Plan Baseline,
 * using the create_fixed_spb.sql script
 */

-- Important: both the original and replacement plans must be loaded
-- into the cursor cache for this to work
 
-- Original plan
define def_spb_orig_sqlid      = "5k8nhqcnqsgbf"
define def_spb_orig_plan_hash  = 2959412835
define def_spb_orig_plan_descr = "SQL id: 5k8nhqcnqsgbf -- initial plan"

-- Replacement plan
define def_spb_repl_sqlid       = "c375wyqvm85wu"
define def_spb_repl_plan_hash   = 3114288414
define def_spb_repl_plan_descr  = "SQL id: 5k8nhqcnqsgbf -- replacement plan"

-- Script for creating the SPB and fixing the plan
@create_fixed_spb


/*=============================================
 * View plan hash values in SQL plans in SPBs 
 */
 
select
    a.signature, a.sql_handle, a.sql_text,
    a.plan_name,
    regexp_replace(b.plan_table_output, '^Plan hash value: ', null) as plan_hash_value,
    a.creator, a.origin, a.parsing_schema_name,
    a.description, a.version, a.created, 
    a.last_modified, a.last_executed, a.last_verified,
    a.enabled, a.accepted, a.fixed,
    a.reproduced, a.autopurge, a.optimizer_cost,
    a.module, a.action, a.executions,
    a.elapsed_time, a.cpu_time, a.buffer_gets,
    a.disk_reads, a.direct_writes, a.rows_processed,
    a.fetches, a.end_of_fetch_count
from 
    dba_sql_plan_baselines a,
    table(dbms_xplan.display_sql_plan_baseline(sql_handle => a.sql_handle, 
            plan_name => a.plan_name, format => 'basic')) (+) b
where
    regexp_like(b.plan_table_output (+), '(^plan hash value:|exception|ORA-)', 'i')
    /*---vvv--- optional filters below this line ---vvv---*/
    --and a.parsing_schema_name = :SCHEMA_NAME
    --and a.signature = (select sa.exact_matching_signature from v$sqlarea sa where sa.sql_id = :SQL_ID)
    --and regexp_like(a.sql_text, 'regular_expression_here', 'i')
    --and a.enabled = 'YES'
    --and a.fixed = 'YES'
    --and a.created >= systimestamp - numtodsinterval(120, 'MINUTE')
    --and a.created >= timestamp '2024-05-19 13:30:00'
;


/*=========================================
 * Display a plan from a SQL Plan baseline 
 */
 
select * 
from
    table(dbms_xplan.display_sql_plan_baseline(
        sql_handle => 'SQL_48dd4be3525291d5', 
        plan_name  => 'SQL_PLAN_4jrabwd9554fp3fc22c54',
        format     => 'Advanced -projection -qbregistry'   /* 19c and higher */
        --format   => 'Advanced -projection'               /* DB < 19c */
    ));


/*===========================
 * Drop SQL Plan Baseline(s) 
 */

/*--
set serveroutput on
declare
    l_cnt pls_integer;
begin
    dbms_output.enable(null);
    l_cnt := dbms_spm.drop_sql_plan_baseline(
        sql_handle => 'SQL_48dd4be3525291d5',
        plan_name => null
    );
    dbms_output.put_line('Dropped ' || l_cnt || ' SPB' 
            || case when l_cnt > 1 then 's' end || '.');
end;
/
--*/
