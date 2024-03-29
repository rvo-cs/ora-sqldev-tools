create or replace package body pkg_pub_datapump_log_viewer as
/*
 * SPDX-FileCopyrightText: 2023 R.Vassallo
 * SPDX-License-Identifier: Apache License 2.0
 */

    gc_sqlcode_app_error    constant number  := -20000;

    gc_fetch_size constant pls_integer := 100;

    e_not_exists exception;
    pragma exception_init(e_not_exists, -942);


    function datapump_job_log (
        p_owner_name  in varchar2,
        p_job_name    in varchar2
    )
    return tt_rec_datapump_log_file
    pipelined
    is
        l_operation user_datapump_jobs.operation %type;
        l_log_rec   t_rec_datapump_log_file;
        l_cv        sys_refcursor;
        
        function log_error (p_sqlcode in number, p_errmsg in varchar2)
        return t_rec_datapump_log_file
        is begin
            l_log_rec.sqlcode := p_sqlcode;
            l_log_rec.sqlerrm := 'ORA' || to_char(p_sqlcode, 'S00000') || ': ' || p_errmsg;
            return l_log_rec;
        end log_error;

        function log_error (p_errmsg in varchar2)
        return t_rec_datapump_log_file
        is begin
            return log_error(gc_sqlcode_app_error, p_errmsg);
        end log_error;

    begin
        /* Check arguments */
        if p_owner_name is null
            or p_job_name is null
        then
            raise_application_error(gc_sqlcode_app_error, 'bad argument(s)');
        end if;
    
        l_log_rec.job_owner := p_owner_name;
        l_log_rec.job_name  := p_job_name;
        
        /* Lookup the job in USER_DATAPUMP_JOBS or DBA_DATAPUMP_JOBS */
        begin
            if p_owner_name = sys_context('USERENV', 'CURRENT_USER') then
                execute immediate
                    q'{ select rtrim(a.operation) from user_datapump_jobs a
                        where a.job_name = :JOB_NAME }'
                    into l_operation
                    using p_job_name;
            else
                execute immediate
                    q'{ select rtrim(a.operation) from dba_datapump_jobs a
                        where a.owner_name = :OWNER_NAME and a.job_name = :JOB_NAME }'
                    into l_operation
                    using p_owner_name, p_job_name;
            end if;
        exception
            when no_data_found then
                pipe row (log_error('datapump job not found'));
                return;
        end;
    
        begin
            open l_cv for
                q'{ select
                        dirname, filename
                    from
                        (select
                            name,
                            value_t,
                            row_number() over (partition by name order by process_order, duplicate) as rn
                        from
                  }'
                || dbms_assert.enquote_name(p_owner_name, false)
                || '.' || dbms_assert.enquote_name(p_job_name, false)
                || q'{ 
                        where
                            process_order < 0
                            and name in ( 'LOG_FILE_DIRECTORY', 'LOG_FILE_NAME' )
                            and mod(process_order, 2) 
                                    = decode(:OPERATION, 'EXPORT', -1, 'IMPORT', 0)
                        )
                        pivot (max(value_t) for name in (
                            'LOG_FILE_DIRECTORY' as dirname,
                            'LOG_FILE_NAME'      as filename
                        )) 
                     }'
                using l_operation;
        exception
            when e_not_exists then
                pipe row (log_error(sqlcode, 'master table not found'));
                return;
        end;
        loop
            fetch l_cv into l_log_rec.log_directory, l_log_rec.log_filename;
            exit when l_cv%notfound;
            pipe row (l_log_rec);
        end loop;
        if l_cv%rowcount = 0 then
            pipe row (log_error('log file not found in the master table'));
        end if;
        close l_cv;

    exception
        when no_data_needed then
            if l_cv%isopen then
                close l_cv;
            end if;
            raise;
    end datapump_job_log;
    

    function datapump_job_log_text (
        p_owner_name  in varchar2,
        p_job_name    in varchar2,
        p_head_limit  in number     default null,
        p_tail_limit  in number     default null
    )
    return pkg_pub_textfile_viewer.tt_rec_line
    pipelined
    is
        cursor c_file_text(p_list_files in sys.odcivarchar2list) is
            select 
                a.* 
            from 
                table(c##pkg_pub_textfile_viewer.file_text(
                    p_list_files  => p_list_files,
                    p_head_limit  => p_head_limit,
                    p_tail_limit  => p_tail_limit
                )) a;

        l_tab pkg_pub_textfile_viewer.tt_rec_line;
        
        l_operation user_datapump_jobs.operation   %type;
        l_dirname   all_directories.directory_name %type;
        l_filename  varchar2(4000 byte);
        
        function line_app_error (p_sqlcode in number, p_errmsg in varchar2)
        return pkg_pub_textfile_viewer.t_rec_line
        is 
            l_rec pkg_pub_textfile_viewer.t_rec_line;
        begin
            l_rec.sqlcode := p_sqlcode;
            l_rec.sqlerrm := 'ORA' || to_char(p_sqlcode, 'S00000') || ': ' || p_errmsg;
            return l_rec;
        end line_app_error;

        function line_app_error (p_errmsg in varchar2)
        return pkg_pub_textfile_viewer.t_rec_line
        is begin
            return line_app_error(gc_sqlcode_app_error, p_errmsg);
        end line_app_error;

    begin
        /*
            Check arguments 
         */
        if p_owner_name is null
            or p_job_name is null
        then
            raise_application_error(gc_sqlcode_app_error, 'Bad argument(s)');
        end if;
    
        /* 
            Lookup the job in USER_DATAPUMP_JOBS or DBA_DATAPUMP_JOBS 
         */
        begin
            if p_owner_name = sys_context('USERENV', 'CURRENT_USER') then
                execute immediate
                    q'{ select rtrim(a.operation) from user_datapump_jobs a
                        where a.job_name = :JOB_NAME }'
                    into l_operation
                    using p_job_name;
            else
                execute immediate
                    q'{ select rtrim(a.operation) from dba_datapump_jobs a
                        where a.owner_name = :OWNER_NAME and a.job_name = :JOB_NAME }'
                    into l_operation
                    using p_owner_name, p_job_name;
            end if;
        exception
            when no_data_found then
                pipe row (line_app_error('datapump job not found'));
                return;
        end;
        
        /* 
           Retrieve the log dirname and filename from the master table 
         */
        begin
            execute immediate
                q'{ select
                        dirname, filename
                    from
                        (select
                            name,
                            value_t,
                            row_number() over (partition by name order by process_order, duplicate) as rn
                        from
                  }'
                || dbms_assert.enquote_name(p_owner_name, false)
                || '.' || dbms_assert.enquote_name(p_job_name, false)
                || q'{ 
                        where
                            process_order < 0
                            and name in ( 'LOG_FILE_DIRECTORY', 'LOG_FILE_NAME' )
                            and mod(process_order, 2) 
                                    = decode(:OPERATION, 'EXPORT', -1, 'IMPORT', 0)
                        )
                        pivot (max(value_t) for name in (
                            'LOG_FILE_DIRECTORY' as dirname,
                            'LOG_FILE_NAME'      as filename
                        )) 
                     }'
                into l_dirname, l_filename
                using l_operation;
        exception
            when no_data_found then
                pipe row (line_app_error('log file not found in the master table'));
                return;
                --
            when too_many_rows then
                pipe row (line_app_error('more than 1 log file found in the master table'));
                return;
                --
            when e_not_exists then
                pipe row (line_app_error(sqlcode, 'master table not found'));
                return;
        end;
        
        /* 
           Fetch from the log file, if available
         */
        open c_file_text (sys.odcivarchar2list(l_dirname || ':' || l_filename));
        loop
            fetch c_file_text bulk collect into l_tab limit gc_fetch_size;
            exit when l_tab.count = 0;
            for i in l_tab.first .. l_tab.last loop
                pipe row (l_tab(i));
            end loop;
        end loop;
        close c_file_text;
        
    exception
        when no_data_needed then
            if c_file_text%isopen then
                close c_file_text;
            end if;
            raise;
    end datapump_job_log_text;
    
end pkg_pub_datapump_log_viewer;
/
