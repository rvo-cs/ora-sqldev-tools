set verify off
set linesize 32000

-- Copy of the trace file into the destination (spool) file

set trimspool on
set heading off
set feedback off
set pagesize 0

column rn      noprint new_value def_rn
column sqlcode noprint new_value def_sqlcode
column sqlerrm noprint new_value def_sqlerrm
column text    format a32000

spool "&&def_destfile"
set termout off

select
    rownum - 1 as rn,
    ftxt.sqlcode,
    ftxt.sqlerrm,
    ftxt.text
from 
    table(c##pkg_pub_textfile_viewer.file_text(
              p_dirname    => '&&def_dirname', 
              p_filename   => '&&def_tracefile'
         )) ftxt;

set termout on
spool off

column rn      clear
column sqlcode clear
column sqlerrm clear
column text    clear

set heading on
set feedback on
set pagesize 15
set linesize 200
set verify on

-- Print a final diagnostic message, depending on the outcome 
-- of the preceding operation

set termout off
column diag_msg noprint new_value def_diag_msg
select
    case
        when &&def_sqlcode = 100 
            and q'{&&def_sqlerrm}' = '[End of file]'
        then
            'Copy successful; line'
            || case 
                   when nvl('&&def_rn', 0) > 1 then
                       's'
               end
            || ' in file: ' || nvl(trim('&&def_rn'), '0')
        else
            'File copy failed: &&def_tracefile' || chr(10)
            || q'{&&def_sqlerrm}'
    end as diag_msg
from
    dual;
column diag_msg clear
set termout on

prompt
prompt &&def_diag_msg
prompt

undefine def_rn
undefine def_sqlcode
undefine def_sqlerrm
undefine def_diag_msg
