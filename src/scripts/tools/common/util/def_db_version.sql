define def_db_version_ge_12   = "--"
define def_db_version_ge_12_2 = "--"
define def_db_version_ge_18   = "--"
define def_db_version_ge_19   = "--"
define def_db_version_ge_21   = "--"
define def_db_version_ge_23   = "--"

column def_db_version_ge_12   noprint new_value def_db_version_ge_12
column def_db_version_ge_12_2 noprint new_value def_db_version_ge_12_2
column def_db_version_ge_18   noprint new_value def_db_version_ge_18
column def_db_version_ge_19   noprint new_value def_db_version_ge_19
column def_db_version_ge_21   noprint new_value def_db_version_ge_21
column def_db_version_ge_23   noprint new_value def_db_version_ge_23

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
        when version_major > 12
            or (version_major = 12 and version_minor >= 2)
        then
            null
        else
            '--'
    end  as def_db_version_ge_12_2,
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
        to_number(regexp_substr(a.version, '(\d+)', 1, 1))  as version_major,
        to_number(regexp_substr(a.version, '(\d+)', 1, 2))  as version_minor
    from
        product_component_version a
    where 
        a.product like 'Oracle Database%' 
        and rownum = 1
    );

column def_db_version_ge_12   clear
column def_db_version_ge_12_2 clear
column def_db_version_ge_18   clear
column def_db_version_ge_19   clear
column def_db_version_ge_21   clear
column def_db_version_ge_23   clear

set termout on
set feedback on
