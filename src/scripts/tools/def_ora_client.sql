define def_ora_client = "sqlplus"

column def_ora_client  noprint new_value def_ora_client

set termout off
set feedback off

select
    case
        when regexp_like(client_driver, '^jdbc')
        then 'sqlcl'    /* SQLcl or SQL Developer */
        else 'sqlplus'
    end  as def_ora_client
from 
    v$session_connect_info a
where 
    a.sid = sys_context('USERENV', 'SID')
    and rownum = 1
;

set termout on
set feedback on