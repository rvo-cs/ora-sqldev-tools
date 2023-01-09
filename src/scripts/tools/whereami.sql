set feedback off
set termout off
set verify off

define def_db_name          = ""
define def_db_info          = ""
define def_inst_name        = ""
define def_inst_num         = ""
define def_session_id       = ""
define def_con_name         = ""
define def_session_user     = ""
define def_current_schema   = ""
define def_diag_trace       = ""
define def_trace_file       = ""

column db_name         noprint  new_value def_db_name
column db_info         noprint  new_value def_db_info
column inst_name       noprint  new_value def_inst_name
column inst_num        noprint  new_value def_inst_num
column session_id      noprint  new_value def_session_id
column con_name        noprint  new_value def_con_name
column session_user    noprint  new_value def_session_user
column current_schema  noprint  new_value def_current_schema
column diag_trace      noprint  new_value def_diag_trace
column trace_file      noprint  new_value def_trace_file

select
    sys_context('USERENV', 'DB_NAME')           as db_name,
    sys_context('USERENV', 'INSTANCE_NAME')     as inst_name,
    sys_context('USERENV', 'INSTANCE')          as inst_num,
    sys_context('USERENV', 'SID')               as session_id,
    sys_context('USERENV', 'SESSION_USER')      as session_user,
    sys_context('USERENV', 'CURRENT_SCHEMA')    as current_schema,
    (select value
       from v$diag_info
      where inst_id = sys_context('USERENV', 'INSTANCE')
        and name = 'Diag Trace')                as diag_trace,
    (select regexp_replace(value, '^.*/')
       from v$diag_info
      where inst_id = sys_context('USERENV', 'INSTANCE')
        and name = 'Default Trace File')        as trace_file
from 
    dual;

variable CON_NAME   varchar2(128 byte)
variable CON_ID     varchar2(128 byte)
variable DB_VERSION varchar2(10 byte)

declare
    e_invalid_identifier    exception;
    e_invalid_userenv_param exception;
    pragma exception_init(e_invalid_identifier    , -904);
    pragma exception_init(e_invalid_userenv_param , -2003);

    l_version_string varchar2(20 byte);
begin
    <<get_version_post_18c>>
    begin
        -- version_full is available beginning with 18.1
        execute immediate
            q'{select 
                  regexp_substr(v.version_full, '^(\d+\.\d+)')
              from
                  product_component_version v
              where
                  v.product like 'Oracle Database%'
              }'
            into l_version_string;
    exception
        when e_invalid_identifier then
            null;
    end get_version_post_18c;

    if l_version_string is null then
        <<get_version_pre_18c>>
        begin
            execute immediate
                q'{select 
                      regexp_substr(v.version, '^(\d+(\.\d+){3})')
                  from
                      product_component_version v
                  where
                      v.product like 'Oracle Database%'
                  }'
                into l_version_string;
        exception
            when others then
                null;
        end get_version_pre_18c;
    end if;
    
    :DB_VERSION := l_version_string;

    <<get_container_info>>
    begin
        select
            sys_context('USERENV', 'CON_NAME')  as con_name,
            sys_context('USERENV', 'CON_ID')    as con_id
        into
            :CON_NAME,
            :CON_ID
        from
            dual;
    exception
        when e_invalid_userenv_param then
            null;
    end get_container_info;
end;
/

select nvl(:CON_NAME, '--N/A--')  as con_name from dual;

select 
    case
        when :DB_VERSION is not null then
            '(version: ' || :DB_VERSION 
            || case
                   when to_number(:CON_ID) = 0 then 
                       '; non-CDB'
                   when to_number(:CON_ID) = 1 then 
                       '; CDB'
                   when to_number(:CON_ID) > 1 then
                       '; PDB'
               end
            || ')'
    end as db_info
from
    dual;

set termout on

prompt
prompt __You are HERE__  [ &&_DATE ]
prompt
prompt Database        : &&def_db_name  &&def_db_info
prompt Instance        : &&def_inst_name
prompt Inst#           : &&def_inst_num
prompt Session id.     : &&def_session_id
prompt Container Name  : &&def_con_name
prompt Session user    : &&def_session_user
prompt Current schema  : &&def_current_schema
prompt Deft trace file : &&def_trace_file
prompt Diag trace dir  : &&def_diag_trace
prompt 

set serveroutput on

declare
    procedure print_first_enabled_role( p_role_list in sys.odcivarchar2list )
    is
    begin
        if p_role_list is not null and p_role_list.count > 0 then
            for i in p_role_list.first .. p_role_list.last loop
                if dbms_session.is_role_enabled(p_role_list(i)) then
                    dbms_output.put_line('Role ' || p_role_list(i) || ' is enabled.');
                    return;
                end if;
            end loop;
        end if;
    end print_first_enabled_role;
begin
    print_first_enabled_role( sys.odcivarchar2list( 'DBA'
                                                  , 'SELECT_CATALOG_ROLE'
                                                  ) );
    if sys_context('USERENV', 'ISDBA') = 'TRUE' then
        dbms_output.put_line('*** You have SYSDBA privileges ***');
    end if;
end;
/

prompt

/*---- Clean-up ----*/

set verify on

column db_name         clear
column db_info         clear
column inst_name       clear
column inst_num        clear
column session_id      clear
column con_name        clear
column session_user    clear
column current_schema  clear
column diag_trace      clear
column trace_file      clear

undefine def_db_name
undefine def_db_info
undefine def_inst_name
undefine def_inst_num
undefine def_session_id
undefine def_con_name
undefine def_session_user
undefine def_current_schema
undefine def_diag_trace
undefine def_trace_file

set feedback 6
