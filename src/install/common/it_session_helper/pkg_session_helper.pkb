create or replace package body pkg_session_helper as

    gc_role_dba constant t_role_name := 'DBA';

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
        p_event_type        in varchar2,
        p_session_info      in t_rec_session_info,
        p_using_role        in t_role_name,
        p_reason            in varchar2,
        p_post_transaction  in boolean
    )
    is
        pragma autonomous_transaction;
        l_post_transaction varchar2(1);
    begin
        l_post_transaction := case when p_post_transaction then 'Y' end;
        insert into &&def_it_sess_helper_log_table (
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
        );
        commit work;
    exception
        when others then
            if dbms_transaction.local_transaction_id is not null then
                rollback;
            end if;
            raise;
    end log_action;


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

        function has_end_session_for_user_role return boolean
        is
            cursor c_end_session_roles is
                select
                    r.role
                from 
                    sys.dba_roles r
                where
                    r.role like gc_role_end_session_prefix || ':%';

            l_role t_role_name;
            l_is_found boolean := false;
        begin
            open c_end_session_roles;
            <<roles_loop>>
            loop
                fetch c_end_session_roles into l_role;
                exit when c_end_session_roles%notfound;
                if is_role_enabled(l_role) then
                    l_is_found := true;
                    exit roles_loop;
                end if;
            end loop roles_loop;
            close c_end_session_roles;
            return l_is_found;
        exception
            when others then
                if c_end_session_roles%isopen then
                    close c_end_session_roles;
                end if;
                raise;
        end has_end_session_for_user_role;

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
                   end;
        end can_terminate_session;
    begin
        if not is_role_enabled(gc_role_dba)
            and not is_role_enabled(gc_role_end_session_self)
            and not has_end_session_for_user_role
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
            p_post_transaction  => p_post_transaction
        );
        
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
    end disconnect_session;

end pkg_session_helper;
/