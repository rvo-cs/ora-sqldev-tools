select
    case
        when sqlcode < 0    then 'SQLDEV:GAUGE:0:100:100:100:0' -- Red
        when sqlcode = 100  then 'SQLDEV:GAUGE:0:100:0:0:0'     -- Green
        when sqlcode is null
            and sqlerrm is not null then 'SQLDEV:GAUGE:0:100:0:100:0' -- Orange
    end         as wl
    , lineno    as line#
    , text
    , sqlerrm   as note
    , file#
    , filepath
from 
    table(c##pkg_pub_textfile_viewer.file_text(
              p_dirname    => :DIAG_TRACE_DIR,   -- Directory object for the diag trace OS directory
              p_filename   => :TRC_FILE_NAME     -- Name of the trace file (*.trc)
         ));
