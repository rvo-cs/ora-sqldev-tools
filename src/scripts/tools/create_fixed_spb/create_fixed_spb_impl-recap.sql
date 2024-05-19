prompt
prompt ! Create a fixed SQL plan baseline?
prompt ! (Please review the following parameters, then confirm.)
prompt !
prompt ! Original SQL plan:
prompt !     SQL id:      &&def_spb_orig_sqlid
prompt !     Plan hash:   &&def_spb_orig_plan_hash
prompt !     Description: "&&def_spb_orig_plan_descr"
prompt !     Attributes:  enabled: NO, fixed: NO
prompt !
prompt ! Replacement SQL plan:
prompt !     SQL id:      &&def_spb_repl_sqlid
prompt !     Plan hash:   &&def_spb_repl_plan_hash
prompt !     Description: "&&def_spb_repl_plan_descr"
prompt !     Attributes:  enabled: YES, fixed: YES
prompt !

accept def_confirm char default "Y" prompt "Proceed with creation of this SPB? [Y] "

set termout off
column script_suffix    noprint new_value def_script_suffix
column confirm_feedback noprint new_value def_confirm_feedback
select
    case
        when user_answer in ('Y', 'YES', 'TRUE') then
            null
        else
            '-canceled'
    end as script_suffix,   -- suffix of the impl. script to start next
    case
        when user_answer in ('Y', 'YES', 'TRUE') then
            'Action confirmed'
        else
            'Canceled'
    end as confirm_feedback
from
    (select 
        upper(trim('&&def_confirm')) as user_answer
    from 
        dual);
column script_suffix    clear
column confirm_feedback clear
set termout on

prompt
prompt &&def_confirm_feedback..
prompt

@@create_fixed_spb_impl&&def_script_suffix

undefine def_confirm
undefine def_script_suffix
undefine def_confirm_feedback
