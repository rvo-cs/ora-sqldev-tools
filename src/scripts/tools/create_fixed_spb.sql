/*
 * SPDX-FileCopyrightText: 2024 R.Vassallo
 * SPDX-License-Identifier: BSD Zero Clause License
 */

/*
    This script:
      1) prompts for the following elements:
          i.   the SQL id of a cursor in the cursor cache (= the original SQL id)
          ii.  the plan hash value of that cursor (= the original plan)
          iii. the SQL id of another cursor in the cursor cache (= the replacement SQL id)
          iv.  the plan hash value of that cursor (= the replacement plan)
          v.   a terse comment for describing the original plan
          vi.  a terse comment for describing the replacement plan
      and then:
      2) attempts to create a SQL plan baseline for the original SQL id, in order to
         force using the replacement plan as the enabled, fixed plan.

    For convenience, the following substitution variables, if defined, are used
    as default values in accept prompts (it is not possible to skip prompts), and
    subsequently undefined:
          . def_spb_orig_sqlid:      original SQL id
          . def_spb_orig_plan_hash:  original plan hash value
          . def_spb_orig_plan_descr: terse comment for describing the original plan
          . def_spb_repl_sqlid:      SQL id of the replacement query
          . def_spb_repl_plan_hash:  plan hash value of the replacement plan
          . def_spb_repl_plan_descr: terse comment for describing the replacement plan
*/

whenever sqlerror exit failure rollback
whenever oserror exit failure rollback

set echo off
set trimspool on

@@create_fixed_spb-settings

set termout off
column tmp_filename noprint new_value def_tmp_filename
select
    'create_fixed_spb-' 
            || sys_context('USERENV', 'DB_UNIQUE_NAME') || '-'
            || sys_context('USERENV', 'SESSIONID') || '-'
            || to_char(localtimestamp, 'YYYYMMDDHH24MISSXFF4')
        as tmp_filename
from
    dual;
column tmp_filename clear
set termout on

define def_tmp_fspec_sp2cfg = "&&def_temp_spool_dir&&def_dir_sep_char&&def_tmp_filename.-a.tmp"
define def_tmp_fspec_accept = "&&def_temp_spool_dir&&def_dir_sep_char&&def_tmp_filename.-b.tmp"

-- prompt the following def_spb_xxxx substitution variables into existence
-- (already existing variables will not be modified)
set termout off
column spb_orig_sqlid      noprint new_value def_spb_orig_sqlid
column spb_orig_plan_hash  noprint new_value def_spb_orig_plan_hash
column spb_orig_plan_descr noprint new_value def_spb_orig_plan_descr
column spb_repl_sqlid      noprint new_value def_spb_repl_sqlid
column spb_repl_plan_hash  noprint new_value def_spb_repl_plan_hash
column spb_repl_plan_descr noprint new_value def_spb_repl_plan_descr
select 
    'X' as spb_orig_sqlid,
    0   as spb_orig_plan_hash,
    'X' as spb_orig_plan_descr,
    'X' as spb_repl_sqlid,
    0   as spb_repl_plan_hash,
    'X' as spb_repl_plan_descr
from 
    dual
where 
    null is not null;
column spb_orig_sqlid      clear
column spb_orig_plan_hash  clear
column spb_orig_plan_descr clear
column spb_repl_sqlid      clear
column spb_repl_plan_hash  clear
column spb_repl_plan_descr clear
set termout on

set termout off
set feedback off
set heading off
-- save settings (linesize, verify, serveroutput) into a temp .sql file
-- (we can't use the SAVE command as it's not implemented in SQL Developer) 
spool &&def_tmp_fspec_sp2cfg
select 
    'set -' as text
from dual;
show linesize
select 
    'set -' as text
from dual;
show verify
select 
    'set -' as text
