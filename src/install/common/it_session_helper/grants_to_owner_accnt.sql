define def_is_dba_or_sysdba = ""

set termout off

column is_dba_or_sysdba noprint new_value def_is_dba_or_sysdba

select
    case
        when sys_context('USERENV', 'ISDBA') = 'TRUE' then
            'sysdba'
        else
            'dba'
    end as is_dba_or_sysdba
from
    dual;

column is_dba_or_sysdba clear

set termout on

@@grants_to_owner_accnt-&&def_is_dba_or_sysdba

undefine def_is_dba_or_sysdba
