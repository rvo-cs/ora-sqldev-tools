/*
 * SPDX-FileCopyrightText: 2021 R.Vassallo
 * SPDX-License-Identifier: BSD Zero Clause License
 */

with 
hist_time_model as (
    select 
        a.dbid, 
        a.instance_number,
        a.snap_id,
        a.stat_name,
        round((a.value 
                - lag(a.value) over (partition by a.dbid, a.instance_number, a.stat_name
                            order by a.snap_id asc))
                / power(10, 6)) as value_s
    from 
        dba_hist_sys_time_model a
),
hist_dbtime as (
    select
        sum(a.value_s) as dbtime_s
    from 
        hist_time_model a,
        dba_hist_snapshot b
    where
        a.dbid = b.dbid and a.instance_number = b.instance_number and a.snap_id = b.snap_id
        and a.stat_name = 'DB time'
        and b.begin_interval_time >= to_date(:FROM_TIME, 'YYYY-MM-DD HH24') - 1/24/4
        and b.end_interval_time <= (case when :TO_TIME is not null 
                                        then to_date(:TO_TIME, 'YYYY-MM-DD HH24') + 1/24/4
                                        else sysdate end)
        and a.dbid = nvl(:DBID, (select dbid from v$database))
        and ((:INST_ID is null and a.instance_number = sys_context('USERENV', 'INSTANCE'))
            or a.instance_number = :INST_ID)
),      
hist_sqlstat as (
    select
        a.dbid,
        a.instance_number,
        a.force_matching_signature,
        a.plan_hash_value,
        min(b.begin_interval_time) as min_begin_interval_time,
        max(b.end_interval_time) as max_end_interval_time,
        max(case when a.force_matching_signature = 0 then a.sql_id else c.sql_id end) as samp_sql_id,
        max(d.command_name) as command_name,
        max(a.parsing_schema_name) keep (dense_rank first order by a.snap_id desc) as parsing_schema_name,
        max(a.module) keep (dense_rank first order by a.snap_id desc) as module,
        max(a.action) keep (dense_rank first order by a.snap_id desc) as action,
        sum(a.invalidations_delta) as invalidations_delta,
        sum(a.parse_calls_delta) as parse_calls_delta,
        sum(a.loads_delta) as loads_delta,
        sum(a.executions_delta) as executions_delta,
        sum(a.fetches_delta) as fetches_delta,
        case when sum(a.executions_delta) > 0 
                then round(sum(a.fetches_delta) / sum(a.executions_delta), 2) end as fetch_px,
        sum(a.end_of_fetch_count_delta) as end_of_fetch_count_delta,
        case when sum(a.executions_delta) > 0 
                then round(sum(a.end_of_fetch_count_delta) / sum(a.executions_delta), 1) end as end_of_fetch_px,
        sum(a.rows_processed_delta) as rows_processed_delta,
        case when sum(a.executions_delta) > 0 
                then round(sum(a.rows_processed_delta) / sum(a.executions_delta), 1) end as rows_px,
        case when sum(a.fetches_delta) > 0
                then round(sum(a.rows_processed_delta) / sum(a.fetches_delta), 1) end as rows_per_fetch,
        round(sum(a.elapsed_time_delta) / power(10, 6)) as elapsed_time_delta_s,
        round(sum(sum(a.elapsed_time_delta)) 
                over (partition by a.dbid, a.instance_number, a.force_matching_signature,
                        case when force_matching_signature = 0 then a.sql_id end) 
                / power(10, 6)) as sig_elapsed_time_delta_s,
        case when sum(a.executions_delta) > 0 
                then round(sum(a.elapsed_time_delta) / power(10, 3) / sum(a.executions_delta), 2) end as ela_ms_px,
        round(sum(a.cpu_time_delta) / power(10, 6)) as cpu_time_delta_s,
        case when sum(a.executions_delta) > 0 
                then round(sum(a.cpu_time_delta) / power(10, 3) / sum(a.executions_delta), 2) end as cpu_ms_px,
        sum(a.buffer_gets_delta) as buffer_gets_delta,
        case when sum(a.executions_delta) > 0 
                then round(sum(a.buffer_gets_delta) / sum(a.executions_delta), 1) end as buf_px,
        case when sum(a.rows_processed_delta) > 0
                then sum(a.buffer_gets_delta) / sum(a.rows_processed_delta) end as bufs_per_row,
        round(sum(a.iowait_delta) / power(10, 6)) as iowait_delta_s,
        case when sum(a.executions_delta) > 0 
                then round(sum(a.iowait_delta) / power(10, 3) / sum(a.executions_delta), 2) end as iowait_ms_px,
        round(sum(a.ccwait_delta) / power(10, 6)) as ccwait_delta_s,
        case when sum(a.executions_delta) > 0 
                then round(sum(a.ccwait_delta) / power(10, 3) / sum(a.executions_delta), 2) end as ccwait_ms_px,
        round(sum(a.apwait_delta) / power(10, 6)) as apwait_delta_s,
        case when sum(a.executions_delta) > 0 
                then round(sum(a.apwait_delta) / power(10, 3) / sum(a.executions_delta), 2) end as apwait_ms_px,
        round(sum(a.clwait_delta) / power(10, 6)) as clwait_delta_s,
        case when sum(a.executions_delta) > 0 
                then round(sum(a.clwait_delta) / power(10, 3) / sum(a.executions_delta), 2) end as clwait_ms_px,
        round(sum(a.plsexec_time_delta) / power(10, 6)) as plsexec_time_delta_s,
        case when sum(a.executions_delta) > 0 
                then round(sum(a.plsexec_time_delta) / power(10, 3) / sum(a.executions_delta), 2) end as plsexec_ms_px,
        round(sum(a.javexec_time_delta) / power(10, 6)) as javexec_time_delta_s,
        case when sum(a.executions_delta) > 0 
                then round(sum(a.javexec_time_delta) / power(10, 3) / sum(a.executions_delta), 2) end as javaexec_ms_px,
        sum(a.direct_writes_delta) as direct_writes_delta,
        sum(a.sorts_delta) as sorts_delta,
        sum(a.disk_reads_delta) as disk_reads_delta,
        round(sum(a.physical_read_bytes_delta) / power(2, 20)) as phys_read_mb_delta,
        case when sum(a.executions_delta) > 0 
                then round(sum(a.physical_read_bytes_delta) / power(2, 20) / sum(a.executions_delta), 2) end 
            as phys_read_mb_px,
        sum(a.physical_read_requests_delta) as phys_read_req_delta,
        case when sum(a.executions_delta) > 0 
                then round(sum(a.physical_read_requests_delta) / sum(a.executions_delta), 2) end 
            as phys_read_req_px,
        sum(a.optimized_physical_reads_delta) as optim_phys_reads_delta,
        round(sum(a.physical_write_bytes_delta) / power(2, 20)) as phys_write_mb_delta,
        case when sum(a.executions_delta) > 0 
                then round(sum(a.physical_write_bytes_delta) / power(2, 20) / sum(a.executions_delta), 2) end 
            as phys_write_mb_px,
        sum(a.physical_write_requests_delta) as phys_write_req_delta,
        case when sum(a.executions_delta) > 0 
                then round(sum(a.physical_write_requests_delta) / sum(a.executions_delta), 2) end 
            as phys_write_req_px,
        round(sum(a.io_interconnect_bytes_delta)  / power(2, 20)) as io_interconnect_mb_delta,
        round(sum(a.io_offload_elig_bytes_delta) / power(2, 20)) as io_offload_elig_mb_delta,
        round(sum(a.io_offload_return_bytes_delta) / power(2, 20)) as io_offload_return_mb_delta,
        round(sum(a.cell_uncompressed_bytes_delta) / power(2, 20)) as cell_uncompressed_mb_delta,
        round(sum(decode(max(d.command_name), 'PL/SQL EXECUTE', 0, 'CALL METHOD', 0,
                sum(a.elapsed_time_delta) / power(10, 6))) over ()) as captured_sql_time_s,
        round(sum(sum(a.plsexec_time_delta) / power(10, 6)) over ()) as captured_plsql_time_s
    from
        dba_hist_sqlstat a,
        dba_hist_snapshot b,
        dba_hist_sqltext c,
        v$sqlcommand d
    where
        a.dbid = b.dbid and a.instance_number = b.instance_number and a.snap_id = b.snap_id
        and a.dbid = c.dbid and a.sql_id = c.sql_id
        and (:SQL_TEXT_RE is null or regexp_like(c.sql_text, :SQL_TEXT_RE, 'i'))
        and (:SQL_TEXT_LIKE is null or upper(c.sql_text) like upper(:SQL_TEXT_LIKE))
        and c.command_type = d.command_type (+)
        and a.dbid = nvl(:DBID, (select dbid from v$database))
        and ((:INST_ID is null and a.instance_number = sys_context('USERENV', 'INSTANCE'))
            or a.instance_number = :INST_ID)
        and b.begin_interval_time >= to_date(:FROM_TIME, 'YYYY-MM-DD HH24') - 1/24/4
        and b.end_interval_time <= (case when :TO_TIME is not null 
                                        then to_date(:TO_TIME, 'YYYY-MM-DD HH24') + 1/24/4
                                        else sysdate end)
    group by
        a.dbid,
        a.instance_number,
        a.force_matching_signature,
        a.plan_hash_value,
        case when force_matching_signature = 0 then a.sql_id end
),
hist_sqlstat2 as (
    select
        case when sum(decode(command_name, 'PL/SQL EXECUTE', 0, 'CALL METHOD', 0, 
                    elapsed_time_delta_s)) over () > 0
            then round(100 * elapsed_time_delta_s
                    / sum(decode(command_name, 'PL/SQL EXECUTE', 0, 'CALL METHOD', 0,
                            elapsed_time_delta_s)) over (), 1)
            end as pct_dbtime,
        case when sum(decode(command_name, 'PL/SQL EXECUTE', 0, 'CALL METHOD', 0,
                    elapsed_time_delta_s)) over () > 0
            then round(100 * sum(decode(command_name, 'PL/SQL EXECUTE', 0, 'CALL METHOD', 0,
                                        elapsed_time_delta_s))
                                    over (order by elapsed_time_delta_s desc) 
                    / sum(decode(command_name, 'PL/SQL EXECUTE', 0, 'CALL METHOD', 0,
                            elapsed_time_delta_s)) over (), 1)
            end as tot_pct_dbtime,
        dbid,
        force_matching_signature,
        plan_hash_value,
        min_begin_interval_time,
        max_end_interval_time,
        samp_sql_id,
        command_name,
        parsing_schema_name,
        module,
        action,
        invalidations_delta,
        parse_calls_delta,
        loads_delta,
        executions_delta,
        end_of_fetch_px,
        fetch_px,
        rows_px,
        rows_per_fetch,
        ela_ms_px,
        cpu_ms_px,
        buffer_gets_delta,
        buf_px,
        bufs_per_row,
        iowait_ms_px,
        ccwait_ms_px,
        apwait_ms_px,
        clwait_ms_px,
        plsexec_ms_px,
        javaexec_ms_px,
        phys_read_mb_px,
        phys_read_req_px,
        phys_write_mb_px,
        phys_write_req_px,
        elapsed_time_delta_s,
        sig_elapsed_time_delta_s,
        cpu_time_delta_s,
        iowait_delta_s,
        ccwait_delta_s,
        apwait_delta_s,
        clwait_delta_s,
        plsexec_time_delta_s,
        javexec_time_delta_s,
        direct_writes_delta,
        sorts_delta,
        disk_reads_delta,
        phys_read_mb_delta,
        phys_read_req_delta,
        optim_phys_reads_delta,
        phys_write_mb_delta,
        phys_write_req_delta,
        io_interconnect_mb_delta,
        io_offload_elig_mb_delta,
        io_offload_return_mb_delta,
        cell_uncompressed_mb_delta,
        captured_sql_time_s,
        captured_plsql_time_s
    from
        hist_sqlstat
    where
        lnnvl(upper(:EXCLUDE_PLSQL) = 'Y') 
            or command_name is null
            or command_name not in ('PL/SQL EXECUTE', 'CALL METHOD')
)
select
    a.pct_dbtime,
    a.tot_pct_dbtime,
    a.parsing_schema_name,
    a.module,
    a.action,
    a.command_name,
    a.force_matching_signature,
    a.samp_sql_id as sql_id,
    a.plan_hash_value,
    to_char(min_begin_interval_time, 'DD/MM HH24:MI') as begin_time,
    to_char(max_end_interval_time, 'DD/MM HH24:MI') as end_time,
    a.executions_delta,
    a.end_of_fetch_px,
    a.fetch_px,
    a.rows_px,
    a.rows_per_fetch,
    a.ela_ms_px,
    a.cpu_ms_px,
    a.iowait_ms_px,
    a.ccwait_ms_px,
    a.apwait_ms_px,
    a.buf_px,
    to_char(a.bufs_per_row, '9.9EEEE') as bufs_per_rows,
    a.clwait_ms_px,
    a.plsexec_ms_px,
    a.javaexec_ms_px,
    b.sql_text,
    a.phys_read_mb_px,
    a.phys_read_req_px,
    a.phys_write_mb_px,
    a.phys_write_req_px,
    a.invalidations_delta,
    a.parse_calls_delta,
    a.loads_delta,
    a.elapsed_time_delta_s,
    a.cpu_time_delta_s,
    a.iowait_delta_s,
    a.ccwait_delta_s,
    a.apwait_delta_s,
    a.clwait_delta_s,
    a.plsexec_time_delta_s,
    a.javexec_time_delta_s,
    a.direct_writes_delta,
    a.sorts_delta,
    a.buffer_gets_delta,
    a.disk_reads_delta,
    a.phys_read_mb_delta,
    a.phys_read_req_delta,
    a.optim_phys_reads_delta,
    a.phys_write_mb_delta,
    a.phys_write_req_delta,
    a.io_interconnect_mb_delta,
    a.io_offload_elig_mb_delta,
    a.io_offload_return_mb_delta,
    a.cell_uncompressed_mb_delta,
    a.captured_sql_time_s,
    a.captured_plsql_time_s,
    c.dbtime_s as total_dbtime_s,
    case when c.dbtime_s > 0
        then round(100 * (a.captured_sql_time_s + a.captured_plsql_time_s) / c.dbtime_s) 
        end as capture_pct
from
    hist_sqlstat2 a,
    dba_hist_sqltext b,
    hist_dbtime c
where
    a.dbid = b.dbid (+)
    and a.samp_sql_id = b.sql_id (+)
order by
    a.sig_elapsed_time_delta_s desc,
    a.force_matching_signature,
    a.elapsed_time_delta_s desc,
    a.samp_sql_id
;
