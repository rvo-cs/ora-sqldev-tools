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
  
    /*
        Returns the contents of the log file of the specified Data Pump job.
        The job must be listed in USER_DATAPUMP_JOBS (if the session user owns
        the job) or in DBA_DATAPUMP_JOBS, and the master table must exist. If
        returning all the lines from the log file is not needed, limits can be
        specified as to the maximum number of lines to be returned, either at
        the head end or at the tail end of the file, or both.
     */
    function datapump_job_log_text (
        p_owner_name      in varchar2,                  -- owner of the Data Pump job
        p_job_name        in varchar2,                  -- name of the Data Pump job
        p_head_limit      in number     default null,   -- max. lines from the head end
        p_tail_limit      in number     default null    -- max. lines from the tail end
    )
    return pkg_pub_textfile_viewer.tt_rec_line
    pipelined;

end pkg_pub_datapump_log_viewer;
/
