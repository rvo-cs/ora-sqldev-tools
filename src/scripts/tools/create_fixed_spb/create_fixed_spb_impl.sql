set verify off
set serveroutput on

declare
    -- sql_id, plan hash value of the original (target) cursor
    l_orig_sqlid      constant v$sql.sql_id          %type := lower('&&def_spb_orig_sqlid');
    l_orig_plan_hash  constant v$sql.plan_hash_value %type := &&def_spb_orig_plan_hash;
    
    -- sql_id, plan hash value of the replacement cursor
    l_repl_sqlid      constant v$sql.sql_id          %type := lower('&&def_spb_repl_sqlid');
    l_repl_plan_hash  constant v$sql.plan_hash_value %type := &&def_spb_repl_plan_hash;

    -- comments for the original and replacement plans
    l_orig_plan_descr constant dba_sql_plan_baselines.description %type := q'{&&def_spb_orig_plan_descr}';
    l_repl_plan_descr constant dba_sql_plan_baselines.description %type := q'{&&def_spb_repl_plan_descr}';

    l_orig_sql_handle dba_sql_plan_baselines.sql_handle %type;
    l_repl_sql_handle dba_sql_plan_baselines.sql_handle %type;

    -- SQL plans of the specified SQL handle, with corresponding plan hash value
    cursor c_spb (in_sql_handle in varchar2) is
        select
            a.plan_name,
            case
                when regexp_like(b.plan_table_output, '^Plan hash value: \d+$') then
                    to_number(regexp_replace(b.plan_table_output, '^Plan hash value: '))
            end  as plan_hash_value,
            case
                when regexp_like(b.plan_table_output, 'exception|ORA-') then
                    substr(b.plan_table_output, 1, 2000)
            end  as error_msg,
            a.enabled,
            a.fixed
        from
            dba_sql_plan_baselines a,
            table(dbms_xplan.display_sql_plan_baseline(sql_handle => a.sql_handle, 
                    plan_name => a.plan_name, format => 'typical')) (+) b
        where
            a.sql_handle = in_sql_handle
            and regexp_like(b.plan_table_output (+), '(^plan hash value:|exception|ORA-)', 'i')
            and a.created >= sysdate - 5/1440;

    function sql_handle_from_cache (
        in_sqlid     in v$sql.sql_id %type,
        in_plan_hash in v$sql.plan_hash_value %type
    )
    return dba_sql_plan_baselines.sql_handle%type
    is
        l_handle dba_sql_plan_baselines.sql_handle %type;
    begin
        select
            'SQL_' || to_char(v.exact_matching_signature, 'fm0xxxxxxxxxxxxxxx')
        into
            l_handle
        from
            v$sql v
        where
            v.sql_id = in_sqlid
            and v.plan_hash_value = in_plan_hash
            and rownum <= 1;
        return l_handle;
    exception
        when no_data_found then
            return null;
    end sql_handle_from_cache;

    procedure log_msg (in_sever in varchar2, in_msg in varchar2)
    is begin
        dbms_output.put_line(in_sever || ': ' || in_msg);
    end log_msg;
        
    procedure log_error (in_msg in varchar2)
    is begin
        log_msg('ERROR', in_msg);
    end log_error;

    procedure log_info (in_msg in varchar2)
    is begin
        log_msg('INFO', in_msg);
    end log_info;
    
    procedure raise_error (
        in_msg in varchar2 default 'processing failed due to previous error(s)'
    )
    is begin
        raise_application_error(-20000, in_msg);
    end raise_error;

