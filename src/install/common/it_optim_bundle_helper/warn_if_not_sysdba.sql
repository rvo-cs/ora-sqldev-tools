define def_is_not_sysdba = ""

set termout off
column is_not_sysdba noprint new_value def_is_not_sysdba
select
    case
        when sys_context('USERENV', 'ISDBA') = 'TRUE' then
            '--'
        else
            null
    end as is_not_sysdba
from
    dual;
column is_not_sysdba clear
set termout on

set heading off
set feedback off
column nc noprint
select
    &&def_is_not_sysdba 'WARNING: you are not SYSDBA' as errmsg,
    1 as nc
from
    dual;
set heading on
set feedback on

prompt

undefine def_is_not_sysdba