from dual;
show serveroutput
spool off
-- linesize must be set high enough for the accept commands to not wrap
set linesize 600
-- verify must be off from now on
set verify off
-- serveroutput show be off for performance reasons in SQLcl & SQL Dev
-- unless we really need to use dbms_output
set serveroutput off
spool &&def_tmp_fspec_accept
with 
def_vars(name, prompt, val) as (
    select 'def_spb_orig_sqlid'       , 'SQL id of the target cursor'            , q'{&&def_spb_orig_sqlid}'     from dual union all
    select 'def_spb_orig_plan_hash'   , 'Original plan hash value'               , q'{&&def_spb_orig_plan_hash}' from dual union all
    select cast(null as varchar2(30)) , cast(null as varchar2(40))               , cast(null as varchar2(20))    from dual union all
    select 'def_spb_repl_sqlid'       , 'SQL id of the replacement cursor'       , q'{&&def_spb_repl_sqlid}'     from dual union all
    select 'def_spb_repl_plan_hash'   , 'Plan hash value of the replacement plan', q'{&&def_spb_repl_plan_hash}' from dual
)
select
    case
        when name is null then
            'prompt'
        else
            'accept ' || dv.name || ' char'
            || case
                   when dv.val is not null then
                       ' default "' || dv.val || '"' 
               end
            || ' prompt "' || dv.prompt || '?'
            || case
                   when dv.val is not null then
                       ' [' || dv.val || ']'
               end
            || ' "'
        end as accept_cmd    
from
    def_vars dv;
spool off
set heading on
set feedback on
set termout on

prompt
@&&def_tmp_fspec_accept

set termout off
column spb_orig_plan_descr noprint new_value def_spb_orig_plan_descr
select
    'SQL id: ' || q'{&&def_spb_orig_sqlid}' || ' -- initial plan' as spb_orig_plan_descr
from
    dual
where
    q'{&&def_spb_orig_plan_descr}' is null;
column spb_orig_plan_descr clear;

column spb_repl_plan_descr noprint new_value def_spb_repl_plan_descr
select
    'SQL id: ' || q'{&&def_spb_orig_sqlid}' || ' -- replacement plan' as spb_repl_plan_descr
from
    dual
where
    q'{&&def_spb_repl_plan_descr}' is null;
column spb_repl_plan_descr clear;
set termout on

set termout off
set feedback off
set heading off
-- linesize must be set high enough for the accept commands to not wrap
set linesize 600
spool &&def_tmp_fspec_accept
with 
def_vars(name, prompt, val) as (
    select 'def_spb_orig_plan_descr' , 'Description of the original plan'    , q'{&&def_spb_orig_plan_descr}' from dual union all
    select 'def_spb_repl_plan_descr' , 'Description of the replacement plan' , q'{&&def_spb_repl_plan_descr}' from dual
)
select
    'accept ' || dv.name || ' char'
            || case
                   when dv.val is not null then
                       ' default "' || dv.val || '"' 
               end
            || ' prompt "' || dv.prompt || '?'
            || case
                   when dv.val is not null then
                       ' [' || dv.val || ']'
               end
            || ' "'
        as accept_cmd    
from
    def_vars dv;
spool off
set heading on
set feedback on
set termout on

prompt
@&&def_tmp_fspec_accept

@@create_fixed_spb/create_fixed_spb_impl-recap

-- restore settings (linesize, verify, serveroutput) to their original values
@&&def_tmp_fspec_sp2cfg

host &&def_host_cmd_rm &&def_tmp_fspec_accept
host &&def_host_cmd_rm &&def_tmp_fspec_sp2cfg

undefine def_spb_orig_sqlid
undefine def_spb_repl_sqlid
undefine def_spb_orig_plan_hash
undefine def_spb_repl_plan_hash
undefine def_spb_orig_plan_descr
undefine def_spb_repl_plan_descr
undefine def_tmp_filename
undefine def_tmp_fspec_sp2cfg
undefine def_tmp_fspec_accept
undefine def_temp_spool_dir
undefine def_dir_sep_char
undefine def_host_cmd_rm
