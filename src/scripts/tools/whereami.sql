/*
 * SPDX-FileCopyrightText: 2021-2024 R.Vassallo
 * SPDX-License-Identifier: BSD Zero Clause License
 */

set feedback off
set termout off
set verify off
set define on
set scan on

define def_db_name          = ""
define def_db_unique_name   = ""
define def_db_role_plus     = ""
define def_db_not_open      = ""
define def_db_info          = ""
define def_inst_name        = ""
define def_inst_num         = ""
define def_instance_info    = ""
define def_session_id       = ""
define def_con_name         = ""
define def_session_user     = ""
define def_current_schema   = ""
define def_diag_trace       = ""
define def_trace_file       = ""

variable CON_NAME           varchar2(128 byte)
variable CON_ID             varchar2(128 byte)
variable DB_VERSION         varchar2(10 byte)
variable DATABASE_ROLE      varchar2(16 byte)
variable IS_DB_OPEN         varchar2(3 byte)
variable DB_OPEN_MODE       varchar2(20 byte)
variable INSTANCE_STATUS    varchar2(12 byte)
variable INSTANCE_LOGINS    varchar2(10 byte)
variable DIAG_TRACE_DIR     varchar2(512 byte)
variable DIAG_TRACE_FILE    varchar2(512 byte)

declare
    e_not_exists            exception;
    e_db_is_not_mounted     exception;
    e_db_is_not_open        exception;
    e_invalid_identifier    exception;
    e_invalid_userenv_param exception;
    pragma exception_init(e_not_exists            , -942);
    pragma exception_init(e_db_is_not_mounted     , -1507);
    pragma exception_init(e_db_is_not_open        , -1219);
    pragma exception_init(e_invalid_identifier    , -904);
    pragma exception_init(e_invalid_userenv_param , -2003);

    l_db_version_string     varchar2(20 byte);
    l_inst_version_string   varchar2(20 byte);
    l_database_role         varchar2(20 byte);
    l_is_db_open            boolean := true;
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
                  and rownum = 1
              }'
            into l_db_version_string;
    exception
        when e_db_is_not_mounted 
            or e_db_is_not_open 
        then
            l_is_db_open := false;
        when e_invalid_identifier then
            null;
    end get_version_post_18c;

    if l_is_db_open and l_db_version_string is null then
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
                into l_db_version_string;
        exception
            when others then
                null;
        end get_version_pre_18c;
    end if;
    
    <<try_v$instance>>
    begin
        execute immediate
            q'{select 
                  regexp_substr(vi.version, '(\d+(\.\d+){3})')  as db_version,
                  vi.status,
                  vi.logins
              from
                  v$instance vi
              }'
            into
                l_inst_version_string,
                :INSTANCE_STATUS,
                :INSTANCE_LOGINS;
    exception
        when e_not_exists then
            null;
    end try_v$instance;
    
    :DB_VERSION := coalesce(l_db_version_string, l_inst_version_string);
    :IS_DB_OPEN := case when l_is_db_open then 'YES' end;

    <<get_database_role>>
    begin
        select
            sys_context('USERENV', 'DATABASE_ROLE')  as database_role
        into
            l_database_role
        from
            dual;
        if l_database_role = 'PRIMARY' then
            -- Don't mention that this DB has the PRIMARY role
            -- unless it's known to have a Data Guard configured
            <<check_dg_config>>
            declare
                l_dg_config_ind number;
            begin
                execute immediate
                    q'{select
                           1 as dg_config_ind
                       from
                           v$system_parameter par
                       where
                           par.name = 'log_archive_config'
                           and lower(par.value) like '%dg\_config%' escape '\'
                       }'
                into
                    l_dg_config_ind;
            exception
                when no_data_found 
                    or e_not_exists 
                then
                    l_database_role := null;
            end check_dg_config;
        end if;
        :DATABASE_ROLE := l_database_role;
    exception
        when e_invalid_userenv_param then
            null;
    end get_database_role;

    <<get_db_open_mode>>
    begin
        execute immediate
            q'{select
                  open_mode
              from
                  v$database
              }'
        into
            :DB_OPEN_MODE;
    exception
        when e_db_is_not_mounted then
            :DB_OPEN_MODE := 'NOT MOUNTED';
        when e_not_exists then
            null;
    end get_db_open_mode;
    
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

    <<get_diag_info>>
    declare
        l_from_view varchar2(30);
    begin
        l_from_view := case
                           when l_is_db_open then
                               '"PUBLIC".v$diag_info'
                           else
                               'v$diag_info'
                       end;
        execute immediate
            q'{select
                   (select 
                        value 
                    from 
                        }' || l_from_view || q'{
                    where 
                        inst_id = sys_context('USERENV', 'INSTANCE')
                        and name = 'Diag Trace'
                   )  as diag_trace,
                   (select 
                        value 
                    from 
                        }' || l_from_view || q'{
                    where 
                        inst_id = sys_context('USERENV', 'INSTANCE')
                        and name = 'Default Trace File'
                   )  as trace_file
               from
                   dual}'
        into    
            :DIAG_TRACE_DIR,
            :DIAG_TRACE_FILE;
    exception
        when e_not_exists then
            null;
    end get_diag_info;
end;
/

