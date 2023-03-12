create or replace package pkg_session_helper authid definer as
/*
 * PACKAGE
 *      pkg_session_helper
 *
 * PURPOSE
 *      Procedures in this package enable users to perform privileged actions
 *      on sessions (theirs, or that of other users), provided they have been
 *      authorized to do so by granting them a role authorizing the action.
 *
 * SECURITY
 *      This package is AUTHID DEFINER, hence it runs with the privileges of
 *      its owner. Each procedure in this package runs its own security checks,
 *      and either denies or authorizes the action depending on roles enabled
 *      in the calling session. Therefore, EXECUTE permission on this package
 *      can be granted to PUBLIC.
 */

    subtype t_role_name is user_role_privs.granted_role %type;

    gc_role_view_session_self   constant t_role_name := '&&def_it_role_view_session_self';
    gc_role_view_session_prefix constant t_role_name := '&&def_it_role_view_session_prfx';

    gc_role_end_session_self    constant t_role_name := '&&def_it_role_end_session_self';
    gc_role_end_session_prefix  constant t_role_name := '&&def_it_role_end_session_prefix';

    /*
     * Record type for returning detailed session information, including
     * (if available) data from the last 20s in v$active_session_history
     */
    type t_rec_session_detail is record (
        inst_id                 sys.gv_$session.inst_id         %type,
       $if dbms_db_version.version >= 12 $then
        con_id                  sys.gv_$session.con_id          %type,
        con_name                sys.gv_$pdbs.name               %type,
       $end 
        service_name            sys.gv_$session.service_name    %type,
        sid                     sys.gv_$session.sid             %type,
        serial#                 sys.gv_$session.serial#         %type,
        type                    sys.gv_$session.type            %type,
        status                  sys.gv_$session.status          %type,
        ash_cnt_samp            number,
        avg_cpu_pct             number,
        avg_activ_pct           number,
        ash_cnt_sql_exec        number,
        ash_cnt_xid             number,
        ash_cnt_ecid            number,
        command                 sys.v_$sqlcommand.command_name  %type,
        username                sys.gv_$session.username        %type,
        schemaname              sys.gv_$session.schemaname      %type,
        osuser                  sys.gv_$session.osuser          %type,
        process                 sys.gv_$session.process         %type,
        machine                 sys.gv_$session.machine         %type,
        program                 sys.gv_$session.program         %type,
        logon_time              sys.gv_$session.logon_time      %type,
        module                  sys.gv_$session.module          %type,
        action                  sys.gv_$session.action          %type,
        client_identifier       sys.gv_$session.client_identifier %type,
        client_info             sys.gv_$session.client_info       %type,
        ecid                    sys.gv_$session.ecid              %type,
        sql_id                  sys.gv_$session.sql_id            %type,
        sql_child_number        sys.gv_$session.sql_child_number  %type,
        sql_exec_id             sys.gv_$session.sql_exec_id       %type,
        sql_exec_start          sys.gv_$session.sql_exec_start    %type,
        in_parse                sys.gv_$active_session_history.in_parse      %type,
        in_hard_parse           sys.gv_$active_session_history.in_hard_parse %type,
        prev_sql_id             sys.gv_$session.prev_sql_id       %type,
        prev_child_number       sys.gv_$session.prev_child_number %type,
        prev_exec_id            sys.gv_$session.prev_exec_id      %type,
        prev_exec_start         sys.gv_$session.prev_exec_start   %type,
        top_level_call_name     sys.v_$toplevelcall.top_level_call_name %type,
        last_call_et            sys.gv_$session.last_call_et    %type,
        state                   sys.gv_$session.state           %type,
        wait_class              sys.gv_$session.wait_class      %type,
        event                   sys.gv_$session.event           %type,
        wait_time_ms                number,
        time_remaining_ms           number,
        time_since_last_wait_ms     number,
        plsql_entry_object_id       sys.gv_$session.plsql_entry_object_id     %type,
        plsql_entry_subprogram_id   sys.gv_$session.plsql_entry_subprogram_id %type,
        plsql_object_id             sys.gv_$session.plsql_object_id           %type,
        plsql_subprogram_id         sys.gv_$session.plsql_subprogram_id       %type,
        pdml_status             sys.gv_$session.pdml_status     %type,
        pddl_status             sys.gv_$session.pddl_status     %type,
        pq_status               sys.gv_$session.pq_status       %type,
        is_px_qry               varchar2(1),
        is_px_qc                varchar2(1),
        qc_inst_id              sys.gv_$px_session.qcinst_id                 %type,
        qc_sid                  sys.gv_$px_session.qcsid                     %type,
        qc_serial#              sys.gv_$px_session.qcserial#                 %type, 
        blocking_session_status sys.gv_$session.blocking_session_status      %type,
        blocking_inst_id        sys.gv_$session.blocking_instance            %type,
        blocking_session        sys.gv_$session.blocking_session             %type,
        sql_trace               sys.gv_$session.sql_trace                    %type,
        sql_trace_waits         sys.gv_$session.sql_trace_waits              %type,
        sql_trace_binds         sys.gv_$session.sql_trace_binds              %type,
        sql_trace_plan_stats    sys.gv_$session.sql_trace_plan_stats         %type,
        resource_consumer_group sys.gv_$session.resource_consumer_group      %type,
        avg_read_iops           number,
        avg_write_iops          number,
        avg_read_mbps           number,
        avg_write_mbps          number,
        avg_interconnect_mbps   number,
        ash_pga_alloc_mb        number,
        ash_temp_space_mb       number
    );
    
    type t_tab_session_detail is table of t_rec_session_detail;
    
    /*
       Returns 1 line for each session of the specified user, iff the calling
       session user is authorized to retrieve information about such sessions,
       through an enabled role.
       
       Supported roles are as follows:
           . SELECT_CATALOG_ROLE
                Users having SELECT_CATALOG_ROLE may retrieve information
                about any session
           . IT_VIEW_SESS_SELF
                This role grants permission to retrieve information about
                one's own sessions
           . "IT_VIEW_SESS:username"
                This role grants permission to retrieve information about
                sessions of the specified username
           . IT_END_SESS_SELF
                Same as IT_VIEW_SESS_SELF above
           . "IT_END_SESS:username"
                Same as "IT_VIEW_SESS:username" above
     */
    function sessions_detail(
        p_username           in varchar2  default sys_context('USERENV', 'SESSION_USER'),
        p_inst_id            in number    default sys_context('USERENV', 'INSTANCE'),
        p_exclude_self       in varchar2  default 'Y',
        p_exclude_background in varchar2  default 'Y'
    )
    return t_tab_session_detail
    pipelined;
 
    /*
       Returns 'TRUE' if the specified role is enabled in the calling session,
       otherwise 'FALSE'.
     */
    function is_session_role_enabled (p_role_name in varchar2) return varchar2;

    /*
       Calls ALTER SYSTEM DISCONNECT SESSION on the specified session,
       iff the session user is authorized to do so through an enabled role.
        
       Supported roles are as follows:
          . DBA
                Users with the DBA role may terminate any session
          . IT_END_SESS_SELF
                This role grants permission to kill one's own sessions
          . "IT_END_SESS:username"
                This role grants the bearer permission to end sessions
                of the specified username
        
        The action is logged in the log table; callers are encouraged to
        supply a reason for terminating the target session.
     */
    procedure disconnect_session(
        p_session_id        in number,
        p_session_serial#   in number,
        p_reason            in varchar2  default null,
        p_post_transaction  in boolean   default false
    );

end pkg_session_helper;
/
