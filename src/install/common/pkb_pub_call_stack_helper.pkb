create or replace package body pkg_pub_call_stack_helper as

    gc_newln constant varchar2(1) := chr(10);
    
    gc_colsep constant varchar2(2) := '  ';

    gc_colsz_min_line  constant pls_integer := 5;
    gc_colsz_min_owner constant pls_integer := 6;
    gc_colsz_min_uqn   constant pls_integer := 20;

    gc_stack_start_marker constant varchar2(30) := '***** Call Stack Start *****';
    gc_stack_end_marker   constant varchar2(30) := '****** Call Stack End ******';

    subtype t_owner is varchar2(200 char);
    subtype t_subprgnam is varchar2(32767 byte);
    
    type t_tab_owner is table of t_owner          index by pls_integer;
    type t_tab_line  is table of pls_integer      index by pls_integer;
    type t_tab_subprgnam is table of t_subprgnam  index by pls_integer;
    
    function enquote_str(
        p_str in varchar2, 
        p_use_quotes in boolean
    ) 
    return varchar2;
    
    procedure process_uqn(
        p_uqn in out nocopy utl_call_stack.unit_qualified_name,
        p_quote_names in boolean
    );

    function call_stack(
        p_skip_frames     in number   default 1,
        p_pretty_print    in varchar2 default 'Y',
        p_quote_names     in varchar2 default 'N',
        p_show_start_end  in varchar2 default 'Y'
    )
    return varchar2
    is
        l_out         varchar2(32000 byte);
        l_use_quotes  boolean;
        l_use_pprint  boolean;
        l_show_start_end boolean;

        /* Call stack data */
        l_depth       pls_integer;
        l_uqn         utl_call_stack.unit_qualified_name;
        l_tab_line    t_tab_line;
        l_tab_owner   t_tab_owner;
        l_tab_spnam   t_tab_subprgnam;

        /* Widths of columns */
        l_colsz_owner pls_integer := 0;
        l_colsz_line  pls_integer := 0;
        l_colsz_uqn   pls_integer := 0;
    begin
        l_use_quotes := (upper(p_quote_names) = 'Y');
        l_use_pprint := (upper(p_pretty_print) = 'Y');
        l_show_start_end := (upper(p_show_start_end) = 'Y');
        
        /* Read stack data */
        l_depth := utl_call_stack.dynamic_depth;
        for i in 1 + p_skip_frames .. l_depth loop
            l_tab_owner(i) := utl_call_stack.owner(i);
            l_tab_line(i)  := utl_call_stack.unit_line(i);
            l_uqn          := utl_call_stack.subprogram(i);
            l_tab_owner(i) := case 
                                when l_tab_owner(i) is not null
                                then enquote_str(l_tab_owner(i), l_use_quotes)
                              end;
            process_uqn(l_uqn, l_use_quotes);
            l_tab_spnam(i) := utl_call_stack.concatenate_subprogram(l_uqn);

            if l_use_pprint then
                /* Adjust column lengths */
                l_colsz_owner := greatest(l_colsz_owner, nvl(length(l_tab_owner(i)), 0));
                l_colsz_line  := greatest(l_colsz_line, 
                        ceil(log(10, nvl(greatest(l_tab_line(i), 1), 0.1))));
                l_colsz_uqn   := greatest(l_colsz_uqn, length(l_tab_spnam(i)));
            end if;
        end loop;

        if l_show_start_end then
            l_out := gc_stack_start_marker;
        end if;
        
        if l_use_pprint then
            /* Pretty-print the stack */
            l_colsz_owner := greatest(l_colsz_owner, gc_colsz_min_owner);
            l_colsz_line  := greatest(l_colsz_line, gc_colsz_min_line);
            l_colsz_uqn   := greatest(l_colsz_uqn, gc_colsz_min_uqn);
            
            l_out := case when l_out is not null then l_out || gc_newln end
                    || rpad('Line', l_colsz_line)
                    || gc_colsep || rpad('Owner', l_colsz_owner)
                    || gc_colsep || rpad('Name', l_colsz_uqn) || gc_newln
                    || rpad('-', l_colsz_line, '-')
                    || gc_colsep || rpad('-', l_colsz_owner, '-')
                    || gc_colsep || rpad('-', l_colsz_uqn, '-');
            
            for i in 1 + p_skip_frames .. l_depth loop
                l_out := l_out || gc_newln
                        || lpad(nvl(to_char(l_tab_line(i)), ' '), l_colsz_line)
                        || gc_colsep || rpad(nvl(l_tab_owner(i), ' '), l_colsz_owner)
                        || gc_colsep || rpad(l_tab_spnam(i), l_colsz_uqn);
            end loop;
        else
            /* No pretty-printing */
            for i in 1 + p_skip_frames .. l_depth loop
                l_out := case when l_out is not null then l_out || gc_newln end
                        || case when l_tab_owner(i) is not null 
                                then l_tab_owner(i) || '.' end
                        || l_tab_spnam(i)
                        || case when l_tab_line(i) is not null 
                                then ', at line ' || l_tab_line(i) end;
            end loop;
        end if;

        if l_show_start_end then
            l_out := l_out || gc_newln || gc_stack_end_marker;
        end if;

        return l_out;
    end call_stack;
    
    procedure print_call_stack(
        p_skip_frames     in number   default 1,
        p_pretty_print    in varchar2 default 'Y',
        p_quote_names     in varchar2 default 'N',
        p_show_start_end  in varchar2 default 'Y'
    )
    is
    begin
        pragma inline(call_stack, 'YES');
        dbms_output.put_line(call_stack(
                p_skip_frames     => p_skip_frames, 
                p_pretty_print    => p_pretty_print, 
                p_quote_names     => p_quote_names, 
                p_show_start_end  => p_show_start_end));
    end print_call_stack;

    function enquote_str(
        p_str in varchar2, 
        p_use_quotes in boolean
    ) 
    return varchar2
    is
    begin
        return case when p_use_quotes
                then dbms_assert.enquote_name(p_str, false)
                else p_str end;
    end enquote_str;
    
    function to_sqlid(p_n in number) return varchar2
    is
        l_base32 varchar2(20 byte);
        lc_digits constant varchar2(32 byte) := '0123456789abcdfghjkmnpqrstuvwxyz';
    begin
        for i in reverse 1 .. ceil(log(32, p_n + 1)) loop
            l_base32 := l_base32 
                    || substr(lc_digits, mod(floor(p_n / power(32, i-1)), 32) + 1, 1);
        end loop;
        return l_base32;
    end;
    
    procedure process_uqn(
        p_uqn in out nocopy utl_call_stack.unit_qualified_name,
        p_quote_names in boolean
    )
    is
    begin
        if p_uqn.count = 1 and regexp_like(p_uqn(1), '^[[:digit:]]+$') then
            p_uqn(1) := '__sql(sql_id = ''' || to_sqlid(to_number(p_uqn(1))) || ''')';
        else
            for i in p_uqn.first .. p_uqn.last loop
                if i = 1 and p_uqn(i) = '__anonymous_block' then
                    continue;
                end if;
                p_uqn(i) := enquote_str(p_uqn(i), p_quote_names);
            end loop;
        end if;
    end process_uqn;

end pkg_pub_call_stack_helper;
/