column db_name         noprint  new_value def_db_name
column db_unique_name  noprint  new_value def_db_unique_name
column inst_name       noprint  new_value def_inst_name
column inst_num        noprint  new_value def_inst_num
column session_id      noprint  new_value def_session_id
column session_user    noprint  new_value def_session_user
column current_schema  noprint  new_value def_current_schema
column con_name        noprint  new_value def_con_name
column db_info         noprint  new_value def_db_info
column db_is_not_open  noprint  new_value def_db_not_open
column db_role_plus    noprint  new_value def_db_role_plus
column instance_info   noprint  new_value def_instance_info
column diag_trace      noprint  new_value def_diag_trace
column trace_file      noprint  new_value def_trace_file

select
    sys_context('USERENV', 'DB_NAME')           as db_name,
    sys_context('USERENV', 'DB_UNIQUE_NAME')    as db_unique_name,
    sys_context('USERENV', 'INSTANCE_NAME')     as inst_name,
    sys_context('USERENV', 'INSTANCE')          as inst_num,
    sys_context('USERENV', 'SID')               as session_id,
    sys_context('USERENV', 'SESSION_USER')      as session_user,
    sys_context('USERENV', 'CURRENT_SCHEMA')    as current_schema,
    nvl(:CON_NAME, '--N/A--')                   as con_name,
    nvl2(coalesce(:DB_VERSION, :CON_ID), '(', null)
        || case 
               when :DB_VERSION is not null then
                   'version: ' || :DB_VERSION
           end
        || case
               when :DB_VERSION is not null and :CON_ID is not null then
                   '; '
           end
        || case
               when to_number(:CON_ID) = 0 then 
                   'non-CDB'
               when to_number(:CON_ID) = 1 then 
                   'CDB'
               when to_number(:CON_ID) > 1 then
                   'PDB'
           end
        || nvl2(coalesce(:DB_VERSION, :CON_ID), ')', null)  as db_info,
    case
        when :IS_DB_OPEN = 'YES' then
            null
        else
            '--'
    end  as db_is_not_open, 
    nvl2(coalesce(:DATABASE_ROLE, :DB_OPEN_MODE), '(', null)
        || case
               when :DATABASE_ROLE is not null then
                   'role: ' || :DATABASE_ROLE
           end 
        || case
               when :DATABASE_ROLE is not null and :DB_OPEN_MODE is not null then
                   '; '
           end
        || case 
               when :DB_OPEN_MODE is not null then
                   'open mode: ' || :DB_OPEN_MODE
           end
        || nvl2(coalesce(:DATABASE_ROLE, :DB_OPEN_MODE), ')', null)  as db_role_plus,
    case
        when :INSTANCE_STATUS <> 'OPEN'
            or :INSTANCE_LOGINS <> 'ALLOWED'
        then
            '('
    end
        || case
               when :INSTANCE_STATUS <> 'OPEN' then
                   'status: ' || :INSTANCE_STATUS
           end
        || case
               when :INSTANCE_STATUS <> 'OPEN'
                   and :INSTANCE_LOGINS <> 'ALLOWED'
               then
                   '; '
           end
        || case
               when :INSTANCE_LOGINS <> 'ALLOWED' then
                   'logins: ' || :INSTANCE_LOGINS
           end
        || case
               when :INSTANCE_STATUS <> 'OPEN'
                   or :INSTANCE_LOGINS <> 'ALLOWED'
               then
                  ')'
           end  as instance_info,
    nvl(:DIAG_TRACE_DIR,  '?  -- v$diag_info not available')  as diag_trace,
    nvl(:DIAG_TRACE_FILE, '?  -- v$diag_info not available')  as trace_file
from
    dual;

set termout on

prompt
prompt __You are HERE__  [ &&_DATE ]
prompt
prompt Database        : &&def_db_name  &&def_db_info
prompt DB unique name  : &&def_db_unique_name  &&def_db_role_plus
prompt Instance        : &&def_inst_name  &&def_instance_info
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
    l_dummy pls_integer;  -- unused
    &&def_db_not_open  procedure print_first_enabled_role( p_role_list in sys.odcivarchar2list )
    &&def_db_not_open  is
    &&def_db_not_open  begin
    &&def_db_not_open      if p_role_list is not null and p_role_list.count > 0 then
    &&def_db_not_open          for i in p_role_list.first .. p_role_list.last loop
    &&def_db_not_open              if dbms_session.is_role_enabled(p_role_list(i)) then
    &&def_db_not_open                  dbms_output.put_line('Role ' || p_role_list(i) || ' is enabled.');
    &&def_db_not_open                  return;
    &&def_db_not_open              end if;
    &&def_db_not_open          end loop;
    &&def_db_not_open      end if;
    &&def_db_not_open  end print_first_enabled_role;
begin
    &&def_db_not_open  print_first_enabled_role( sys.odcivarchar2list( 'DBA'
    &&def_db_not_open                                                , 'SELECT_CATALOG_ROLE'
    &&def_db_not_open                                                ) );
    if sys_context('USERENV', 'ISDBA') = 'TRUE' then
        dbms_output.put_line('*** You have SYSDBA privileges ***');
    end if;
end;
/

prompt

/*---- Clean-up ----*/

set verify on

column db_name         clear
column db_unique_name  clear
column inst_name       clear
column inst_num        clear
column session_id      clear
column session_user    clear
column current_schema  clear
column con_name        clear
column db_info         clear
column db_is_not_open  clear
column db_role_plus    clear
column instance_info   clear
column diag_trace      clear
column trace_file      clear

undefine def_db_name
undefine def_db_unique_name
undefine def_inst_name
undefine def_inst_num
undefine def_session_id
undefine def_session_user
undefine def_current_schema
undefine def_con_name
undefine def_db_info
undefine def_db_not_open
undefine def_db_role_plus
undefine def_instance_info
undefine def_diag_trace
undefine def_trace_file

set feedback 6
