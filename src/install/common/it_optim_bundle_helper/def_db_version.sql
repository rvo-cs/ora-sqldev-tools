define def_db_version_major = ""
define def_db_version_minor = ""
define def_db_version_lt_12_2 = ""
define def_db_version_lt_18   = ""
define def_db_version_ge_18   = ""

set termout off
set heading off
set feedback off

column db_version_major   noprint new_value def_db_version_major
column db_version_minor   noprint new_value def_db_version_minor
column db_version_lt_12_2 noprint new_value def_db_version_lt_12_2
column db_version_lt_18   noprint new_value def_db_version_lt_18
column db_version_ge_18   noprint new_value def_db_version_ge_18
select
    to_char(version_major) as db_version_major,
    to_char(version_minor) as db_version_minor,
    case
        when version_major < 12
            or (version_major = 12 and version_minor < 2)
        then
            null
        else
            '--'
    end  as db_version_lt_12_2,
    case 
        when version_major < 18 then
            null
        else
            '--'
    end  as db_version_lt_18,
    case 
        when version_major >= 18 then
            null
        else
            '--'
    end  as db_version_ge_18
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
column db_version_major   clear
column db_version_minor   clear
column db_version_lt_12_2 clear
column db_version_lt_18   clear
column db_version_ge_18   clear

set termout on

-- Error message if the DB version < 12.2
column nc noprint
select
    &&def_db_version_lt_12_2 'ERROR: Oracle 12.2 or higher is required '
    &&def_db_version_lt_12_2 || '(your version: &&def_db_version_major..&&def_db_version_minor)' as errmsg,
    1 as nc
from
    dual;
column nc clear

prompt

-- Ensure we fail if DB version < 12.2
column nc                         noprint
column fail_if_db_version_lt_12_2 noprint
select
    &&def_db_version_lt_12_2 1/0 as fail_if_db_version_lt_12_2,
    1 as nc
from
    dual;
column nc                         clear
column fail_if_db_version_lt_12_2 clear

set heading on
set feedback on