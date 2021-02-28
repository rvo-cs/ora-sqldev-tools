/*---------------------------------------------------------------------------------------*/
/* V$SESSION */

select
    a.sid, 
    a.serial#, 
    --'alter system disconnect session ''' || a.sid || ',' || a.serial# || ''' immediate;' as kill_stmt,
    a.service_name,
    --a.server,
    a.type,
    a.status,
    a.username,
    a.schemaname,
    a.osuser,
    a.process,
    a.machine,
    a.program,
    a.logon_time,
    a.module,
    a.action,
    a.client_identifier,
    a.client_info,
    a.sql_id,
    a.sql_child_number,
    a.sql_exec_id,
    a.sql_exec_start,
    a.prev_sql_id,
    a.prev_child_number,
    a.prev_exec_id,
    a.prev_exec_start,
    a.top_level_call#,
    a.last_call_et,
    case when a.time_remaining_micro is null then 'ON CPU' else a.state end as state,
    a.wait_class,
    a.event,
    a.seconds_in_wait,      /* Deprecated, use time_remaining_micro and time_since_last_wait_micro */
    round(a.wait_time_micro / power(10, 3), 1) as wait_time_ms,
    round(a.time_remaining_micro / power(10, 3), 1) as time_remaining_ms,
    round(a.time_since_last_wait_micro / power(10, 3), 1) as time_since_last_wait_ms,
    a.pdml_enabled,
    a.pdml_status,
    a.pddl_status,
    a.pq_status,
    case when b.qcsid is null then 'N' else 'Y' end as is_px_qry,
    case when b.qcsid = a.sid and lnnvl(b.qcinst_id <> sys_context('USERENV', 'INSTANCE')) then 'Y' 
         when b.qcsid is not null then 'N' 
    end as is_px_qc,
    b.qcinst_id, b.qcsid, b.qcserial#, 
    a.blocking_session_status,
    a.blocking_instance,
    a.blocking_session,
    a.sql_trace,
    a.sql_trace_waits,
    a.sql_trace_binds,
    a.sql_trace_plan_stats
    , a.con_id
from
    v$session a, v$px_session b
where
    a.saddr = b.saddr (+)
    and a.type = 'USER'
    --and a.username = 'SYS'
    --and a.username = 'SCOTT'
;

/*---------------------------------------------------------------------------------------*/
/* DBMS_XPLAN */

select * from table(dbms_xplan.display_cursor('an40ab2d35q6z', 0, 'Advanced +adaptive -projection -qbregistry +allstats last'));
select * from table(dbms_xplan.display_cursor('091fb1shwqyn8', 0, 'Advanced +adaptive -projection -qbregistry -outline +allstats last'));

select * from table(dbms_xplan.display_awr('091fb1shwqyn8', null, null, 'Advanced -projection'));


/*=====================================================================================*/
/* On-going transactions */

select
    a.inst_id, a.con_id,
    b.sid, b.serial#, b.type, b.username,
    a.xid, a.status,
    a.used_ublk, a.used_urec, a.start_time,
    a.flag, a.space, a.recursive, a.noundo, a.ptx,
    b.program, b.module, b.action
from
    gv$transaction a,
    gv$session b
where
    a.inst_id = b.inst_id
    and a.ses_addr = b.saddr
;

/*=====================================================================================*/
/* Cursor cache (V$SQL) */

