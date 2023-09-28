define def_db_version_ge_12 = "--"
define def_db_version_ge_18 = "--"
define def_db_version_ge_19 = "--"
define def_db_version_ge_21 = "--"
define def_db_version_ge_23 = "--"

column def_db_version_ge_12  noprint new_value def_db_version_ge_12
column def_db_version_ge_18  noprint new_value def_db_version_ge_18
column def_db_version_ge_19  noprint new_value def_db_version_ge_19
column def_db_version_ge_21  noprint new_value def_db_version_ge_21
column def_db_version_ge_23  noprint new_value def_db_version_ge_23

set termout off
set feedback off

select
    case 
        when version_major >= 12 then
            null
        else
            '--'
    end  as def_db_version_ge_12,
    case 
        when version_major >= 18 then
            null
        else
            '--'
    end  as def_db_version_ge_18,
    case 
        when version_major >= 19 then
            null
        else
            '--'
    end  as def_db_version_ge_19,
    case 
        when version_major >= 21 then
            null
        else
            '--'
    end  as def_db_version_ge_21,
    case 
        when version_major >= 23 then
            null
        else
            '--'
    end  as def_db_version_ge_23
from 
    (select
        to_number(regexp_substr(a.version, '^(\d+)'))  as version_major
    from
        product_component_version a
    where 
        a.product like 'Oracle Database%' 
        and rownum = 1
    );

set termout on
set feedback on
