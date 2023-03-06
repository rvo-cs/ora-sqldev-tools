create or replace package pkg_purge_itsesshlplog authid definer as

    subtype t_interval_ds0  is interval day(3) to second(0);

    /*
     * Name of the log table
     */
    gc_log_table_name    constant user_tables.table_name %type := '&&def_it_sess_helper_log_table';

    /*
     * Number of top-most partitions which are always preserved (ignored)
     * when purging.
     */
    gc_retention_parts   constant number := &&def_purge_retention_weeks;
    
    /*
     * Retention period: any partition touching that period will be kept.
     */
    gc_retention_period  constant t_interval_ds0 := interval '&&def_purge_retention_days' day;

    procedure run_purge(
        p_dry_run       in boolean      default true
    );

    procedure set_partition_large_extents(
        p_value    in boolean  default false,
        p_dry_run  in boolean  default true
    );

    procedure add_partition(
        p_for_datetime  in timestamp    default localtimestamp,
        p_dry_run       in boolean      default true
    );

    procedure purge(
        p_table_name        in  varchar2,
        p_dry_run           in  boolean         default true,
        p_retention_period  in  t_interval_ds0  default null
    );

end pkg_purge_itsesshlplog;
/
