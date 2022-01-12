create or replace package pkg_pub_textfile_viewer authid current_user as
/*
 * PACKAGE
 *      pkg_pub_textfile_viewer
 *
 * PURPOSE
 *      A package for enabling to read text files on the database server host 
 *      through pipeline table functions. This is mostly intended as an easy
 *      way to browse Data Pump log files.
 *
 * SECURITY
 *      This package is defined as AUTHID CURRENT USER and runs with the
 *      privileges of the caller.
 *
 *      EXECUTE on this package may be granted to PUBLIC.
 *
 *      Remark: this package uses UTL_FILE internally for file access,
 *      therefore EXECUTE on SYS.UTL_FILE is needed both at compile time
 *      and when running this package.
 *
 * CHARACTER ENCODING
 *      Files read through this package should be in the same encoding
 *      as the database character set. This is a requirement of UTL_FILE.
 *
 */
  
    /* Max line size, in bytes */
    gc_max_line_size  constant number  := 4000;


    /*
        The record type to be returned by pipeline functions: 1 record is returned
        for each line of each file that we read; extra records are returned in order
        to notify of events such as end-of-file, I/O errors, etc.
        
          o FILE# is the file number, counting from 1, to which the record pertains.
            This is only useful when reading from more than 1 file in the same call.
          
          o DIRNAME is the name of the directory object containing the target file.
        
          o FILENAME is the base name of the target file
        
          o FILEPATH is the full path of the target file
          
          o LINENO is the line number, relative to the target file
          
          o TEXT is the content of the line, limited to 4000 bytes. Lines longer
            than that will be truncated if their length is less than or equal to
            32K characters; lines longer than that will cause a non-recoverable
            ORA-29284 read error.
            
          o SQLCODE is NULL, except in the following situations:
              . at end-of-file: +100
              . in case of errors: sqlcode < 0
                
          o SQLERRM is null, except in the following situations
              . when sqlcode < 0: sqlerrm contains the corresponding message
                (Please remind that: "ORA-29283: invalid file operation" is
                very likely to mean "no such file or directory".)
              . when sqlcode = 100: sqlerrm is "[End of file]"
              . when lines are skipped due to head/tail limits: sqlerrm is a
                message to make that clear, e.g. "[...Skipping NNN lines...]"
          
     */
    type t_rec_line is record (
        file#       number,
        dirname     all_directories.directory_name %type,
        filename    varchar2(4000 byte),
        filepath    varchar2(4000 byte),
        lineno      number,
        text        varchar2(4000 byte),
        sqlcode     number,
        sqlerrm     varchar2(2000 byte)
    );
    
    type tt_rec_line is varray(32000) of t_rec_line;

    /*
        Returns the contents of the specified file. If returning all the lines
        from the target file is not needed, limits can be specified as to the
        maximum number of lines which should be returned, either at the head
        end or at the tail end of the file, or both.
    */
    function file_text (
        p_dirname     in varchar2,              -- directory object to read from
        p_filename    in varchar2,              -- base name of the target file
        p_head_limit  in number  default null,  -- max. lines to return from the head end
        p_tail_limit  in number  default null   -- max. lines to return from the tail end
    )
    return tt_rec_line
    pipelined;
    

    /*
        Returns the contents of the specified files. If returning all the lines
        from all the specified files is not needed, limits can be specified as to
        the maximum number of lines which should be returned, either at the head
        end or at the tail end, or both. These limits may apply to each and every
        file separately, or to all the files globally as if they were concatenated
        into a single file.
    */
    function file_text (
        p_list_files      in sys.odcivarchar2list,      -- list of file specifications
                                                        -- (syntax: DIRNAME:FILENAME)
        p_head_limit      in number     default null,   -- max. lines from the head end
        p_tail_limit      in number     default null,   -- max. lines from the tail end
        p_per_file_limit  in varchar2   default 'N'     -- limits are per-file if 'Y'
    )
    return tt_rec_line
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
        p_owner_name      in varchar2,                  -- owner of the Data Pump job
        p_job_name        in varchar2,                  -- name of the Data Pump job
        p_head_limit      in number     default null,   -- max. lines from the head end
        p_tail_limit      in number     default null    -- max. lines from the tail end
    )
    return tt_rec_line
    pipelined;

end pkg_pub_textfile_viewer;
/
