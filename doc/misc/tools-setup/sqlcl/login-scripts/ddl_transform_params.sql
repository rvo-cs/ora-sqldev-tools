@&&RVOCS_ORASQLDEVTOOLS_DIR/src/scripts/tools/common/util/def_db_version

set termout off
set feedback off

define def_script_suffix = "12.1-"

column def_script_suffix noprint new_value def_script_suffix
select
    nvl2('&&def_db_version_ge_12_2', '12.1-', '12.2+') as def_script_suffix
from
    dual;
column def_script_suffix clear

@@ddl_transform_params/ddl_transform_params-&&def_script_suffix..sql

undefine def_script_suffix

set termout on
set feedback on

@&&RVOCS_ORASQLDEVTOOLS_DIR/src/scripts/tools/common/util/undef_db_version
