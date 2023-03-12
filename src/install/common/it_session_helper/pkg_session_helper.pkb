create or replace package body pkg_session_helper as

    gc_role_dba             constant t_role_name := 'DBA';
    gc_role_select_catalog  constant t_role_name := 'SELECT_CATALOG_ROLE';

    e_insufficient_privileges exception;
    pragma exception_init (e_insufficient_privileges, -1031);
        
    cursor c_session_info (p_sid in number, p_serial# in number) is
        select
            ses.sid,
            ses.serial#,
            ses.logon_time,
            ses.user#,
            ses.username,
            ses.module,
            ses.action
        from
            sys.v_$session ses
        where
            ses.sid = p_sid
            and ses.serial# = p_serial#;

    subtype t_rec_session_info is c_session_info %rowtype;           


    function is_role_enabled (p_role_name in varchar2) return boolean
    is
    begin
       $if dbms_db_version.version < 12 
           or (dbms_db_version.version = 12 and dbms_db_version.release = 1)
       $then
        return sys_context('SYS_SESSION_ROLES', p_role_name) = 'TRUE';
       $elsif dbms_db_version.version < 19
       $then
        return dbms_session.is_role_enabled(
                dbms_assert.enquote_name(p_role_name, capitalize => false));
       $else
        return dbms_session.session_is_role_enabled(
                dbms_assert.enquote_name(p_role_name, capitalize => false));
       $end
    end is_role_enabled;
    

    function is_session_role_enabled (p_role_name in varchar2) return varchar2
    is begin
        return case
                   when is_role_enabled(p_role_name) then
                       'TRUE'
                   else
                       'FALSE'
               end;
    end is_session_role_enabled;


    function has_one_prefixed_role (p_role_prefix in varchar2) return boolean
    is
        cursor c_prefixed_roles(p_prefix in varchar2) is
            select
                r.role
            from 
                sys.dba_roles r
            where
                r.role like p_prefix || ':%';

        l_role t_role_name;
        l_is_found boolean := false;
    begin
        open c_prefixed_roles(p_role_prefix);
        <<roles_loop>>
        loop
            fetch c_prefixed_roles into l_role;
            exit when c_prefixed_roles%notfound;
            if is_role_enabled(l_role) then
                l_is_found := true;
                exit roles_loop;
            end if;
        end loop roles_loop;
        close c_prefixed_roles;
        return l_is_found;
    exception
        when others then
            if c_prefixed_roles%isopen then
                close c_prefixed_roles;
            end if;
            raise;
    end has_one_prefixed_role;
    
               
    function userid_for_username (p_username in varchar2) return all_users.user_id %type
    is
        l_user_id all_users.user_id %type;
    begin
        select
            u.user_id into l_user_id
        from
            sys.all_users u
        where
            u.username = p_username;
        return l_user_id;
    end userid_for_username;


    function sessions_detail(
        p_username           in varchar2  default sys_context('USERENV', 'SESSION_USER'),
        p_inst_id            in number    default sys_context('USERENV', 'INSTANCE'),
        p_exclude_self       in varchar2  default 'Y',
        p_exclude_background in varchar2  default 'Y'
    )
    return t_tab_session_detail
    pipelined
    is
        cursor c_sessions_detail (
            p_user_id             in number, 
            p_inst_id             in number,
            p_exclude_self        in varchar2,
            p_exclude_background  in varchar2
        )
        is
        with
            live_sessions as (
                select
                    se.inst_id,
                    se.sid, 
                    se.serial#,
                    se.service_name,
                    se.type,
                    case
                        when se.type = 'BACKGROUND'
                            and se.time_remaining_micro is not null
                            and se.state = 'WAITING'
                            and se.wait_class = 'Idle'
                        then
                            null
                        else
                            se.status
                    end  as status,
                    cm.command_name  as command,
                    se.user#,
                    se.username,
                    se.schemaname,
                    se.osuser,
                    se.process,             -- Foreground: client OS process id
                    se.machine,             -- Foreground: client OS machine name
                    se.program,             -- Foreground: client program name
                    se.logon_time,
                    se.module,
                    se.action,
                    se.client_identifier,
                    se.client_info,
                    se.sql_id,
                    case
                        when se.sql_id is null then
                            null
                        else
                            se.sql_child_number
                    end  as sql_child_number,
                    se.sql_exec_id,
                    se.sql_exec_start,
                    se.prev_sql_id,
                    case
                        when se.prev_sql_id is null then
                            null
                        else
                            se.prev_child_number
                    end  as prev_child_number,
                    se.prev_exec_id,
                    se.prev_exec_start,
                    tc.top_level_call_name,
                    se.last_call_et,
                    case
                        when se.time_remaining_micro is null then
                            'ON CPU' 
                        else
                            se.state
                    end  as state,
                    se.wait_class,
                    se.event,
                    round(se.wait_time_micro / power(10, 3), 1)             as wait_time_ms,
                    round(se.time_remaining_micro / power(10, 3), 1)        as time_remaining_ms,
                    round(se.time_since_last_wait_micro / power(10, 3), 1)  as time_since_last_wait_ms,
                    se.plsql_entry_object_id,
                    se.plsql_entry_subprogram_id,
                    se.plsql_object_id,
                    se.plsql_subprogram_id,
                    se.pdml_status,
                    se.pddl_status,
                    se.pq_status,
                    case
                        when px.qcsid is null then 
                            'N' 
                        else
                            'Y' 
                    end  as is_px_qry,
                    case
                        when px.qcsid = se.sid 
                            and lnnvl(px.qcinst_id <> sys_context('USERENV', 'INSTANCE')) 
                        then
                            'Y' 
                        when px.qcsid is not null then
                            'N'
                    end  as is_px_qc,
                    px.qcinst_id,
                    px.qcsid,
                    px.qcserial#, 
                    se.blocking_session_status,
                    se.blocking_instance,
                    se.blocking_session,
                    se.sql_trace,
                    se.sql_trace_waits,
                    se.sql_trace_binds,
                    se.sql_trace_plan_stats,
                    se.ecid,
                    se.resource_consumer_group
                   $if dbms_db_version.version >= 12 $then
                    , se.con_id
                   $end
                from
                    gv$session se,
                    gv$px_session px,
                    v$sqlcommand cm,
                    v$toplevelcall tc
                where
                    se.inst_id = px.inst_id (+)
                    and se.saddr = px.saddr (+)
                    and se.command = cm.command_type (+)
                    and se.top_level_call# = tc.top_level_call# (+)
                    and 1 = (case
                                when p_inst_id is null then
                                    1
                                when se.inst_id = p_inst_id then
                                    1
                             end)
                    and 1 = (case
                                when p_user_id is null then
                                    1
                                when se.user# = p_user_id then
                                    1
                             end)
                    and 1 = (case
                                when lnnvl(upper(p_exclude_background) = 'Y') then
                                    1
                                when se.type = 'BACKGROUND' then
                                    0
                                else
                                    1
                             end)
            ),
            ash_sessions_last_20s as (
                select
                    ash1.inst_id,
                    ash1.session_id,
                    ash1.session_serial#,
                    ash1.cnt_samp,
                    ash1.cnt_sql_exec,
                    ash1.cnt_xid,
                    ash1.in_parse,
                    ash1.in_hard_parse,
                    ash1.cnt_ecid,
                    case
                        when ash1.tm_delta_cpu_time_ratio < power(10,-3) then
                            0
                        else
                            ash1.tm_delta_cpu_time_ratio
                    end  as tm_delta_cpu_time_ratio,
                    case
                        when ash1.tm_delta_db_time_ratio < power(10,-3) then
                            0
                        else
                            ash1.tm_delta_db_time_ratio
                    end  as tm_delta_db_time_ratio,
                    ash1.delta_read_iops,
                    ash1.delta_write_iops,
                    ash1.delta_iops,
                    ash1.delta_read_mbps,
                    ash1.delta_write_mbps,
                    ash1.delta_interconnect_mbps,
                    ash1.pga_allocated_mb,
                    ash1.temp_space_allocated_mb
                from
                    (select
                        ash.inst_id,
                        ash.session_id,
                        ash.session_serial#,
                        ash.cnt_samp,
                        ash.cnt_sql_exec,
                        ash.cnt_xid,
                        ash.in_parse,
                        ash.in_hard_parse,
                        ash.cnt_ecid,
                        ash.tm_delta_cpu_time
                                / greatest(nullif(ash.tm_delta_time, 0),
                                           19 * power(10,6))                as tm_delta_cpu_time_ratio,
                        ash.tm_delta_db_time
                                / greatest(nullif(ash.tm_delta_time, 0),
                                           19 * power(10,6))                as tm_delta_db_time_ratio,
                        ash.delta_read_io_requests 
                                * power(10, 6) 
                                / greatest(nullif(ash.delta_time, 0), 
                                           19 * power(10,6))                as delta_read_iops,
                        ash.delta_write_io_requests
                                * power(10, 6) 
                                / greatest(nullif(ash.delta_time, 0),
                                           19 * power(10,6))                as delta_write_iops,
                        (ash.delta_read_io_requests + ash.delta_write_io_requests)
                                * power(10, 6) 
                                / greatest(nullif(ash.delta_time, 0),
                                           19 * power(10,6))                as delta_iops,
                        ash.delta_read_io_bytes
                                * power(10, 6)
                                / greatest(nullif(ash.delta_time, 0),
                                           19 * power(10,6))
                                / power(2, 20)                              as delta_read_mbps,
                        ash.delta_write_io_bytes
                                * power(10, 6)
                                / greatest(nullif(ash.delta_time, 0),
                                           19 * power(10,6))
                                / power(2, 20)                              as delta_write_mbps,
                        ash.delta_interconnect_io_bytes
                                * power(10, 6)
                                / greatest(nullif(ash.delta_time, 0),
                                           19 * power(10,6))
                                / power(2, 20)                              as delta_interconnect_mbps,
                        ash.pga_allocated / power(2, 20)                    as pga_allocated_mb,
                        ash.temp_space_allocated / power(2, 20)             as temp_space_allocated_mb
                    from
                        (select
                            a.inst_id,
                            a.session_id,
                            a.session_serial#,
                            count(*)  as cnt_samp,
                            count(distinct case
                                               when a.is_sqlid_current = 'Y' then
                                                   to_char(a.inst_id) || ':' || a.sql_id 
                                                   || ',' || to_char(a.sql_exec_id)
                                                   || ',' || to_char(a.sql_exec_start, 
                                                                     'YYYYMMDDHH24MISS')
                                           end)                                       as cnt_sql_exec,
                            count(distinct a.xid)                                     as cnt_xid,
                            max(a.in_parse)
                                    keep (dense_rank first order by a.sample_id desc) as in_parse,
                            max(a.in_hard_parse)
                                    keep (dense_rank first order by a.sample_id desc) as in_hard_parse,
                            count(distinct a.ecid)                                    as cnt_ecid,
                            sum(a.tm_delta_time)                                      as tm_delta_time,
                            sum(a.tm_delta_cpu_time)                                  as tm_delta_cpu_time,
                            sum(a.tm_delta_db_time)                                   as tm_delta_db_time,
                            sum(a.delta_time)                                         as delta_time,
                            sum(a.delta_read_io_requests)                             as delta_read_io_requests,
                            sum(a.delta_write_io_requests)                            as delta_write_io_requests,
                            sum(a.delta_read_io_bytes)                                as delta_read_io_bytes,
                            sum(a.delta_write_io_bytes)                               as delta_write_io_bytes,
                            sum(a.delta_interconnect_io_bytes)                        as delta_interconnect_io_bytes,
                            max(a.pga_allocated)
                                    keep (dense_rank first order by a.sample_id desc) as pga_allocated,
                            max(a.temp_space_allocated)
                                    keep (dense_rank first order by a.sample_id desc) as temp_space_allocated
                        from
                            gv$active_session_history a
                        where
                            a.sample_time >= localtimestamp - numtodsinterval(20, 'SECOND')
                            and 1 = (case
                                        when p_inst_id is null then
                                            1
                                        when a.inst_id = p_inst_id then
                                            1
                                     end)
                            and 1 = (case
                                        when p_user_id is null then
                                            1
                                        when a.user_id = p_user_id then
                                            1
                                     end)
                            and 1 = (case
                                        when lnnvl(upper(p_exclude_background) = 'Y') then
                                            1
                                        when a.session_type = 'BACKGROUND' then
                                            0
                                        else
                                            1
                                     end)
                        group by
                            a.inst_id,
                            a.session_id,
                            a.session_serial#
                        ) ash
                    ) ash1
            ),
            live_sessions_wt_ash20s as (
                select
                    liv.inst_id,
                   $if dbms_db_version.version >= 12 $then
                    liv.con_id,
                   $end
                    liv.service_name,
                    liv.sid,
                    liv.serial#,
                    liv.type,
                    liv.status,
                    ash.cnt_samp                        as ash_cnt_samp,
                    100 * ash.tm_delta_cpu_time_ratio   as avg_cpu_pct,
                    100 * ash.tm_delta_db_time_ratio    as avg_activ_pct,
                    ash.cnt_sql_exec                    as ash_cnt_sql_exec,
                    nullif(ash.cnt_xid, 0)              as ash_cnt_xid,
                    liv.command,
                    -- fix username for background sessions
                    case
                        when liv.username is null and liv.user# = 0 then
                            'SYS'
                        else
                            liv.username
                    end as username,
                    liv.schemaname,
                    liv.osuser,
                    liv.process,
                    liv.machine,
                    liv.program,
                    liv.logon_time,
                    liv.module,
                    liv.action,
                    liv.client_identifier,
                    liv.client_info,
                    liv.sql_id,
                    liv.sql_child_number,
                    liv.sql_exec_id,
                    liv.sql_exec_start,
                    liv.prev_sql_id,
                    liv.prev_child_number,
                    liv.prev_exec_id,
                    liv.prev_exec_start,
                    liv.top_level_call_name,
                    liv.last_call_et,
                    liv.state,
                    liv.wait_class,
                    liv.event,
                    liv.wait_time_ms,
                    liv.time_remaining_ms,
                    liv.time_since_last_wait_ms,
                    liv.plsql_entry_object_id,
                    liv.plsql_entry_subprogram_id,
                    liv.plsql_object_id,
                    liv.plsql_subprogram_id,
                    liv.ecid,
                    nullif(ash.cnt_ecid, 0)             as ash_cnt_ecid,
                    liv.pdml_status,
                    liv.pddl_status,
                    liv.pq_status,
                    liv.is_px_qry,
                    liv.is_px_qc,
                    liv.qcinst_id                       as qc_inst_id,
                    liv.qcsid                           as qc_sid,
                    liv.qcserial#                       as qc_serial#, 
                    liv.blocking_session_status,
                    liv.blocking_instance               as blocking_inst_id,
                    liv.blocking_session,
                    liv.sql_trace,
                    liv.sql_trace_waits,
                    liv.sql_trace_binds,
                    liv.sql_trace_plan_stats,
                    liv.resource_consumer_group,
                    ash.in_parse,
                    ash.in_hard_parse,
                    nullif(ash.delta_read_iops, 0)           as avg_read_iops,
                    nullif(ash.delta_write_iops, 0)          as avg_write_iops,
                    nullif(ash.delta_read_mbps, 0)           as avg_read_mbps,
                    nullif(ash.delta_write_mbps, 0)          as avg_write_mbps,
                    nullif(ash.delta_interconnect_mbps, 0)   as avg_interconnect_mbps,
                    nullif(ash.pga_allocated_mb, 0)          as ash_pga_alloc_mb,
                    nullif(ash.temp_space_allocated_mb, 0)   as ash_temp_space_mb
                from
                    live_sessions liv,
                    ash_sessions_last_20s ash
                where
                    liv.inst_id = ash.inst_id (+)
                    and liv.sid = ash.session_id (+)
                    and liv.serial# = ash.session_serial# (+)
            )
            select
                det.inst_id,
               $if dbms_db_version.version >= 12 $then
                det.con_id,
                det.con_name,
               $end
                det.service_name,
                det.sid,
                det.serial#,
                det.type,
                det.status,
                det.ash_cnt_samp,
                case
                    when det.avg_cpu_pct = 0 then
                        0
                    else
                        round( det.avg_cpu_pct,
                               greatest(0, 2 - floor(log(10, abs(det.avg_cpu_pct)))) )
                end  as avg_cpu_pct,
                case
                    when det.avg_activ_pct = 0 then
                        0
                    else
                        round( det.avg_activ_pct,
                               greatest(0, 2 - floor(log(10, abs(det.avg_activ_pct)))) )
                end  as avg_activ_pct,
                det.ash_cnt_sql_exec,
                det.ash_cnt_xid,
                det.ash_cnt_ecid,
                det.command,
                det.username,
                det.schemaname,
                det.osuser,
                det.process,
                det.machine,
                det.program,
                det.logon_time,
                det.module,
                det.action,
                det.client_identifier,
                det.client_info,
                det.ecid,
                det.sql_id,
                det.sql_child_number,
                det.sql_exec_id,
                det.sql_exec_start,
                det.in_parse,
                det.in_hard_parse,
                det.prev_sql_id,
                det.prev_child_number,
                det.prev_exec_id,
                det.prev_exec_start,
                det.top_level_call_name,
                det.last_call_et,
                det.state,
                det.wait_class,
                det.event,
                det.wait_time_ms,
                det.time_remaining_ms,
                det.time_since_last_wait_ms,
                det.plsql_entry_object_id,
                det.plsql_entry_subprogram_id,
                det.plsql_object_id,
                det.plsql_subprogram_id,
                det.pdml_status,
                det.pddl_status,
                det.pq_status,
                det.is_px_qry,
                det.is_px_qc, 
                det.qc_inst_id,
                det.qc_sid,
                det.qc_serial#,
                det.blocking_session_status,
                det.blocking_inst_id,
                det.blocking_session,
                det.sql_trace,
                det.sql_trace_waits,
                det.sql_trace_binds,
                det.sql_trace_plan_stats,
                det.resource_consumer_group,
                case 
                    when det.avg_read_iops = 0 then
                        0
                    else 
                        round( det.avg_read_iops,
                               greatest(0, 2 - floor(log(10, abs(det.avg_read_iops)))) )
                end  as avg_read_iops,
                case 
                    when det.avg_write_iops = 0 then
                        0
                    else
                        round( det.avg_write_iops,
                               greatest(0, 2 - floor(log(10, abs(det.avg_write_iops)))) )
                end  as avg_write_iops,
                case 
                    when det.avg_read_mbps = 0 then
                        0
                    else
                        round( det.avg_read_mbps,
                               greatest(0, 2 - floor(log(10, abs(det.avg_read_mbps)))) )
                end  as avg_read_mbps,
                case 
                    when det.avg_write_mbps = 0 then
                        0
                    else
                        round( det.avg_write_mbps,
                               greatest(0, 2 - floor(log(10, abs(det.avg_write_mbps)))) )
                end  as avg_write_mbps,
                case 
                    when det.avg_interconnect_mbps = 0 then
                        0
                    else
                        round( det.avg_interconnect_mbps,
                               greatest(0, 2 - floor(log(10, abs(det.avg_interconnect_mbps)))) )
                end  as avg_interconnect_mbps,
                case 
                    when det.ash_pga_alloc_mb = 0 then
                        0
                    else
                        round( det.ash_pga_alloc_mb,
                               greatest(0, 2 - floor(log(10, abs(det.ash_pga_alloc_mb)))) )
                end  as ash_pga_alloc_mb,
                case 
                    when det.ash_temp_space_mb = 0 then
                        0
                    else
                        round( det.ash_temp_space_mb,
                               greatest(0, 2 - floor(log(10, abs(det.ash_temp_space_mb)))) )
                end  as ash_temp_space_mb
            from
               $if dbms_db_version.version >= 12 $then
                (select
                    s.*,
                    case
                        when s.con_id = 1 then
                            'CDB$ROOT'
                        else
                            pdb.name
                    end  as con_name
                from
                    live_sessions_wt_ash20s s,
                    gv$pdbs pdb
                where
                    s.inst_id = pdb.inst_id (+)
                    and s.con_id = pdb.con_id (+)
                ) det
               $else
                live_sessions_wt_ash20s det
               $end
            where 1 = 1
                and 1 = (case
                             when lnnvl(upper(p_exclude_self) = 'Y') then
                                1
                             when det.inst_id = to_number(sys_context('USERENV', 'INSTANCE'))
                                and det.sid = to_number(sys_context('USERENV', 'SID'))
                             then
                                0
                             when det.qc_inst_id = to_number(sys_context('USERENV', 'INSTANCE'))
                                and det.qc_sid = to_number(sys_context('USERENV', 'SID'))
                             then
                                0
                             else
                                1
                         end)
            order by
                decode(det.type, 'USER', 1, 'BACKGROUND', 2),
                det.inst_id,
                det.sid;

        subtype t_username        is all_users.username%type;
        type t_tab_per_user_indic is table of pls_integer index by t_username;

        l_user_id             all_users.user_id %type;
        l_rec_sess_detail     t_rec_session_detail;
        
        l_tab_canview_user    t_tab_per_user_indic;
        l_can_view_all_users  boolean;
        
        function can_view_sessions_of(p_username in varchar2)
        return boolean
        is
            l_can_view_session boolean;
        begin
            if l_tab_canview_user.exists(p_username) then
                l_can_view_session := (l_tab_canview_user(p_username) = 1);
            else
                l_can_view_session := is_role_enabled(gc_role_select_catalog)
                        or ( p_username = sys_context('USERENV', 'SESSION_USER')
                             and ( is_role_enabled(gc_role_view_session_self)
                                   or is_role_enabled(gc_role_end_session_self) ) 
                           )
                        or is_role_enabled(gc_role_view_session_prefix || ':' || p_username)
                        or is_role_enabled(gc_role_end_session_prefix || ':' || p_username)
                        or sys_context('USERENV', 'SESSION_USER') = 'SYS';
                l_tab_canview_user(p_username) :=
                        case when l_can_view_session then 1 else 0 end;
            end if;
            return l_can_view_session;
        end can_view_sessions_of;

        function can_view_all_sessions return boolean
        is
        begin
            if l_can_view_all_users is null then
                l_can_view_all_users := is_role_enabled(gc_role_select_catalog)
                        or sys_context('USERENV', 'SESSION_USER') = 'SYS';
            end if;
            return l_can_view_all_users;
        end can_view_all_sessions;
        
    begin
        if p_username is not null then
            if not can_view_sessions_of(p_username) then
                raise e_insufficient_privileges;
            end if;
            l_user_id := userid_for_username(p_username);
        end if;
        open c_sessions_detail(l_user_id, p_inst_id, p_exclude_self, p_exclude_background);
        loop
            fetch c_sessions_detail into l_rec_sess_detail;
            exit when c_sessions_detail %notfound;
            if (l_rec_sess_detail.username is not null
                    and can_view_sessions_of(l_rec_sess_detail.username))
                or can_view_all_sessions
            then
                pipe row (l_rec_sess_detail);
            end if;
        end loop;
        close c_sessions_detail;
    exception
        when no_data_needed then
            close c_sessions_detail;
            raise;
    end sessions_detail;


    procedure lookup_session (
        p_session_id        in            number,
        p_session_serial#   in            number,
        p_session_info      in out nocopy t_rec_session_info
    )
    is
        l_is_not_found boolean;
    begin
        begin
            open c_session_info(p_session_id, p_session_serial#);
            fetch c_session_info into p_session_info;
            l_is_not_found := c_session_info%notfound;
            close c_session_info;
        exception
            when others then
                if c_session_info%isopen then
                    close c_session_info;
                end if;
                raise;
        end;
        if l_is_not_found then
            raise_application_error(-20000, 'session not found');
        end if;
    end lookup_session;
    

    procedure log_action(
        p_event_type        in  varchar2,
        p_session_info      in  t_rec_session_info,
        p_using_role        in  t_role_name,
        p_reason            in  varchar2,
        p_post_transaction  in  boolean,
        p_out_rowid         out rowid
    )
    is
        pragma autonomous_transaction;
        l_post_transaction varchar2(1);
    begin
        l_post_transaction := case when p_post_transaction then 'Y' end;
        insert into &&def_it_sess_helper_log_table log (
            seq_num,
            event_type,
            target_session_id,
            target_session_serial#,
            target_session_logon_time,
            target_session_userid,
            target_session_username,
            target_session_module,
            target_session_action,
            post_transaction,
            role_used,
            reason
        )
        values (
            seq_sess_helper.nextval,
            p_event_type,
            p_session_info.sid,
            p_session_info.serial#,
            p_session_info.logon_time,
            p_session_info.user#,
            p_session_info.username,
            p_session_info.module,
            p_session_info.action,
            l_post_transaction,
            p_using_role,
            p_reason
        )
        returning log.rowid into p_out_rowid;
        commit work;
    exception
        when others then
            if dbms_transaction.local_transaction_id is not null then
                rollback;
            end if;
            raise;
    end log_action;

    
    procedure log_action_result(
        p_rowid    in rowid,
        p_sqlcode  in number
    )
    is
        pragma autonomous_transaction;

        cursor c_action_row (p_rowid in rowid) is
            select
                log.sqlcode
            from
                &&def_it_sess_helper_log_table log
            where
                log.rowid = p_rowid
            for update nowait;
        
        l_dummy number;
    begin
        open c_action_row(p_rowid);
        fetch c_action_row into l_dummy;
        update &&def_it_sess_helper_log_table log set
            log.sqlcode = p_sqlcode
        where current of c_action_row;
        close c_action_row;
        commit;
    exception
        when others then
            if dbms_transaction.local_transaction_id is not null then
                rollback;
            end if;
            raise;
    end log_action_result;


    procedure wrap_dyn_exec (p_stmt in varchar2)
    is
    begin
        execute immediate p_stmt;
    end wrap_dyn_exec;
    

    procedure disconnect_session(
        p_session_id        in number,
        p_session_serial#   in number,
        p_reason            in varchar2  default null,
        p_post_transaction  in boolean   default false
    )
    is
        l_rec_sessinfo    t_rec_session_info;
        l_using_role_name t_role_name;
        l_log_rowid       rowid;

        function can_terminate_session (p_session_info in t_rec_session_info)
        return varchar2
        is
            l_role_end_session_for_user t_role_name;
        begin
            l_role_end_session_for_user := gc_role_end_session_prefix 
                    || ':' || p_session_info.username;
            return case
                       when is_role_enabled(gc_role_dba)
                       then
                           gc_role_dba
                       when p_session_info.user# = sys_context('USERENV', 'SESSION_USERID')
                           and is_role_enabled(gc_role_end_session_self)
                       then
                           gc_role_end_session_self
                       when is_role_enabled(l_role_end_session_for_user)
                       then
                           l_role_end_session_for_user
                       when sys_context('USERENV', 'SESSION_USER') = 'SYS' then
                           'SYSDBA'
                   end;
        end can_terminate_session;
    begin
        if not is_role_enabled(gc_role_dba)
            and sys_context('USERENV', 'SESSION_USER') <> 'SYS'
            and not is_role_enabled(gc_role_end_session_self)
            and not has_one_prefixed_role(gc_role_end_session_prefix)
        then
            raise e_insufficient_privileges;
        end if;
        
        lookup_session(p_session_id, p_session_serial#, l_rec_sessinfo);
        
        l_using_role_name := can_terminate_session(l_rec_sessinfo);
        if l_using_role_name is null then
            raise e_insufficient_privileges;
        end if;
        
        log_action(
            p_event_type        => 'KILL SESSION',
            p_session_info      => l_rec_sessinfo, 
            p_using_role        => l_using_role_name, 
            p_reason            => p_reason,
            p_post_transaction  => p_post_transaction,
            p_out_rowid         => l_log_rowid
        );
        
        <<dyn_exec_block>>
        begin
            wrap_dyn_exec(
                'alter system disconnect session ''' 
                    || to_char(l_rec_sessinfo.sid)
                    || ','
                    || to_char(l_rec_sessinfo.serial#)
                    || ''' '
                    || case
                           when p_post_transaction then
                               'post_transaction'
                           else
                               'immediate'
                       end
            );
            <<log_success_no_raise>>
            begin
                log_action_result(l_log_rowid, 0);
            exception
                when others then
                    null;   -- NOSONAR: G-5040
            end log_success_no_raise;
        exception
            when others then
                <<log_exception_no_raise>>
                begin
                    log_action_result(l_log_rowid, sqlcode);
                exception
                    when others then
                        null;   -- NOSONAR: G-5040
                end log_exception_no_raise;
                raise;
        end dyn_exec_block;
    end disconnect_session;

end pkg_session_helper;
/