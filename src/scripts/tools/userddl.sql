/*
 * SPDX-FileCopyrightText: 2021-2022 R.Vassallo
 * SPDX-License-Identifier: BSD Zero Clause License
 */

set echo off

define def_username = "&1"

whenever sqlerror exit failure rollback
whenever oserror exit failure rollback

set verify off

@@userddl-settings

set termout off
set feedback off

define def_db_name = ""
define def_username_xc = ""
define def_username_xc_int = ""
define def_error_msg = ""
define def_action = ""

define def_simple_username = "--"
define def_complex_username = "--"

column def_simple_username  noprint new_value def_simple_username
column def_complex_username noprint new_value def_complex_username

whenever sqlerror continue none

select
    nvl2('&&def_username', null, null) as def_simple_username,
    '--' as def_complex_username
from
    dual;

select
    '--' as def_simple_username,
    nvl2(&&def_username, null, null) as def_complex_username
from 
    dual;

whenever sqlerror exit failure rollback

column def_db_name          noprint new_value def_db_name
column def_username_xc      noprint new_value def_username_xc
column def_username_xc_int  noprint new_value def_username_xc_int
column def_action           noprint new_value def_action
column def_error_msg        noprint new_value def_error_msg

select
    sys_context('USERENV', 'DB_UNIQUE_NAME') as def_db_name,
    max(a.username)                          as def_username_xc,
    replace(max(username), '''', '''''')     as def_username_xc_int,
    case
        when count(*) = 0 then 'error'
        when count(*) > 1 then 'error'
        else 'spool'
    end as def_action,
    case
        when count(*) = 0 then '*** ERROR, username not found'
        when count(*) > 1 then '*** ERROR, more than one matching username'
    end as def_error_msg
from
    dba_users a
where
    lnnvl('&&def_simple_username' = '&&def_complex_username') 
    &&def_simple_username and upper(a.username) = upper('&&def_username')
    &&def_complex_username and a.username = &&def_username
;

set termout on

define def_spool_filename = "cr_user-&&def_db_name-&&def_username_xc..sql"

@@userddl/userddl-&&def_action

set feedback on

undefine def_db_name
undefine def_username
undefine def_username_xc
undefine def_username_xc_int
undefine def_simple_username
undefine def_complex_username
undefine def_error_msg
undefine def_action
undefine def_spool_directory
undefine def_spool_filename
undefine 1

whenever sqlerror continue none
whenever oserror continue none
