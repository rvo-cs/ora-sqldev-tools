create or replace package pkg_pub_datapump_log_viewer authid current_user as
/*
 * PACKAGE
 *      pkg_pub_datapump_log_viewer
 *
 * PURPOSE
 *      A package for browsing Data Pump log files.
 *
 * SECURITY
 *      This package is defined as AUTHID CURRENT USER and runs with the
 *      privileges of the caller.
 *
 *      EXECUTE on this package may be granted to PUBLIC.
 *
 * DEPENDENCIES
 *      This package relies on pkg_pub_textfile_viewer.file_text for reading
 *      the Data Pump log files. See pkg_pub_textfile_viewer for details and
 *      additional requirements.
 */

    type t_rec_datapump_log_file is record (
        job_owner      user_users.username %type,
        job_name       user_datapump_jobs.job_name %type,
        log_directory  all_directories.directory_name %type,
        log_filename   varchar2(4000 byte),
        sqlcode        number,
        sqlerrm        varchar2(2000 byte)
    );
    
    type tt_rec_datapump_log_file is table of t_rec_datapump_log_file;

    /*
        Returns the log file(s) for the specified Data Pump job. The job must
        be listed in USER_DATAPUMP_JOBS (if the session user owns the job) or
        in DBA_DATAPUMP_JOBS, and the master table must exist.

        Remark: unsure whether a single Data Pump job can have more than 1 log
        file or not, but we'll attempt to prepare for that, just in case.
     */
    function datapump_job_log (
        p_owner_name  in varchar2,      -- owner of the Data Pump job
        p_job_name    in varchar2       -- name of the Data Pump job
    )
    return tt_rec_datapump_log_file
    pipelined;
  
    /*
        Returns the contents of the log file of the specified Data Pump job.
        The job must be listed in USER_DATAPUMP_JOBS (if the session user owns
        the job) or in DBA_DATAPUMP_JOBS, and the master table must exist. If
        returning all the lines from the log file is not needed, limits can be
        specified as to the maximum number of lines to be returned, either at
        the head end or at the tail end of the file, or both.
     */
    function datapump_job_log_text (
        p_owner_name  in varchar2,                  -- owner of the Data Pump job
        p_job_name    in varchar2,                  -- name of the Data Pump job
        p_head_limit  in number     default null,   -- max. lines from the head end
        p_tail_limit  in number     default null    -- max. lines from the tail end
    )
    return pkg_pub_textfile_viewer.tt_rec_line
    pipelined;

end pkg_pub_datapump_log_viewer;
/
