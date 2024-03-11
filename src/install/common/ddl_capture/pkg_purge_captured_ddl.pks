create or replace package pkg_purge_captured_ddl authid definer as
/*
 * SPDX-FileCopyrightText: 2021-2024 R.Vassallo
 * SPDX-License-Identifier: BSD Zero Clause License
 */

    subtype t_interval_ds0  is interval day to second(0);

    /*
     * Names of the pre-DDL/post-DDL capture tables
     */
    gc_pre_ddl_table     constant user_tables.table_name %type := '&&def_pre_ddl_table';
    gc_post_ddl_table    constant user_tables.table_name %type := '&&def_post_ddl_table';

   $if $$ddl_capture_grant_details $then
    gc_pre_grant_table   constant user_tables.table_name %type := '&&def_pre_grant_table';
    gc_post_grant_table  constant user_tables.table_name %type := '&&def_post_grant_table';
   $end
   
    /*
     * Number of top-most partitions which are always preserved (ignored)
     * when purging.
     */
    gc_retention_parts   constant number := &&def_purge_retention_weeks;
    
    /*
     * Retention period: any partition touching that period will be kept.
     */
    gc_retention_period  constant t_interval_ds0 := numtodsinterval(&&def_purge_retention_days, 'DAY');

    procedure purge(
        p_table_name        in  varchar2,
        p_dry_run           in  boolean         default true,
        p_retention_period  in  t_interval_ds0  default null
    );

end pkg_purge_captured_ddl;
/
