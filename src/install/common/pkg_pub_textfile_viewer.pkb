create or replace package body pkg_pub_textfile_viewer as

    gc_dir_sep       constant varchar2(1)  := '/';

    gc_max_readsize  constant pls_integer  := 32000;

    gc_sqlcode_eof          constant number  := 100;
    gc_sqlcode_value_error  constant number  := -6502;
    gc_sqlcode_app_error    constant number  := -20000;
    
    gc_sqlerrm_value_error  constant varchar2(100) := 'ORA-06502: PL/SQL: numeric or value error';
    
    gc_fetch_size constant pls_integer := 100;


    type t_rec_line_impl is record (
        fileno          pls_integer,
        lineno          number,
        text            varchar2(4000 byte),
        is_value_error  boolean
    );
    
    type tt_rec_line_impl is table of t_rec_line_impl;
    
    type t_rec_file_proc is record (
        dirname     all_directories.directory_name %type,
        filename    varchar2(4000 byte),
        filepath    varchar2(4000 byte),
        linecnt     number,
        emitcnt     number,
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


    function file_text_impl_is_bad_arg (
        p_head_limit  in number,
        p_tail_limit  in number
    )
    return boolean
    is
    begin
        return 
            p_head_limit < 0
            or p_head_limit <> floor(p_head_limit) 
            or p_tail_limit < 0
            or p_tail_limit <> floor(p_tail_limit)
            or p_head_limit + p_tail_limit = 0
            or (p_head_limit = 0 and p_tail_limit is null)
            or (p_tail_limit = 0 and p_head_limit is null);
    end file_text_impl_is_bad_arg;
    
    
    function file_text (
        p_dirname     in varchar2,
        p_filename    in varchar2,
        p_head_limit  in number     default null,
        p_tail_limit  in number     default null
    )
    return tt_rec_line
    pipelined
    is
        cursor c_file_text is
            select 
                a.* 
            from 
                table(c##pkg_pub_textfile_viewer.file_text(
                    p_list_files  => sys.odcivarchar2list(p_dirname || ':' || p_filename),
                    p_head_limit  => p_head_limit,
                    p_tail_limit  => p_tail_limit
                )) a;

        l_tab tt_rec_line;
    begin
        if p_dirname is null
            or p_filename is null
            or file_text_impl_is_bad_arg ( p_head_limit => p_head_limit
                                         , p_tail_limit => p_tail_limit )
        then
            raise_application_error(gc_sqlcode_app_error, 'Bad argument(s)');
        end if;

        open c_file_text;
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
    end file_text;


    function file_text (
        p_list_files      in sys.odcivarchar2list,
        p_head_limit      in number     default null,
        p_tail_limit      in number     default null,
        p_per_file_limit  in varchar2   default 'N'
    )
    return tt_rec_line
    pipelined
    is
        l_is_per_file_limit boolean;
        
        l_tab_file_proc  t_tab_file_proc;           -- keeps track of each file's processing
        l_buf            tt_rec_line_impl;          -- ring buffer of read lines
        l_bufsize        simple_integer  := nvl(p_tail_limit, 1) + 1;
        l_idx            simple_integer  := 1;      -- current index into the ring buffer
        l_lo             simple_integer  := 0;      -- lowest pos. in the ring buffer    
        l_hi             simple_integer  := 0;      -- highest pos. in the ring buffer
        l_has_wrapped    boolean         := false;  -- ring buffer wrap indicator
        l_cur_fno        pls_integer     := 0;      -- index of current file
        l_last_emit_fno  pls_integer     := 0;      -- last file for which 1 line was piped
        l_linecnt        number          := 0;      -- line counter in the current file
        l_total_linecnt  number          := 0;      -- line counter accross all files

        l_fh             utl_file.file_type;

        procedure copy_line_meta(
            p_in   in  t_rec_file_proc,
            p_out  in out nocopy  t_rec_line
        )
        is
        begin
            p_out.dirname  := p_in.dirname;
            p_out.filename := p_in.filename;
            p_out.filepath := p_in.filepath;
        end copy_line_meta;

        function as_line_rec (p_rec_impl in t_rec_line_impl) return t_rec_line
        is
            l_rec t_rec_line;
        begin
            copy_line_meta(l_tab_file_proc(p_rec_impl.fileno), l_rec);
            l_rec.file#  := p_rec_impl.fileno;
            l_rec.lineno := p_rec_impl.lineno;
            if p_rec_impl.is_value_error then
                l_rec.sqlcode := gc_sqlcode_value_error;
                l_rec.sqlerrm := gc_sqlerrm_value_error;
            end if;
            l_rec.text := p_rec_impl.text;
            l_last_emit_fno := l_rec.file#;
            return l_rec;
        end as_line_rec;

        function as_line_rec (
            p_fileno   in pls_integer,
            p_sqlerrm  in varchar2  default null
        )
        return t_rec_line
        is
            l_rec t_rec_line;
        begin
            copy_line_meta(l_tab_file_proc(p_fileno), l_rec);
            l_rec.file# := p_fileno;
            if p_sqlerrm is not null then
                l_rec.sqlerrm := p_sqlerrm;
            else
                l_rec.sqlcode := l_tab_file_proc(p_fileno).sqlcode;
                l_rec.sqlerrm := l_tab_file_proc(p_fileno).sqlerrm;
            end if;
            /*
                Note: this is the line for notifying the final status of the 
                file (end-of-file or I/O error); l_last_emit_fno is set to 
                p_fileno + 1 in order to prevent from emitting it twice.
            */
            l_last_emit_fno := l_rec.file# + 1;
            return l_rec;
        end as_line_rec;        

    begin
        /*
            Check arguments 
         */
        if p_list_files is null
            or p_list_files.count = 0
            or file_text_impl_is_bad_arg ( p_head_limit => p_head_limit
                                         , p_tail_limit => p_tail_limit )
            or p_per_file_limit is null
            or upper(p_per_file_limit) not in ('Y', 'N')
        then
            raise_application_error(gc_sqlcode_app_error, 'Bad argument(s)');
        end if;
        
        l_is_per_file_limit := (upper(p_per_file_limit) = 'Y');

        /* 
            Extract dir. names and file names
            from p_list_files into l_tab_file_proc
         */
        for i in p_list_files.first .. p_list_files.last loop
            declare
                l_dirname  all_directories.directory_name %type;
                l_filename varchar2(4000 byte);
            begin
                l_dirname  := regexp_substr(p_list_files(i), '^ ([^:]+) :', 1, 1, 'x', 1);
                l_filename := regexp_substr(p_list_files(i), '^ ([^:]+) : (.+) $', 1, 1, 'x', 2);
                if l_dirname is null or l_filename is null then
                    raise_application_error(gc_sqlcode_app_error, 
                            'File spec. must be in ''DIRNAME:filename'' syntax');
                end if;
                l_tab_file_proc(i).dirname  := l_dirname;
                l_tab_file_proc(i).filename := l_filename;
            end;
        end loop;

        /* 
           Main section 
        */
        l_buf := tt_rec_line_impl();
        l_buf.extend( l_bufsize );
        
        <<main_loop>>
        loop
            /* 
               Process the previously read line, if any.
               l_cur_fno = 0 means no file was processed so far
               otherwise l_linecnt = 0 means we're at EOF, or I/O error
             */
            if l_cur_fno > 0 and l_linecnt = 0 then
                if l_is_per_file_limit then
                    if l_lo > 0 then
                        /* 
                            Emit buffered lines
                            (see ring buffer diagram below)
                         */
                        if l_has_wrapped then
                            declare
                                l_skipcnt number;
                            begin
                                l_skipcnt := l_buf(l_lo).lineno - 1
                                        - l_tab_file_proc(l_cur_fno).emitcnt;
                                if l_skipcnt > 0 then
                                    pipe row (as_line_rec(l_cur_fno, 
                                            '[...Skipping ' || to_char(l_skipcnt) || ' line'
                                            || case when l_skipcnt > 1 then 's' end || '...]'));
                                end if;
                            end;
                        end if;
                        loop
                            pipe row (as_line_rec(l_buf(l_lo)));
                            exit when l_lo = l_hi;
                            l_lo := 1 + mod(l_lo, l_bufsize);
                        end loop;
                    
                        /* Re-init. the ring buffer */
                        l_idx := 1;
                        l_lo  := 0;
                        l_hi  := 0;
                    end if;
            
                    /* Emit EOF or I/O error line */
                    if l_cur_fno >= l_last_emit_fno then
                        pipe row (as_line_rec(l_cur_fno));
                    end if;
                end if;
                
            elsif l_linecnt > 0 then
                /* 
                    We've just read 1 line; emit it immediately or buffer it,
                    depending on head/tail limits (either global or per-file)
                 */
                declare
                    l_tst_linecnt number;
                begin
                    l_tst_linecnt := 
                            case 
                                when l_is_per_file_limit 
                                then l_linecnt 
                                else l_total_linecnt 
                            end;
                    if (p_head_limit is null and p_tail_limit is null)  -- unlimited
                        or l_tst_linecnt <= p_head_limit                -- first N lines
                    then
                        for i in greatest(l_last_emit_fno, 1) .. l_cur_fno - 1 loop
                            pipe row (as_line_rec(i));
                        end loop;
                        pipe row (as_line_rec(l_buf(l_idx)));
                        l_tab_file_proc(l_cur_fno).emitcnt := 
                                l_tab_file_proc(l_cur_fno).emitcnt + 1;
                        
                    elsif l_tst_linecnt > p_head_limit 
                        and nvl(p_tail_limit, 0) = 0            -- first N lines only
                    then                                    
                        -- Stop processing this file
                        l_linecnt := 0;
                        utl_file.fclose(l_fh);
                        l_fh := null;
                        for i in greatest(l_last_emit_fno, 1) .. l_cur_fno - 1 loop
                            pipe row (as_line_rec(i));
                        end loop;
                        pipe row (as_line_rec(l_cur_fno, '[Max of ' || to_char(p_head_limit)
                                || ' line' || case when p_head_limit > 1 then 's' end
                                || ' reached.]'));
                        continue main_loop;
                    
                    elsif p_tail_limit is not null
                    then
                        /*
                            Ring buffer implementation
                            (capacity = sup = p_tail_limit + 1)
                            
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
                        else
                            l_lo := 1;
                        end if;
                    end if;
                end;
            end if;

            if l_linecnt = 0 then
                /* 
                    Get the next file 
                */
                if l_cur_fno = l_tab_file_proc.count then
                    exit main_loop;             --> no more file to process
                end if;
                l_cur_fno := l_cur_fno + 1;
                begin
                    l_tab_file_proc(l_cur_fno).filepath := 
                            directory_equiv_path(l_tab_file_proc(l_cur_fno).dirname) 
                            || gc_dir_sep || l_tab_file_proc(l_cur_fno).filename;
                exception
                    when no_data_found then     
                        -- Directory not found in ALL_DIRECTORIES
                        l_tab_file_proc(l_cur_fno).sqlcode := utl_file.invalid_path_errcode;
                        l_tab_file_proc(l_cur_fno).sqlerrm := 'ORA'
                                || to_char(l_tab_file_proc(l_cur_fno).sqlcode) 
                                || ': invalid directory path';
                        continue main_loop;
                end;
                begin
                    l_fh := utl_file.fopen( 
                        location => l_tab_file_proc(l_cur_fno).dirname,
                        filename => l_tab_file_proc(l_cur_fno).filename,
                        open_mode => 'r',
                        max_linesize => gc_max_readsize
                    );
                    l_tab_file_proc(l_cur_fno).linecnt := 0;
                    l_tab_file_proc(l_cur_fno).emitcnt := 0;
                exception                               ----vvv--- As described in UTL_FILE spec ---vvv---
                    when utl_file.invalid_path          --> File location or name was invalid
                        or utl_file.invalid_mode        --> The open_mode string was invalid
                        or utl_file.invalid_operation   --> File could not be opened as requested
                        or utl_file.invalid_maxlinesize --> Specified max_linesize is too large or too small
                        or utl_file.access_denied       --> Access to the directory object is denied
                    then
                        l_tab_file_proc(l_cur_fno).sqlcode := sqlcode;
                        l_tab_file_proc(l_cur_fno).sqlerrm :=   -- keep 1st line of sqlerrm
                                regexp_substr(sqlerrm, '^(.*)$', 1, 1, 'm', 1);
                        continue main_loop;
                end;
            end if;
            
            /* 
              Get the next line 
             */
            declare
                l_line varchar2(32000 byte);
            begin
                l_linecnt := l_linecnt + 1;
                l_buf(l_idx).fileno := l_cur_fno;
                l_buf(l_idx).lineno := l_linecnt;
                l_buf(l_idx).is_value_error := false;
                utl_file.get_line(l_fh, l_line, gc_max_readsize);
                l_tab_file_proc(l_cur_fno).linecnt := l_linecnt;
                l_total_linecnt := l_total_linecnt + 1;
                l_buf(l_idx).text := l_line;
            exception
                when no_data_found                  --> reached the end of file
                then
                    l_tab_file_proc(l_cur_fno).sqlcode := gc_sqlcode_eof;
                    l_tab_file_proc(l_cur_fno).sqlerrm := '[End of file]';
                    l_linecnt := 0;                 --> move on to the next file
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
                    l_tab_file_proc(l_cur_fno).sqlcode := sqlcode;
                    l_tab_file_proc(l_cur_fno).sqlerrm := sqlerrm;
                    l_linecnt := 0;                 --> move on to the next file
            end;
            
            if l_linecnt = 0 then
                if utl_file.is_open(l_fh) then
                    utl_file.fclose(l_fh);
                    l_fh := null;
                end if;
            end if;
            
        end loop main_loop;
        
        if not l_is_per_file_limit then
            if l_lo > 0 then
                /* 
                    We'll emit buffered lines; before that we'll mention
                    any section of any file which may have been skipped.
                 */
                if l_has_wrapped then
                    for i in greatest(l_last_emit_fno, 1) .. l_buf(l_lo).fileno loop
                        declare
                            l_skipcnt number;
                        begin
                            l_skipcnt := case
                                           when i < l_buf(l_lo).fileno
                                           then l_tab_file_proc(i).linecnt
                                           else l_buf(l_lo).lineno - 1
                                         end
                                            - l_tab_file_proc(i).emitcnt;
                            if l_skipcnt > 0 then
                                pipe row (as_line_rec(i, '[...Skipping ' 
                                        || to_char(l_skipcnt) || ' line'
                                        || case when l_skipcnt > 1 then 's' end || '...]'));
                            end if;
                            if i < l_buf(l_lo).fileno then
                                pipe row (as_line_rec(i));
                            end if;
                        end;
                    end loop;
                end if;
                loop
                    for i in greatest(l_last_emit_fno, 1) .. l_buf(l_lo).fileno - 1 loop
                        pipe row (as_line_rec(i));
                    end loop;
                    pipe row (as_line_rec(l_buf(l_lo)));
                    exit when l_lo = l_hi;
                    l_lo := 1 + mod(l_lo, l_bufsize);
                end loop;
            end if;
    
            for i in greatest(l_last_emit_fno, 1) .. l_cur_fno loop
                if l_tab_file_proc(i).sqlcode is not null then
                    pipe row (as_line_rec(i));
                end if;
            end loop;
        end if;

    end file_text;
  
end pkg_pub_textfile_viewer;
/
