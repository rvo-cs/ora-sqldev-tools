define def_db_version_major   = ""
define def_db_version_minor   = ""

define def_db_version_ge_12   = "--"
define def_db_version_lt_12_2 = ""
define def_db_version_ge_12_2 = "--"
define def_db_version_lt_18   = ""
define def_db_version_ge_18   = "--"
define def_db_version_ge_19   = "--"
define def_db_version_ge_21   = "--"
define def_db_version_ge_23   = "--"

column db_version_major       noprint new_value def_db_version_major
column db_version_minor       noprint new_value def_db_version_minor
column def_db_version_ge_12   noprint new_value def_db_version_ge_12
column def_db_version_lt_12_2 noprint new_value def_db_version_lt_12_2
column def_db_version_ge_12_2 noprint new_value def_db_version_ge_12_2
column def_db_version_lt_18   noprint new_value def_db_version_lt_18
column def_db_version_ge_18   noprint new_value def_db_version_ge_18
column def_db_version_ge_19   noprint new_value def_db_version_ge_19
column def_db_version_ge_21   noprint new_value def_db_version_ge_21
column def_db_version_ge_23   noprint new_value def_db_version_ge_23

set termout off
set feedback off

define def_script_suffix = "--"

column def_script_suffix noprint new_value def_script_suffix
select
    case max(cols.column_name)
        when 'VERSION_FULL' then '_ge_18'
        when 'VERSION'      then '_lt_18'
        else '--'
    end  as def_script_suffix
from
    sys.all_tab_cols  cols
where
    cols.owner = 'SYS'
    and cols.table_name = 'PRODUCT_COMPONENT_VERSION'
    and cols.column_name in ('VERSION', 'VERSION_FULL');
column def_script_suffix clear

@@def_db_version&&def_script_suffix..sql

undefine def_script_suffix

column db_version_major       clear
column db_version_minor       clear
column def_db_version_ge_12   clear
column def_db_version_lt_12_2 clear
column def_db_version_ge_12_2 clear
column def_db_version_lt_18   clear
column def_db_version_ge_18   clear
column def_db_version_ge_19   clear
column def_db_version_ge_21   clear
column def_db_version_ge_23   clear

set termout on
set feedback on
