define def_db_version_ge_12 = "--"

column def_db_version_ge_12  noprint new_value def_db_version_ge_12

set termout off
set feedback off

select
    case 
        when to_number(regexp_substr(a.version, '^(\d+)')) >= 12
        then null
        else '--'
    end  as def_db_version_ge_12
from 
    product_component_version a
where 
    a.product like 'Oracle Database%' 
    and rownum = 1;

set termout on
set feedback on
