create or replace package pkg_pub_sesstat_helper authid current_user as
/*
 * SPDX-FileCopyrightText: 2021 R.Vassallo
 * SPDX-License-Identifier: BSD Zero Clause License
 */

/*
 * PACKAGE
 *      pkg_pub_sesstat_helper
 *
 * PURPOSE
 *      A package for taking snapshots of session statistics (V$SESSTAT)
 *      of a specified session, and computing differences between successive
 *      snapshots. Also snapshots and optionally reads out differences in
 *      instance-wide latch statistics (V$LATCH).
 *      
 *      Snapshots are kept in package-global collections in the private
 *      memory of the calling session, and are not persisted.
 *
 * SECURITY
 *      This package is defined as AUTHID CURRENT USER and runs with the
 *      privileges of the caller; the caller needs the SELECT permission,
 *      either directly or through a role, on the following views:
 *
 *          . V$SESSTAT
 *          . V$STATNAME
 *          . V$LATCH
 *
 *      EXECUTE on this package may be granted to PUBLIC.
 *
 */
 
    type t_rec_snapshot is record (
        snap_id     number,     /* Snapshot id; 0 = most recent */
        snap_time   timestamp
    );
    
    type tt_rec_snapshot is table of t_rec_snapshot;

    /* 
        Session statistics -- sources: v$sesstat + v$statname 
     */
    type t_v$sesstat is record (
        statistic#  v$sesstat .statistic# %type,
        value       v$sesstat .value      %type,
        name        v$statname.name       %type,
        class#      v$statname.class      %type,
        class       v$statname.name       %type
    );
    
    type tt_v$sesstat is table of t_v$sesstat;
    
    /* 
        Latch statistics -- source: v$latch
     */
    type t_v$latch is record (
        addr                v$latch.addr      %type
      , latch#              v$latch.latch#    %type
      , level#              v$latch.level#    %type
      , name                v$latch.name      %type
      , gets                v$latch.gets      %type
      , misses              v$latch.misses    %type
      , sleeps              v$latch.sleeps    %type
      , immediate_gets      v$latch.immediate_gets   %type
      , immediate_misses    v$latch.immediate_misses %type
      , spin_gets           v$latch.spin_gets %type
      , wait_time           v$latch.wait_time %type
     $IF not dbms_db_version.ver_le_11_2 $THEN
      , con_id              v$latch.con_id    %type
     $END
    );
    
    type tt_v$latch is table of t_v$latch;

    /*
        Takes a snapshot of session statistics of the specified session.
        (Also snapshots instance-wide latch statistics).
     */
    procedure snap(p_sid in v$sesstat.sid%type);

    /*
        Returns the time when the specified snapshot was taken for
        the specified session. Snapshots are identified by integer
        numbers, as follows:
            0 is the most recent snapshot
            1 is the second latest snapshot
            ... and so forth...
            N is the earliest snapshot
        (Note: each session has its own independent set of snapshots.)
     */
    function snap_time(
        p_sid       in v$sesstat.sid%type,
        p_snap_id   in number
    )
    return timestamp;
    
    /*
        Returns the list of successive snapshots of the specified
        session, from latest to earliest.
     */
    function list_snapshot(p_sid in v$sesstat.sid%type)
    return tt_rec_snapshot
    pipelined;

    /*
        Reads out the differences between 2 snapshots of the specified
        session, using DBMS_OUTPUT.
        
        Examples:
            pkg_pub_sesstat_helper.print_diff(371);
                Prints diffs in session statistics between the 2 latest snapshots
                of the target session (sid = 371)

            pkg_pub_sesstat_helper.print_diff(371, 'Y');
                Same as above, including diffs in (instance-wide) latch statistics

            pkg_pub_sesstat_helper.print_diff(371, p_min_gets => 10)
                Same as above, but with the latch gets threshold lowered to 10
                
            pkg_pub_sesstat_helper.print_diff(371, 'Y', 2);
                Prints diffs in session and latch statistics, between snapshot 2
                (the 3rd most recent) and snapshot 0 (the latest).
                
            pkg_pub_sesstat_helper.print_diff(371, p_snap_from => 2);
                Prints diffs in session statistics only, between snapshots 2 and 0.
                (Remark: using the named argument syntax is needed here!)
     */
    procedure print_diff(
        p_sid               in v$sesstat.sid%type,    /* Target session */
        p_print_latch_diff  in varchar2 default 'N',  /* Include latch statistics? */
        p_snap_from         in number   default 1,    /* From snapshot? */
        p_snap_to           in number   default 0,    /* To snapshot? */
        p_min_gets          in number   default null, 
                                /* Latch gets ignore threshold: latches with differences
                                   in gets lower than this are ignored in the readout.
                                   (Null = use the default value: 100) */
        p_with_vsep         in varchar2 default 'Y'
                                /* Add a vertical separator before/after the report? */
    );
    
    /*
        Reads out the differences in session statistics between 2 snapshots
        of the specified session, using DBMS_OUTPUT.
     */
    procedure print_stat_diff(
        p_sid        in v$sesstat.sid%type,  /* Target session */
        p_snap_from  in number default 1,    /* From snapshot? */
        p_snap_to    in number default 0     /* To snaphot? */
    );

    /*
        Reads out the differences in instance-wide latch statistics between 
        2 snapshots of the specified session, using DBMS_OUTPUT.
     */
    procedure print_latch_diff(
        p_sid        in v$sesstat.sid%type,  /* Target session */
        p_snap_from  in number default 1,    /* From snapshot? */
        p_snap_to    in number default 0,    /* To snapshot? */
        p_min_gets   in number default null
                                /* Latch gets ignore threshold: latches with differences
                                   in gets lower than this are ignored in the readout.
                                   (Null = use the default value: 100) */
    );

    /*
        Returns 1 row for each difference in session statistics between 2
        snapshots of the specified session. This is similar to print_stat_diff,
        but as a pipelined table function.
     */
    function stat_diff(
        p_sid        in v$sesstat.sid%type,  /* Target session */
        p_snap_from  in number default 1,    /* From snapshot? */
        p_snap_to    in number default 0     /* To snapshot? */
    )
    return tt_v$sesstat
    pipelined;
    
    /*
        Returns 1 row for each difference in (instance-wide) latch statistics between
        2 snapshots of the specified session. This is similar to print_latch_diff, but
        as a pipelined table function.
     */
    function latch_diff(
        p_sid        in v$sesstat.sid%type,  /* Target session */
        p_snap_from  in number default 1,    /* From snapshot? */
        p_snap_to    in number default 0,    /* To snapshot? */
        p_min_gets   in number default null
                                /* Latch gets ignore threshold: latches with differences
                                   in gets lower than this are ignored in the readout.
                                   (Null = use the default value: 100) */
    )
    return tt_v$latch
    pipelined;

    /*
        Returns the whole set of session statistics in the specified snapshot
        of the specified session. [Used internally.]
     */
    function stat_snap(
        p_sid       in v$sesstat.sid%type,
        p_snap_id   in number
    )
    return tt_v$sesstat
    pipelined;

    /*
        Returns the whole set of (instance-wide) latch statistics in the specified
        snapshot of the specified session. [Used internally.]
     */
    function latch_snap(
        p_sid       in v$sesstat.sid%type,
        p_snap_id   in number
    )
    return tt_v$latch
    pipelined;

end pkg_pub_sesstat_helper;
/
