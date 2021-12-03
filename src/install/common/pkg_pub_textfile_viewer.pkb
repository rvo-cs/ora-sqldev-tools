create or replace package body pkg_pub_textfile_viewer as

    gc_dir_sep       constant varchar2(1)  := '/';

    gc_max_readsize  constant pls_integer  := 32000;

    gc_sqlcode_eof          constant number  := 100;
    gc_sqlcode_value_error  constant number  := -6502;
    
    gc_sqlerrm_value_error  constant varchar2(100) := 'ORA-06502: PL/SQL: numeric or value error';
    

    type t_rec_line_impl is record (
        fileno          pls_integer,
        lineno          pls_integer,
        text            varchar2(4000 byte),
        is_value_error  boolean
    );
    
    type tt_rec_line_impl is table of t_rec_line_impl;
    
    type t_rec_file_proc is record (
        dirname     all_directories.directory_name %type,
        filename    varchar2(4000 byte),
        filepath    varchar2(4000 byte),
        linecnt     pls_integer,
        sqlcode     number,
        sqlerrm     varchar2(2000 byte)
    );

    type t_tab_file_proc is table of t_rec_file_proc index by pls_integer;

    
    function directory_equiv_path (p_dirname in varchar2) return varchar2
    is
        l_dirpath all_directories.directory_path %type;
    begin
        select
            a.directory_path into l_dirpath
        from
            all_directories a
        where
            a.directory_name = p_dirname;
        
        return l_dirpath;
    end directory_equiv_path;


    function file_text (
        p_dirname     in varchar2,
        p_filename    in varchar2,
        p_head_limit  in number     default null,
        p_tail_limit  in number     default null
    )
    return tt_rec_line
    pipelined
    is
        l_fh    utl_file.file_type;
        l_li    t_rec_line;
    begin
        if p_head_limit < 0 
            or p_head_limit <> floor(p_head_limit) 
            or p_tail_limit < 0
            or p_tail_limit <> floor(p_tail_limit)
            or p_head_limit + p_tail_limit = 0
            or (p_head_limit = 0 and p_tail_limit is null)
            or (p_tail_limit = 0 and p_head_limit is null)
        then
            raise_application_error(-20000, 'Bad argument(s)');
        end if;
    
        l_li.dirname := p_dirname;
        l_li.filename := p_filename;
        begin
            l_li.filepath := directory_equiv_path(p_dirname) || gc_dir_sep || p_filename;
        exception
            when no_data_found then     
                /* Directory not found in ALL_DIRECTORIES */
                l_li.sqlcode := utl_file.invalid_path_errcode;
                l_li.sqlerrm := 'ORA' || to_char(l_li.sqlcode) || ': invalid directory path';
                pipe row (l_li);
                return;
        end;
        
        /* OPEN */
        begin
            l_fh := utl_file.fopen( 
                location => p_dirname,
                filename => p_filename,
                open_mode => 'r',
                max_linesize => gc_max_readsize
            );
        exception                               ----vvv--- As described in UTL_FILE spec ---vvv---
            when utl_file.invalid_path          --> File location or name was invalid
                or utl_file.invalid_mode        --> The open_mode string was invalid
                or utl_file.invalid_operation   --> File could not be opened as requested
                or utl_file.invalid_maxlinesize --> Specified max_linesize is too large or too small
                or utl_file.access_denied       --> Access to the directory object is denied
            then
                l_li.sqlcode := sqlcode;
                l_li.sqlerrm := sqlerrm;
                pipe row (l_li);
                return;
        end;

        /* READ */
        declare
            l_line         varchar2(32000 byte);
            l_buf          tt_rec_line_impl;
            l_bufsize      simple_integer   := nvl(p_tail_limit, 1) + 1;
            l_idx          simple_integer   := 1;
            l_lo           simple_integer   := 0;
            l_hi           simple_integer   := 0;
            l_has_wrapped  boolean          := false;
            l_linecnt      pls_integer      := 0;
            l_skipcnt      pls_integer      := 0;

            procedure copy_line_meta(
                p_in   in  t_rec_line,
                p_out  in out nocopy  t_rec_line
            )
            is
            begin
                p_out.dirname  := p_in.dirname;
                p_out.filename := p_in.filename;
                p_out.filepath := p_in.filepath;
            end copy_line_meta;

            function as_line_rec(p_rec_impl in t_rec_line_impl) return t_rec_line
            is
                l_rec t_rec_line;
            begin
                copy_line_meta(l_li, l_rec);
                l_rec.lineno   := p_rec_impl.lineno;
                if p_rec_impl.is_value_error then
                    l_rec.sqlcode := gc_sqlcode_value_error;
                    l_rec.sqlerrm := gc_sqlerrm_value_error;
                end if;
                l_rec.text := p_rec_impl.text;
                return l_rec;
            end as_line_rec;
        begin
            l_buf := tt_rec_line_impl();
            l_buf.extend( l_bufsize );
            
            <<read_loop>>
            loop
                /* 
                   Process the previously read line 
                 */
                if l_linecnt > 0 then
                    if (p_head_limit is null and p_tail_limit is null)  -- unlimited
                        or l_linecnt <= p_head_limit                    -- first N lines plus...
                    then
                        pipe row (as_line_rec(l_buf(l_idx)));
                        
                    elsif l_linecnt > p_head_limit and nvl(p_tail_limit, 0) = 0  -- first N lines only
                    then
                        exit read_loop;
                    
                    elsif p_tail_limit is not null
                    then
                        /*
                            Ring buffer implementation (capacity = sup = p_tail_limit + 1)
                            
                                o Initial situation (empty)
                                    |01|02|03|04|05|06|07|08|09|10|
                                   ^  ^                          ^
                                   |  |                          |
                                   | inf,idx                    sup
                                 lo,hi
                            
                                o Before wrapping: lo = inf
                                    |01|02|03|04|05|06|07|08|09|10|
                                      ^                ^  ^      ^
                                      |                |  |      |
                                     inf,lo            hi idx    sup
                        
                                o After wrapping: hi "pushes" lo forward
                                    |01|02|03|04|05|06|07|08|09|10|
                                      ^             ^  ^  ^      ^
                                      |             |  |  |      |
                                     inf           hi idx lo    sup
                        
                                (Iterating always goes from lo to hi, modulo sup)
                        */
                        l_hi := l_idx;
                        l_idx := 1 + mod(l_idx, l_bufsize);
                        if l_idx = 1 then
                            l_has_wrapped := true;
                        end if;
                        if l_has_wrapped then
                            l_lo := 1 + mod(l_hi + 1, l_bufsize);
                            l_skipcnt := l_skipcnt + 1;
                        else
                            l_lo := 1;
                        end if;
                    end if;
                end if;

                /* 
                  Get the next line 
                 */
                begin
                    l_linecnt := l_linecnt + 1;
                    l_buf(l_idx).lineno := l_linecnt;
                    l_buf(l_idx).is_value_error := false;
                    utl_file.get_line(l_fh, l_line, gc_max_readsize);
                    l_buf(l_idx).text := l_line;
                exception
                    when no_data_found                  --> reached the end of file
                    then
                        l_li.sqlcode := gc_sqlcode_eof;
                        l_li.sqlerrm := '[End of file]';
                        exit read_loop;
                    --
                    when value_error                    --> line to long to store in buffer
                    then
                        l_buf(l_idx).is_value_error := true;
                        l_buf(l_idx).text := substrb(l_line, 1, gc_max_line_size);
                    --                    
                    when utl_file.invalid_filehandle    --> not a valid file handle
                        or utl_file.invalid_operation   --> file is not open for reading
                                                        --> or is open for byte mode access
                        or utl_file.read_error          --> OS error occurred during read
                                                        --  (incl. input line > gc_max_readsize)
                        or utl_file.charsetmismatch     --> if the file is open for nchar data.
                    then
                        l_li.sqlcode := sqlcode;
                        l_li.sqlerrm := sqlerrm;
                        exit read_loop;
                end;
            end loop read_loop;
            
            if l_lo > 0 then
                /* Emit buffured lines */
                if l_skipcnt > 0 then
                    declare
                        l_rec t_rec_line;
                    begin
                        copy_line_meta(l_li, l_rec);
                        l_rec.sqlerrm := '[...Skipping ' || to_char(l_skipcnt) || ' line'
                                || case when l_skipcnt > 1 then 's' end || '...]';
                        pipe row (l_rec);
                    end;
                end if;
                loop
                    pipe row (as_line_rec(l_buf(l_lo)));
                    exit when l_lo = l_hi;
                    l_lo := 1 + mod(l_lo, l_bufsize);
                end loop;
            end if;
        end;

        if l_li.sqlcode is not null then
            pipe row (l_li);
        end if;
        
        /* CLOSE */
        utl_file.fclose(l_fh);
    end file_text;
    
    
    function datapump_job_log_text (
        p_owner_name      in varchar2,
        p_job_name        in varchar2,
        p_head_limit      in number     default null,
        p_tail_limit      in number     default null,
        p_per_file_limit  in varchar2   default 'N'  
    )
    return tt_rec_line
    pipelined
    is
    begin
        /* !TODO! */
        return;
    end datapump_job_log_text;
    
end pkg_pub_textfile_viewer;
/
