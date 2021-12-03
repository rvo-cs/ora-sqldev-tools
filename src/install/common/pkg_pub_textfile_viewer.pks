create or replace package pkg_pub_textfile_viewer authid current_user as

    /* Max line size in bytes */
    gc_max_line_size  constant number  := 4000;

    type t_rec_line is record (
        dirname     all_directories.directory_name %type,
        filename    varchar2(4000 byte),
        filepath    varchar2(4000 byte),
        lineno      number,
        text        varchar2(4000 byte),
        sqlcode     number,
        sqlerrm     varchar2(2000 byte)
    );
    
    type tt_rec_line is table of t_rec_line;

    function file_text (
        p_dirname     in varchar2,
        p_filename    in varchar2,
        p_head_limit  in number     default null,
        p_tail_limit  in number     default null
    )
    return tt_rec_line
    pipelined;
    
    
    function datapump_job_log_text (
        p_owner_name      in varchar2,
        p_job_name        in varchar2,
        p_head_limit      in number     default null,
        p_tail_limit      in number     default null,
        p_per_file_limit  in varchar2   default 'N'  
    )
    return tt_rec_line
    pipelined;

end pkg_pub_textfile_viewer;
/
