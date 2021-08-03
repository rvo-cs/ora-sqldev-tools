begin
    dbms_scheduler.create_job(
        job_name    => sys_context('USERENV', 'CURRENT_SCHEMA') || '.' || '&&def_purge_job_name',
        job_type    => 'PLSQL_BLOCK',
        job_action  => q'<begin
                            pkg_purge_captured_ddl.purge(pkg_purge_captured_ddl.gc_pre_ddl_table,
                                                         p_dry_run => false);
                            dbms_output.put_line('----------------');
                            pkg_purge_captured_ddl.purge(pkg_purge_captured_ddl.gc_post_ddl_table,
                                                         p_dry_run => false);
                         end;>',
        start_date  => sysdate,
        repeat_interval => '&&def_purge_repeat_interval',
        enabled     => true,
        auto_drop   => false,
        comments    => 'Periodic purge of the pre/post-DDL capture tables'
    );
end;
/
