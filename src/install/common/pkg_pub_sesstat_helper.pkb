create or replace package body pkg_pub_sesstat_helper as

    subtype t_snap_id     is pls_integer;
    subtype t_session_id  is pls_integer;
    
    /*
        The series of timestamps when a specific session was snapped;
        the index is the snapshot number for that session.
     */
    type t_snap_time is table of timestamp index by t_snap_id;

    /*
        The series of all snapshot timestamps, for all snapped sessions;
        the index is the session id.
     */
    type t_all_snap_time is table of t_snap_time index by t_session_id;

    g_all_snap_time t_all_snap_time;

    /* 
        Snapshots of V$SESSTAT taken taken when snapping a specific session;
        the index is the snapshot number for that session.
     */
    type t_hist_sesstat is table of tt_v$sesstat index by t_snap_id;

    /* 
        All snapshots of V$SESSTAT, for all snapped sessions;
        the index is the session id.
     */
    type t_all_hist_sesstat is table of t_hist_sesstat index by t_session_id;

    g_all_hist_sesstat t_all_hist_sesstat;

    /* 
        Snapshots of V$LATCH taken taken when snapping a specific session;
        the index is the snapshot number for that session.
     */
    type t_hist_latch is table of tt_v$latch index by t_snap_id;
    
    /* 
        All snapshots of V$LATCH, for all snapped sessions;
        the index is the session id.
     */
    type t_all_hist_latch is table of t_hist_latch index by t_session_id;

    g_all_hist_latch t_all_hist_latch;

    cursor c_stat_diff(
        p_sid        v$sesstat.sid%type,
        p_snap_from  number,
        p_snap_to    number
    ) is
        select
            c.statistic#,
            c.value,
            d.name,
            d.class as class#,
            decode(d.class, 1, 'User', 2, 'Redo', 4, 'Enqueue', 8, 'Cache',
                   16, 'OS', 32, 'RAC', 64, 'SQL', 128, 'Debug') as class
        from
            (select
                b.statistic#,
                b.value - nvl(a.value, 0) as value
            from
                table(c##pkg_pub_sesstat_helper.stat_snap(p_sid, p_snap_from)) a,
                table(c##pkg_pub_sesstat_helper.stat_snap(p_sid, p_snap_to)) b
            where
                a.statistic# (+) = b.statistic#
                and (b.value - nvl(a.value, 0)) <> 0
            ) c,
            v$statname d
        where
            c.statistic# = d.statistic#
        order by
            upper(d.name), c.statistic#;

    /*
        Default threshold on latch gets (willing to wait + immediate)
        Latches with fewer than this are not reported as differences.
     */
    gc_latch_min_gets constant number := 100;

    cursor c_latch_diff(
        p_sid        v$sesstat.sid%type,
        p_snap_from  number,
        p_snap_to    number,
        p_min_gets   number  default gc_latch_min_gets
    ) is
        select
            b.addr
          , b.latch#
          , b.level#
          , b.name
          , b.gets   - nvl(a.gets, 0)      as gets
          , b.misses - nvl(a.misses, 0)    as misses
          , b.sleeps - nvl(a.sleeps, 0)    as sleeps
          , b.immediate_gets   - nvl(a.immediate_gets, 0)    as immediate_gets
          , b.immediate_misses - nvl(a.immediate_misses, 0)  as immediate_misses
          , b.spin_gets        - nvl(a.spin_gets, 0)         as spin_gets
          , b.wait_time        - nvl(a.wait_time, 0)         as wait_time
         $IF not dbms_db_version.ver_le_11_2 $THEN
          , b.con_id
         $END
        from 
            table(c##pkg_pub_sesstat_helper.latch_snap(p_sid, p_snap_from)) a
          , table(c##pkg_pub_sesstat_helper.latch_snap(p_sid, p_snap_to)) b
        where
            a.addr (+)        = b.addr
            and a.latch# (+)  = b.latch#
            and a.level# (+)  = b.level#
            and a.name (+)    = b.name
           $IF not dbms_db_version.ver_le_11_2 $THEN
            and a.con_id (+)  = b.con_id
           $END
            and ((b.gets + b.immediate_gets
                        - nvl(a.gets, 0) - nvl(a.immediate_gets, 0))
                    >= greatest(1, p_min_gets)
                 or (b.wait_time - nvl(a.wait_time, 0)) > 0 /* µs */
                 or (b.misses - nvl(a.misses, 0)) > 0
                 or (b.immediate_misses - nvl(a.immediate_misses, 0)) > 0)
        order by
            wait_time desc
          , gets + immediate_gets desc
          , level# , latch# , name;

    gc_colsep            constant varchar2(10) := '  ';
    gc_colsz_stat_value  constant number := 10;
    gc_colsz_latch_value constant number := 10;


    procedure snap(p_sid in v$sesstat.sid%type)
    is
        l_snap_id           t_snap_id;
        l_snap_time         timestamp;
        l_new_hist_snap     t_snap_time;
        l_stat_snap         tt_v$sesstat;
        l_new_hist_sesstat  t_hist_sesstat;
        l_latch_snap        tt_v$latch;
        l_new_hist_latch    t_hist_latch;
    begin
        l_snap_time := systimestamp;
        
        select
            a.statistic#,
            a.value,
            cast(null as varchar2(64))  as name, 
            cast(null as number)        as class#,
            cast(null as varchar2(64))  as class 
        bulk collect into l_stat_snap
        from
            v$sesstat a
        where
            a.sid = p_sid;
        
        if l_stat_snap.count = 0 then
            raise_application_error(-20000, 'session not found');
        end if;
        
        select
            a.addr
          , a.latch#
          , a.level#
          , a.name
          , a.gets
          , a.misses
          , a.sleeps
          , a.immediate_gets
          , a.immediate_misses
          , a.spin_gets
          , a.wait_time
         $IF not dbms_db_version.ver_le_11_2 $THEN
          , a.con_id
         $END
        bulk collect into l_latch_snap
        from 
            v$latch a
        where
            a.gets > 0
            or a.immediate_gets > 0;
    
        if g_all_snap_time.exists(p_sid) then
            l_snap_id := g_all_snap_time(p_sid).count + 1;
            g_all_snap_time   (p_sid)(l_snap_id) := l_snap_time;
            g_all_hist_sesstat(p_sid)(l_snap_id) := l_stat_snap;
            g_all_hist_latch  (p_sid)(l_snap_id) := l_latch_snap;
        else
            l_snap_id := 1;
            l_new_hist_snap   (l_snap_id) := l_snap_time;
            l_new_hist_sesstat(l_snap_id) := l_stat_snap;
            l_new_hist_latch  (l_snap_id) := l_latch_snap;
            g_all_snap_time   (p_sid) := l_new_hist_snap;
            g_all_hist_sesstat(p_sid) := l_new_hist_sesstat ;
            g_all_hist_latch  (p_sid) := l_new_hist_latch;
        end if;
    end snap;
    

    function snap_time(
        p_sid       in v$sesstat.sid%type,
        p_snap_id   in number
    ) 
    return timestamp
    is
    begin
        if g_all_snap_time.exists(p_sid) then
            if p_snap_id between 0 and g_all_snap_time(p_sid).count - 1 then
                return g_all_snap_time(p_sid)(g_all_snap_time(p_sid).count - p_snap_id);
            end if;
        end if;
        return null;
    end snap_time;

    
    function list_snapshot(p_sid in v$sesstat.sid%type)
    return tt_rec_snapshot
    pipelined
    is
        l_rec_snap t_rec_snapshot;
        l_cnt_snap pls_integer;
    begin
        if g_all_snap_time.exists(p_sid) then
            l_cnt_snap := g_all_snap_time(p_sid).count;
            for i in 0 .. l_cnt_snap - 1 loop
                l_rec_snap.snap_id := i;
                l_rec_snap.snap_time := g_all_snap_time(p_sid)(l_cnt_snap - i);
                pipe row(l_rec_snap);
            end loop;
        end if;
        return;
    end list_snapshot;

    
    procedure assert_snapshot_exists(
        p_sid      in v$sesstat.sid%type,
        p_snap_id  in t_snap_id
    )
    is
    begin
        if not g_all_hist_latch.exists(p_sid) then
            raise_application_error(-20000, 'no available data for this session');
        end if;
        if not p_snap_id between 0 and g_all_hist_latch(p_sid).count - 1 then
            raise_application_error(-20000, 'snapshot index is out of range');
        end if;
    end assert_snapshot_exists;


    function safe_rpad(p_val in varchar2, p_len in number, p_pad in varchar2 default ' ')
    return varchar2;

    function safe_lpad(p_val in varchar2, p_len in number, p_pad in varchar2 default ' ')
    return varchar2;
    
    function ela_s(p_ts_from in timestamp, p_ts_to in timestamp) return number;
    

    procedure print_diff(
        p_sid               in v$sesstat.sid%type,
        p_print_latch_diff  in varchar2  default 'N',
        p_snap_from         in number    default 1,
        p_snap_to           in number    default 0,
        p_min_gets          in number    default null,
        p_with_vsep         in varchar2  default 'Y'
    )
    is
        l_is_with_vsep        boolean := (upper(p_with_vsep) = 'Y');
        l_is_print_latch_diff boolean :=
                (upper(p_print_latch_diff) = 'Y' or p_min_gets is not null);
    begin
        assert_snapshot_exists(p_sid, p_snap_from);
        assert_snapshot_exists(p_sid, p_snap_to);

        if l_is_with_vsep then 
            dbms_output.put_line('****'); 
        end if;

        dbms_output.put_line('Session id   : ' || to_char(p_sid));
        dbms_output.put_line('From time    : ' 
                || to_char(snap_time(p_sid, p_snap_from), 'YYYY-MM-DD HH24:MI:SSXFF2')
                || '  (snap# ' || p_snap_from || ')');
        dbms_output.put_line('To time      : ' 
                || to_char(snap_time(p_sid, p_snap_to), 'YYYY-MM-DD HH24:MI:SSXFF2')
                || '  (snap# ' || p_snap_to || ')');
        dbms_output.put_line('Elapsed time : ' 
                || to_char(round(ela_s(snap_time(p_sid, p_snap_from),
                                       snap_time(p_sid, p_snap_to)), 2)) || ' s');
        dbms_output.new_line;

        print_stat_diff(p_sid => p_sid,
                p_snap_from => p_snap_from, p_snap_to => p_snap_to);

        if l_is_print_latch_diff then
            dbms_output.new_line;
            print_latch_diff(p_sid => p_sid,
                    p_snap_from => p_snap_from, p_snap_to => p_snap_to,
                    p_min_gets => p_min_gets);
        end if;

        if l_is_with_vsep then 
            dbms_output.new_line; 
            dbms_output.put_line('****'); 
        end if;
    end print_diff;

    
    procedure print_stat_diff(
        p_sid        in v$sesstat.sid%type,
        p_snap_from  in number default 1,
        p_snap_to    in number default 0
    )
    is
        l_rec t_v$sesstat;
    begin
        assert_snapshot_exists(p_sid, p_snap_from);
        assert_snapshot_exists(p_sid, p_snap_to);

        dbms_output.put_line('=== Session statistics deltas ===');
        dbms_output.new_line;
    
        if c_stat_diff%isopen then close c_stat_diff; end if;
        open c_stat_diff(p_sid => p_sid, 
                         p_snap_from => p_snap_from,
                         p_snap_to => p_snap_to);
        loop
            fetch c_stat_diff into l_rec;
            exit when c_stat_diff%notfound;
            if c_stat_diff%rowcount = 1 then
                dbms_output.put_line(
                    rpad('Value diff.', gc_colsz_stat_value + 1) 
                    || gc_colsep || 'Stat. Name'
                );
                dbms_output.put_line(
                    rpad('-', gc_colsz_stat_value + 1, '-')
                    || gc_colsep || rpad('-', 64, '-')
                );
            end if;
            dbms_output.put_line(
                safe_lpad(to_char(l_rec.value), gc_colsz_stat_value) || ' '
                || gc_colsep || l_rec.name
            );
        end loop;
        if c_stat_diff%rowcount = 0 then
            dbms_output.put_line('No change.');
        end if;
        close c_stat_diff;
    end print_stat_diff;


    procedure print_latch_diff(
        p_sid        in v$sesstat.sid%type,
        p_snap_from  in number default 1,
        p_snap_to    in number default 0,
        p_min_gets   in number default null
    )
    is
        l_rec t_v$latch;
        --
        l_latch_min_gets number;            /* Latch gets ignore threshold */
        l_tot_latch_wait number := 0;       /* Latch total wait time */
        --
        l_cnt_out       pls_integer := 0;   /* count of printed diffs */
        l_cnt_ignored   pls_integer := 0;   /* count of ignored diffs */
        l_ign_gets      number := 0;        /* ignored latches: total gets */
        l_ign_misses    number := 0;        /* ignored latches: total misses */
        l_ign_wait_time number := 0;        /* ignored latches: total wait time */
        --
        function fmt_int(p_n in integer) return varchar2
        is begin
            return case when p_n <> 0 then to_char(p_n) end;
        end fmt_int;
        --
        function fmt_wait_time(p_wait_time in number,
                p_zero_as_ws boolean default true) return varchar2
        is begin
            return case when not p_zero_as_ws or p_wait_time <> 0 then
                    to_char(round(p_wait_time / power(10,3), 1)) end;
        end fmt_wait_time;
    begin
        assert_snapshot_exists(p_sid, p_snap_from);
        assert_snapshot_exists(p_sid, p_snap_to);

        l_latch_min_gets := greatest(1, nvl(p_min_gets, gc_latch_min_gets));
        
        dbms_output.put_line('=== Latch activity (instance-wide) ===');
        dbms_output.new_line;
        
        if c_latch_diff%isopen then close c_latch_diff; end if;
        open c_latch_diff(p_sid => p_sid, 
                         p_snap_from => p_snap_from,
                         p_snap_to => p_snap_to,
                         p_min_gets => 1);
        loop
            fetch c_latch_diff into l_rec;
            exit when c_latch_diff%notfound;
            
            l_tot_latch_wait := l_tot_latch_wait + l_rec.wait_time;
            
            if (l_rec.immediate_gets + l_rec.gets) < l_latch_min_gets then
                /* Ignored row */
                l_cnt_ignored := l_cnt_ignored + 1;
                l_ign_gets := l_ign_gets + (l_rec.gets + l_rec.immediate_gets);
                l_ign_misses := l_ign_misses + (l_rec.misses + l_rec.immediate_misses);
                l_ign_wait_time := l_ign_wait_time + l_rec.wait_time;
            else
                /* Printed row */
                l_cnt_out := l_cnt_out + 1;
                if l_cnt_out = 1 then
                    dbms_output.put_line(rtrim(
                                        lpad('Gets'        , gc_colsz_latch_value)
                        || gc_colsep || lpad('Misses'      , gc_colsz_latch_value)
                        || gc_colsep || lpad('Imm Gets'    , gc_colsz_latch_value)
                        || gc_colsep || lpad('Imm Misses'  , gc_colsz_latch_value)
                        || gc_colsep || lpad('Spin Gets'   , gc_colsz_latch_value)
                        || gc_colsep || lpad('Sleeps'      , gc_colsz_latch_value)
                        || gc_colsep || lpad('Xtra Sleep'  , gc_colsz_latch_value)
                        || gc_colsep || lpad('Wait (ms)'   , gc_colsz_latch_value)
                        || gc_colsep || rpad('Latch Name', 50) 
                    ));
                    dbms_output.put_line(
                                        rpad('-', gc_colsz_latch_value, '-')
                        || gc_colsep || rpad('-', gc_colsz_latch_value, '-')
                        || gc_colsep || rpad('-', gc_colsz_latch_value, '-')
                        || gc_colsep || rpad('-', gc_colsz_latch_value, '-')
                        || gc_colsep || rpad('-', gc_colsz_latch_value, '-')
                        || gc_colsep || rpad('-', gc_colsz_latch_value, '-')
                        || gc_colsep || rpad('-', gc_colsz_latch_value, '-')
                        || gc_colsep || rpad('-', gc_colsz_latch_value, '-')
                        || gc_colsep || rpad('-', 50, '-')
                    );
                end if;
                dbms_output.put_line(rtrim(
                       safe_lpad(fmt_int(l_rec.gets), gc_colsz_latch_value)
                    || gc_colsep
                    || safe_lpad(fmt_int(l_rec.misses), gc_colsz_latch_value)
                    || gc_colsep
                    || safe_lpad(fmt_int(l_rec.immediate_gets), gc_colsz_latch_value)
                    || gc_colsep
                    || safe_lpad(fmt_int(l_rec.immediate_misses), gc_colsz_latch_value)
                    || gc_colsep
                    || safe_lpad(fmt_int(l_rec.spin_gets), gc_colsz_latch_value)
                    || gc_colsep
                    || safe_lpad(fmt_int(l_rec.sleeps), gc_colsz_latch_value)
                    || gc_colsep
                    || safe_lpad(fmt_int(l_rec.sleeps + l_rec.spin_gets - l_rec.misses),
                            gc_colsz_latch_value)
                    || gc_colsep
                    || safe_lpad(fmt_wait_time(l_rec.wait_time), gc_colsz_latch_value)
                    || gc_colsep
                    || safe_rpad(l_rec.name, 50)
                ));
            end if;
        end loop;
        
        if c_latch_diff%rowcount = 0 then
            dbms_output.put_line('No change.');  /* Can you believe that? */
        end if;
        close c_latch_diff;

        if l_cnt_out > 1 then dbms_output.new_line; end if;

        /* Summary: ignored rows */
        if l_cnt_ignored > 0 then
            dbms_output.put_line(
                'Ignored row' || case when l_cnt_ignored > 1 then 's' end
                || ': ' || l_cnt_ignored 
                || ' (cond: gets < ' || to_char(l_latch_min_gets) || ')'
                || '; of which total gets: ' || to_char(l_ign_gets) 
                || ', misses: ' || to_char(l_ign_misses)
                || ', wait(ms): '|| fmt_wait_time(l_ign_wait_time, false)
            );
        end if;

        /* Summary: elapsed time + total latch wait time */
        dbms_output.put_line(
            'Elapsed: ' 
            || to_char(round(ela_s(snap_time(p_sid, p_snap_from),
                                   snap_time(p_sid, p_snap_to)), 2)) || ' s'
            || ', total latch wait: ' || fmt_wait_time(l_ign_wait_time, false) || ' ms'
        );
    end print_latch_diff;


    function stat_diff(
        p_sid        in v$sesstat.sid%type,
        p_snap_from  in number default 1,
        p_snap_to    in number default 0
    )
    return tt_v$sesstat
    pipelined
    is
        l_stat_diff t_v$sesstat;
    begin
        assert_snapshot_exists(p_sid, p_snap_from);
        assert_snapshot_exists(p_sid, p_snap_to);
        if c_stat_diff%isopen then close c_stat_diff; end if;
        open c_stat_diff(p_sid => p_sid, 
                         p_snap_from => p_snap_from,
                         p_snap_to => p_snap_to);
        loop
            fetch c_stat_diff into l_stat_diff;
            exit when c_stat_diff%notfound;
            pipe row(l_stat_diff);
        end loop;
        close c_stat_diff;
        return;
    exception
        when no_data_needed then
            if c_stat_diff%isopen then
                close c_stat_diff;
            end if;
            raise;
    end stat_diff;


    function latch_diff(
        p_sid        in v$sesstat.sid%type,
        p_snap_from  in number default 1,
        p_snap_to    in number default 0,
        p_min_gets   in number default null
    )
    return tt_v$latch
    pipelined
    is
        l_latch_diff t_v$latch;
    begin
        assert_snapshot_exists(p_sid, p_snap_from);
        assert_snapshot_exists(p_sid, p_snap_to);
        if c_latch_diff%isopen then close c_latch_diff; end if;
        open c_latch_diff(p_sid => p_sid,
                          p_snap_from => p_snap_from,
                          p_snap_to => p_snap_to,
                          p_min_gets => nvl(p_min_gets, gc_latch_min_gets));
        loop
            fetch c_latch_diff into l_latch_diff;
            exit when c_latch_diff%notfound;
            pipe row(l_latch_diff);
        end loop;
        close c_latch_diff;
        return;
    exception
        when no_data_needed then
            if c_latch_diff%isopen then
                close c_latch_diff;
            end if;
            raise;
    end latch_diff;


    function stat_snap(
        p_sid       in v$sesstat.sid%type,
        p_snap_id   in number
    )
    return tt_v$sesstat
    pipelined
    is
        l_idx pls_integer;
    begin
        if g_all_hist_sesstat.exists(p_sid) then
            if p_snap_id between 0 and g_all_hist_sesstat(p_sid).count - 1 then
                l_idx := g_all_hist_sesstat(p_sid).count - p_snap_id;
                for i in g_all_hist_sesstat(p_sid)(l_idx).first 
                        .. g_all_hist_sesstat(p_sid)(l_idx).last
                loop
                    pipe row (g_all_hist_sesstat(p_sid)(l_idx)(i));
                end loop;
            end if;
        end if;
        return;
    end stat_snap;


    function latch_snap(
        p_sid        in v$sesstat.sid%type,
        p_snap_id    in number
    )
    return tt_v$latch
    pipelined
    is
        l_idx pls_integer;
    begin
        if g_all_hist_latch.exists(p_sid) then
            if p_snap_id between 0 and g_all_hist_latch(p_sid).count - 1 then
                l_idx := g_all_hist_latch(p_sid).count - p_snap_id;
                for i in g_all_hist_latch(p_sid)(l_idx).first 
                        .. g_all_hist_latch(p_sid)(l_idx).last
                loop
                    pipe row (g_all_hist_latch(p_sid)(l_idx)(i));
                end loop;
            end if;
        end if;
        return;
    end latch_snap;
    

    function safe_rpad(p_val in varchar2, p_len in number, p_pad in varchar2 default ' ')
    return varchar2 is
    begin
        return rpad(nvl(p_val, p_pad),
                greatest(p_len, length(nvl(p_val, p_pad))), p_pad);
    end safe_rpad;

    
    function safe_lpad(p_val in varchar2, p_len in number, p_pad in varchar2 default ' ')
    return varchar2 is
    begin
        return lpad(nvl(p_val, p_pad),
                greatest(p_len, length(nvl(p_val, p_pad))), p_pad);
    end safe_lpad;

    
    function ela_s(p_ts_from in timestamp, p_ts_to in timestamp) return number
    is
        l_itv interval day(3) to second;
    begin
        l_itv := p_ts_to - p_ts_from;
        return
              extract(day from l_itv) * 86400
            + extract(hour from l_itv) * 3600
            + extract(minute from l_itv) * 60
            + extract(second from l_itv);
    end ela_s;

end pkg_pub_sesstat_helper;
/