select
    a.sql_id, --a.address,
    a.child_number, --a.child_address,
    --a.hash_value, --a.old_hash_value,
    --a.service, --a.service_hash,
    --a.module, --a.module_hash,
    --a.action, a.action_hash,
    a.object_status,
    a.invalidations, a.loads, a.parse_calls,
    a.first_load_time, a.last_load_time, a.last_active_time,
    a.users_opening, a.users_executing,
    a.exact_matching_signature, a.force_matching_signature
    , a.is_resolved_adaptive_plan
    , a.full_plan_hash_value
    , a.plan_hash_value
    , a.executions, a.px_servers_executions as px_execs,
    a.fetches, a.end_of_fetch_count as eof_count,
    a.rows_processed,
    case when a.executions > 0 then round(a.rows_processed  / a.executions, 1) end  as rows_px,
    a.buffer_gets,
    case when a.executions > 0 then round(a.buffer_gets     / a.executions, 2) end  as buf_px,
    case when a.rows_processed > 0 then to_char(a.buffer_gets    / a.rows_processed, '0.9EEEE')   end   as bufs_per_row,
    case when a.executions > 0 then round(a.elapsed_time         / a.executions / power(10,3), 2) end   as ela_px_ms,
    case when a.executions > 0 then round(a.cpu_time             / a.executions / power(10,3), 2) end   as cpu_px_ms,
    case when a.executions > 0 then round(a.user_io_wait_time    / a.executions / power(10,3), 2) end   as iowait_px_ms,
    case when a.executions > 0 then round(a.application_wait_time/ a.executions / power(10,3), 2) end   as appwait_px_ms,
    case when a.executions > 0 then round(a.concurrency_wait_time/ a.executions / power(10,3), 2) end   as ccywait_px_ms,
    case when a.executions > 0 then round(a.cluster_wait_time    / a.executions / power(10,3), 2) end   as cluwait_px_ms,
    case when a.executions > 0 then round(a.plsql_exec_time      / a.executions / power(10,3), 2) end   as plsql_time_px_ms,
    case when a.executions > 0 then round(a.java_exec_time       / a.executions / power(10,3), 2) end   as java_time_ps_ms,
    --a.optimizer_mode, --a.optimizer_cost,
    --a.optimizer_env, --a.optimizer_env_hash_value,
    --a.sharable_mem, a.persistent_mem, a.runtime_mem, a.typecheck_mem,
    --a.type_chk_heap,
    --a.literal_hash_value,
    a.sorts,
    a.disk_reads
    , a.direct_reads, a.direct_writes
    , a.physical_read_requests,
    round(a.physical_read_bytes  / power(2,20), 2)   as phys_read_mb,
    a.physical_write_requests,
    round(a.physical_write_bytes / power(2,20), 2)   as phys_write_mb,
    --a.optimized_phy_read_requests,
    --a.io_interconnect_bytes, a.io_cell_uncompressed_bytes,
    --a.io_cell_offload_eligible_bytes, a.io_cell_offload_returned_bytes,
    --a.im_scans, a.im_scan_bytes_uncompressed, a.im_scan_bytes_inmemory,
    --a.parsing_user_id,
    --a.parsing_schema_id,
    c.username as parsing_user_name,
    a.parsing_schema_name,
    b.command_name, --a.command_type,
    a.sql_fulltext
    , a.is_reoptimizable
    , a.is_obsolete, a.is_bind_sensitive, a.is_bind_aware, a.is_shareable,
    --a.child_latch,
    --a.outline_category, --a.outline_sid,
    a.sql_profile, a.sql_patch, a.sql_plan_baseline,
    --a.program_id, a.program_line#,
    --a.bind_data,
    --a.result_cache /* Not in 12.2 */, 
    a.sqltype,
    a.remote,
    round(a.elapsed_time           / power(10,6), 1)   as elapsed_time_s,
    round(a.cpu_time               / power(10,6), 1)   as cpu_time_s,
    round(a.user_io_wait_time      / power(10,6), 1)   as user_io_wait_s,
    round(a.application_wait_time  / power(10,6), 1)   as app_wait_time_s,
    round(a.concurrency_wait_time  / power(10,6), 1)   as ccy_wait_time_s,
    round(a.cluster_wait_time      / power(10,6), 1)   as clus_wait_time_s,
    round(a.plsql_exec_time        / power(10,6), 1)   as plsql_exec_time_s,
    round(a.java_exec_time         / power(10,6), 1)   as java_exec_time_s,
    a.loaded_versions, a.open_versions, --a.kept_versions,
    a.locked_total, a.pinned_total,
    a.serializable_aborts
    --, a.ddl_no_invalidate, a.is_rolling_invalid, a.is_rolling_refresh_invalid,
    --a.sql_quarantine, a.avoided_executions,
    , a.con_id
from
    v$sql a,
    v$sqlcommand b,
    all_users c 
where
    1 = 1
    and a.command_type = b.command_type (+)
    and a.parsing_user_id = c.user_id (+)
    and a.sql_id = :SQL_ID
    --and regexp_like(a.sql_fulltext, 'v\$database', 'i')
order by 
    a.last_active_time desc
    --a.physical_read_bytes desc
--fetch first 10 row only
;