begin
    <<check_orig_in_cursor_cache>>
    begin
        l_orig_sql_handle := sql_handle_from_cache(
            in_sqlid     => l_orig_sqlid, 
            in_plan_hash => l_orig_plan_hash
        );
        if l_orig_sql_handle is null then
            log_error(
                'no matching cursor in v$sql for sql_id=''' || l_orig_sqlid || ''''
                || ' and plan_hash_value=' || to_char(l_orig_plan_hash)
            );
        end if;
    end check_orig_in_cursor_cache;

    <<check_repl_in_cursor_cache>>    
    begin
        l_repl_sql_handle := sql_handle_from_cache(
            in_sqlid     => l_repl_sqlid, 
            in_plan_hash => l_repl_plan_hash
        );
        if l_repl_sql_handle is null then
            log_error(
                'no matching cursor in v$sql for sql_id=''' || l_repl_sqlid || ''''
                || ' and plan_hash_value=' || to_char(l_repl_plan_hash)
            );
        end if;
    end check_repl_in_cursor_cache;

    if l_orig_sql_handle is null or l_repl_sql_handle is null then
        raise_error;
    end if;

    <<load_orig_plan_from_cache>>    
    declare
        l_cnt_plans pls_integer;
    begin
        l_cnt_plans := dbms_spm.load_plans_from_cursor_cache(
            sql_id          => l_orig_sqlid,
            plan_hash_value => l_orig_plan_hash,
            fixed           => 'NO',        /* 'NO' => continue to capture plans */
            enabled         => 'NO'
        );
        if l_cnt_plans = 0 then
            log_error('no plan loaded for the original cursor');
            raise_error;
        else
            log_info('count of loaded plans for the original cursor: ' || l_cnt_plans);
        end if;
    end load_orig_plan_from_cache;

    <<load_repl_plan_from_cache>>
    declare
        l_cnt_plans pls_integer;
    begin
        l_cnt_plans := dbms_spm.load_plans_from_cursor_cache(
            sql_handle      => l_orig_sql_handle,
            sql_id          => l_repl_sqlid,
            plan_hash_value => l_repl_plan_hash,
            fixed           => 'YES',  -- 'YES' => don't capture plans anymore for this SQL handle
            enabled         => 'YES'
        );
        if l_cnt_plans = 0 then
            log_error('no plan loaded for the replacement cursor');
            raise_error;
        else
            log_info('count of loaded plans for the replacement cursor: ' || l_cnt_plans);
        end if;
    end load_repl_plan_from_cache;

    <<comment_on_new_sql_plans>>
    declare
        l_sql_plan_name     dba_sql_plan_baselines.plan_name %type;
        l_sql_plan_hash     v$sql.plan_hash_value %type;
        l_sql_plan_errmsg   varchar2(2000);
        l_sql_plan_enabled  dba_sql_plan_baselines.enabled %type;
        l_sql_plan_fixed    dba_sql_plan_baselines.fixed   %type;
        l_cnt_descr_orig    pls_integer;
        l_cnt_descr_repl    pls_integer;
    begin
        l_cnt_descr_orig := 0;
        l_cnt_descr_repl := 0;
        open c_spb (l_orig_sql_handle);
        <<for_each_new_sql_plan>>
        loop
            fetch c_spb into
                l_sql_plan_name,
                l_sql_plan_hash,
                l_sql_plan_errmsg,
                l_sql_plan_enabled,
                l_sql_plan_fixed;
            exit for_each_new_sql_plan when c_spb %notfound;
            if l_sql_plan_enabled = 'NO' and l_sql_plan_fixed = 'NO' then
                l_cnt_descr_orig := l_cnt_descr_orig 
                      + dbms_spm.alter_sql_plan_baseline(
                            sql_handle      => l_orig_sql_handle,
                            plan_name       => l_sql_plan_name,
                            attribute_name  => 'description',
                            attribute_value => l_orig_plan_descr
                        );
            elsif l_sql_plan_enabled = 'YES' and l_sql_plan_fixed = 'YES' then
                l_cnt_descr_repl := l_cnt_descr_repl
                      + dbms_spm.alter_sql_plan_baseline(
                            sql_handle      => l_orig_sql_handle,
                            plan_name       => l_sql_plan_name,
                            attribute_name  => 'description',
                            attribute_value => l_repl_plan_descr
                        );
            end if;
        end loop for_each_new_sql_plan;
        close c_spb;
        if l_cnt_descr_orig > 0 then
            log_info('updated description of ' || l_cnt_descr_orig
                    || ' initial SQL plan' || case when l_cnt_descr_orig > 1 then 's' end);
        else
            log_error('description of the original SQL plan not updated');
        end if;
        if l_cnt_descr_repl > 0 then
            log_info('updated description of ' || l_cnt_descr_repl
                    || ' replacement SQL plan' || case when l_cnt_descr_repl > 1 then 's' end);
        else
            log_error('description of the replacement SQL plan not updated');
        end if;
        if l_cnt_descr_orig = 0 or l_cnt_descr_repl = 0 then
            raise_error;
        end if;
    end comment_on_new_sql_plans;
    
    log_info('SQL plan baseline created successfully (SQL handle: ' || l_orig_sql_handle || ')');
end;
/
