set echo off

define def_object_type = "&1"
define def_schema_name = "&2"
define def_object_name = "&3"

whenever sqlerror exit failure rollback
whenever oserror exit failure rollback

set verify off

@@genddl-settings

set termout off
set feedback off

define def_db_name              = ""
define def_schema_name_xc       = ""
define def_schema_name_xc_int   = ""
define def_object_type_xc       = ""
define def_object_type_sfn      = ""
define def_object_name_xc       = ""
define def_object_name_xc_int   = ""
define def_ivalid_schema        = ""
define def_errmsg_schema        = ""
define def_ivalid_objnam        = ""
define def_errmsg_objnam        = ""

define def_simple_schema_name   = "--"
define def_complex_schema_name  = "--"

column def_simple_schema_name   noprint new_value def_simple_schema_name
column def_complex_schema_name  noprint new_value def_complex_schema_name

define def_simple_object_name   = "--"
define def_complex_object_name  = "--"

column def_simple_object_name   noprint new_value def_simple_object_name
column def_complex_object_name  noprint new_value def_complex_object_name

whenever sqlerror continue none

select
    nvl2('&&def_schema_name', null, null) as def_simple_schema_name,
    '--' as def_complex_schema_name
from
    dual;

select
    '--' as def_simple_schema_name,
    nvl2(&&def_schema_name, null, null) as def_complex_schema_name
from 
    dual;

select
    nvl2('&&def_object_name', null, null) as def_simple_object_name,
    '--' as def_complex_object_name
from
    dual;

select
    '--' as def_simple_object_name,
    nvl2(&&def_object_name, null, null) as def_complex_object_name
from 
    dual;
    
whenever sqlerror exit failure rollback

column def_db_name              noprint new_value def_db_name
column def_schema_name_xc       noprint new_value def_schema_name_xc
column def_schema_name_xc_int   noprint new_value def_schema_name_xc_int
column def_ivalid_schema        noprint new_value def_ivalid_schema
column def_errmsg_schema        noprint new_value def_errmsg_schema

select
    sys_context('USERENV', 'DB_NAME')     as def_db_name,
    max(a.username)                       as def_schema_name_xc,
    replace(max(username), '''', '''''')  as def_schema_name_xc_int,
    case
        when count(*) = 0 then 'error'
        when count(*) > 1 then 'error'
        else 'ok'
    end as def_ivalid_schema,
    case
        when count(*) = 0 then '*** ERROR, schema name not found'
        when count(*) > 1 then '*** ERROR, more than one matching schema name'
    end as def_errmsg_schema
from
    dba_users a
where
    lnnvl('&&def_simple_schema_name' = '&&def_complex_schema_name')
    &&def_simple_schema_name    and upper(a.username) = upper('&&def_schema_name')
    &&def_complex_schema_name   and a.username = &&def_schema_name
;

column def_object_type_xc       noprint new_value def_object_type_xc
column def_object_type_sfn      noprint new_value def_object_type_sfn
column def_object_name_xc       noprint new_value def_object_name_xc
column def_object_name_xc_int   noprint new_value def_object_name_xc_int
column def_ivalid_objnam        noprint new_value def_ivalid_objnam
column def_errmsg_objnam        noprint new_value def_errmsg_objnam

select
    max(a.object_type)                              as def_object_type_xc,
    replace(lower(max(a.object_type)), ' ', '_')    as def_object_type_sfn,
    max(a.object_name)                              as def_object_name_xc,
    replace(max(object_name), '''', '''''')         as def_object_name_xc_int,
    case
        when count(*) = 0 then 'error'
        when count(*) > 1 then 'error'
        else 'ok'
    end as def_ivalid_objnam,
    case
        when count(*) = 0 then '*** ERROR, object not found'
        when count(*) > 1 then '*** ERROR, more than one matching object'
    end as def_errmsg_objnam
from
    dba_objects a
where
    lnnvl('&&def_simple_object_name' = '&&def_complex_object_name')
    and a.object_type = upper('&def_object_type')
    and a.owner = '&&def_schema_name_xc_int'
    &&def_simple_object_name    and upper(a.object_name) = upper('&&def_object_name')
    &&def_complex_object_name   and a.object_name = &&def_object_name
;

set termout on

@@genddl/genddl-fname-&&def_spool_naming_scheme

@@genddl/genddl-&&def_ivalid_schema-&&def_ivalid_objnam

set feedback on

undefine def_db_name
undefine def_schema_name
undefine def_schema_name_xc
undefine def_schema_name_xc_int
undefine def_simple_schema_name
undefine def_complex_schema_name
undefine def_object_type
undefine def_object_type_xc
undefine def_object_type_sfn
undefine def_object_name
undefine def_object_name_xc
undefine def_object_name_xc_int
undefine def_simple_object_name
undefine def_complex_object_name
undefine def_ivalid_schema
undefine def_errmsg_schema
undefine def_ivalid_objnam
undefine def_errmsg_objnam
undefine def_constraint_pk_as_alter
undefine def_constraint_unique_as_alter
undefine def_constraint_check_as_alter
undefine def_cnstraint_foreign_as_alter
undefine def_cnstraint_notnull_as_alter
undefine def_print_private_synonyms
undefine def_print_public_synonyms
undefine def_strip_object_schema
undefine def_strip_segment_attrs
undefine def_strip_tablespace_clause
undefine def_sort_table_grants
undefine def_spool_directory
undefine def_spool_filename
undefine def_spool_naming_scheme
undefine 1
undefine 2
undefine 3

whenever sqlerror continue none
whenever oserror continue none
