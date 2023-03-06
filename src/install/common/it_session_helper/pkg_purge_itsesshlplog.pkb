create or replace package body pkg_purge_itsesshlplog as

    function dry_run_prefix( p_dry_run in boolean ) return varchar2;     -- fwd decl.
    function boolean_as_vc2( p_bool_value in boolean ) return varchar2;  -- fwd decl.

    procedure run_purge(
        p_dry_run       in boolean      default true
    )
    is
        l_partition_ts timestamp(0);
    begin
        purge(p_table_name => gc_log_table_name, p_dry_run => p_dry_run);

        set_partition_large_extents(p_value => false, p_dry_run => p_dry_run);
        
        l_partition_ts := localtimestamp;
        <<add_2_partitions>>
        for i in 1..2 loop
            add_partition(
                p_for_datetime => l_partition_ts,
                p_dry_run      => p_dry_run
            );
            l_partition_ts := l_partition_ts + interval '7' day;
        end loop add_2_partitions;
    end run_purge;


    procedure set_partition_large_extents(
        p_value    in boolean  default false,
        p_dry_run  in boolean  default true
    )
    is
        l_stmt varchar2(200);
    begin
        l_stmt := 'alter session set "_partition_large_extents" = '
                || boolean_as_vc2(p_value);
        if not p_dry_run then
            execute immediate l_stmt;
        end if;
        dbms_output.put_line(dry_run_prefix(p_dry_run) || '>>> ' || l_stmt);
    end set_partition_large_extents;


    procedure add_partition(
        p_for_datetime  in timestamp    default localtimestamp,
        p_dry_run       in boolean      default true
    )
    is
        l_stmt varchar2(300);
    begin
        l_stmt := 'lock table '
            || dbms_assert.enquote_name(gc_log_table_name, capitalize => false)
            || ' partition for (to_timestamp(''' || to_char(p_for_datetime, 'YYYY-MM-DD HH24:MI:SSXFF')
            || ''', ''YYYY-MM-DD HH24:MI:SSXFF'')) in row exclusive mode';
        if not p_dry_run then
            execute immediate l_stmt;
        end if;
        dbms_output.put_line(dry_run_prefix(p_dry_run) || '>>> ' || l_stmt);
        if not p_dry_run then
            rollback;
        end if;
        dbms_output.put_line(dry_run_prefix(p_dry_run) || '>>> rollback');
    end add_partition;


    procedure purge(
        p_table_name        in  varchar2,
        p_dry_run           in  boolean         default true,
        p_retention_period  in  t_interval_ds0  default null
    )
    is
        cursor c_parts (p_table_name in varchar2) is
            select
                b.partition_name,
                b.high_value
            from
                (select
                    a.partition_name,
                    a.high_value,
                    a.partition_position,
                    row_number() over (order by a.partition_position desc) as rn
                from
                    user_tab_partitions a
                where
                    a.table_name = p_table_name
                    and a.interval = 'YES'
                ) b
            where
                b.rn > gc_retention_parts
            order by
                b.partition_position asc;
        
        l_retention_period   t_interval_ds0;
        
        l_purge_upper_bound  timestamp;
        l_drop_stmt          varchar2(200);
        l_part_cnt           number;    -- count of partitions considered for purging
        l_drop_cnt           number;    -- count of dropped partitions

        l_partition_name  user_tab_partitions.partition_name %type;
        l_high_value_vc2  varchar2(100);
        l_high_value_ts   timestamp;

        function dry_run_prefix return varchar2
        is begin
            return pkg_purge_itsesshlplog.dry_run_prefix(p_dry_run);
        end dry_run_prefix;
        
    begin
        l_retention_period := nvl(p_retention_period, gc_retention_period);

        l_purge_upper_bound := trunc(systimestamp, 'DDD') - l_retention_period;
        l_part_cnt := 0;
        l_drop_cnt := 0;
    
        dbms_output.put_line(
            dry_run_prefix || 'Purging from     :  ' 
            || dbms_assert.enquote_name(p_table_name, false)
        );
        dbms_output.put_line(
            dry_run_prefix || 'Retention period :  ' || l_retention_period
        );
        dbms_output.put_line(
            dry_run_prefix || 'Upper bound      :  ' 
            || to_char(l_purge_upper_bound, 'YYYY-MM-DD HH24:MI:SS')
        );
        dbms_output.put_line(
            dry_run_prefix || 'Always keeping   :  ' 
            || to_char(gc_retention_parts) || ' top-most partition'
            || case when gc_retention_parts > 1 then 's' end
        );
        
        open c_parts(p_table_name);
        loop
            fetch c_parts into l_partition_name, l_high_value_vc2;
            exit when c_parts %notfound;
            l_part_cnt := l_part_cnt + 1;
            
            if not regexp_like(l_high_value_vc2,
                    '^TIMESTAMP''(-| )\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}''$')
            then
                raise_application_error(-20000, 
                        'High value of partition ' || l_partition_name 
                        || ' is not in the expected format');
            end if;

            l_high_value_ts := to_timestamp(substr(l_high_value_vc2, 11, 20),
                    'SYYYY-MM-DD HH24:MI:SS');
            
            dbms_output.put_line(
                dry_run_prefix
                || 'Partition ' || p_table_name || '.' || l_partition_name
                || ' (high value: ' || l_high_value_vc2 
                || case 
                    when l_high_value_ts <= l_purge_upper_bound 
                    then ' <= '
                    else ' >  '
                   end
                || to_char(l_purge_upper_bound, 'YYYY-MM-DD HH24:MI:SS') 
                || ') is to be ' 
                || case 
                    when l_high_value_ts <= l_purge_upper_bound 
                    then 'purged'
                    else 'kept'
                   end
            );
            
            if l_high_value_ts <= l_purge_upper_bound
            then
                l_drop_stmt := 'alter table '
                        || dbms_assert.enquote_name(p_table_name, false)
                        || ' drop partition '
                        || dbms_assert.enquote_name(l_partition_name, false);
                
                dbms_output.put_line(dry_run_prefix || '>>> ' || l_drop_stmt);
                
                if not p_dry_run then
                    execute immediate l_drop_stmt;
                    l_drop_cnt := l_drop_cnt + 1;
                end if;
            end if;
        end loop;
        close c_parts;
        
        dbms_output.put_line(
            dry_run_prefix 
            || case
                when l_part_cnt = 0 
                then 'No eligible partition for purging'
                else 'Count of partition(s) actually dropped: ' || l_drop_cnt
               end
        );
    end purge;


    function dry_run_prefix( p_dry_run in boolean ) return varchar2
    is begin
        return case
                   when p_dry_run is null or p_dry_run then
                       '## DRY RUN: '
               end;
    end dry_run_prefix;
    
    
    function boolean_as_vc2( p_bool_value in boolean ) return varchar2
    is begin
        return case
                   when p_bool_value then
                       'true'
                   when not p_bool_value then
                       'false'
               end;
    end boolean_as_vc2;

end pkg_purge_itsesshlplog;
/
