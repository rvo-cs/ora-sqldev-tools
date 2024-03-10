-- Try to read the 1st line of the input trace file: this is enough to 
-- determine if it can't be read because of common reasons such as: wrong
-- directory object, or file not found. In that case, we'll have avoided
-- creating a useless file in the destination folder.

set termout off
column script_suffix noprint new_value def_script_suffix
column diag_msg      noprint new_value def_diag_msg
select
    case
        when ftxt.sqlcode not in (0, 100) then
            'b-error'
        else
            'c'
    end as script_suffix,   -- suffix of the impl. script to start next
    case
        when ftxt.sqlcode not in (0, 100) then
            'File copy failed: &&def_tracefile' || chr(10)
            || ftxt.sqlerrm
    end as diag_msg         -- error message
from 
    table(c##pkg_pub_textfile_viewer.file_text(
              p_dirname    => '&&def_dirname', 
              p_filename   => '&&def_tracefile'
         )) ftxt
where
    rownum <= 1;
column script_suffix clear
column diag_msg      clear
set termout on

@@copy_tracefile_impl_&&def_script_suffix

undefine def_script_suffix
undefine def_diag_msg
