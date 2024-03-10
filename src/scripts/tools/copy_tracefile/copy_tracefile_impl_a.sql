-- Prompt for the name of the source directory object, and for the name
-- of the trace file to be copied, if they were not specified as arguments.

@@accept_dirname&&def_dirname_ind..sql
@@accept_trcfile&&def_tracefile_ind..sql

-- The filespec of the spool file is always derived, as follows, if not
-- specified as argument, so we never prompt for it.

set termout off
column destfile noprint new_value def_destfile
select
    coalesce('&&def_destfile',
             nvl2('&&def_default_dest_folder', 
                  '&&def_default_dest_folder' || '&&def_dir_sep',
                  null) || '&&def_tracefile') as destfile
from
    dual;
column destfile clear
set termout on

-- Display the trace file to be copied, and the file specification of the 
-- destination file; then prompt the user for confirmation of the copy

prompt
prompt ! Trace file copy:
prompt !
prompt ! From:
prompt !     Directory: &&def_dirname
prompt !     Filename:  &&def_tracefile
prompt ! To:
prompt !     Filespec:  &&def_destfile
prompt !

accept def_confirm char default "Y" prompt "Proceed with trace file copy? [Y] "

set termout off
column script_suffix noprint new_value def_script_suffix
select
    case
        when user_answer in ('Y', 'YES', 'TRUE') then
            'b'
        else
            'a-canceled'
    end as script_suffix  -- suffix of the impl. script to start next
from
    (select 
        upper(trim('&&def_confirm')) as user_answer
    from 
        dual);
column script_suffix clear
set termout on

@@copy_tracefile_impl_&&def_script_suffix

undefine def_confirm
undefine def_script_suffix
