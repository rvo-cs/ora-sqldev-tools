/*
  Create the periodic purge job
 */
begin
    dbms_scheduler.create_job(
        job_name    => sys_context('USERENV', 'CURRENT_SCHEMA') || '.' || '&&def_purge_job_name',
        job_type    => 'PLSQL_BLOCK',
        job_action  => q'<begin
                            dbms_output.enable(null);
                            pkg_purge_itsesshlplog.run_purge(p_dry_run => false);
                         end;>',
        start_date  => sysdate,
        repeat_interval => '&&def_purge_repeat_interval',
        enabled     => true,
        auto_drop   => false,
        comments    => 'Periodic purge of the log table'
    );
end;
/

/*
  Run the job once, in order to pre-create the current partition and the next one.
  This enables to set "_partition_large_extents"=false at partition-creation time.
*/
begin
    dbms_scheduler.run_job(
        job_name => sys_context('USERENV', 'CURRENT_SCHEMA') || '.' || '&&def_purge_job_name',
        use_current_session => false
    );
end;
/

