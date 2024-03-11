/*
 * SPDX-FileCopyrightText: 2022 R.Vassallo
 * SPDX-License-Identifier: BSD Zero Clause License
 */

whenever sqlerror exit failure rollback
whenever oserror exit failure rollback

@@common/util/def_db_version

clear screen
set sqlformat ansiconsole
set pagesize 500
set verify off

prompt
prompt **** Current container ****

set heading off
set feedback off

select coalesce ( &&def_db_version_ge_12  nvl2( sys_context('USERENV', 'CDB_NAME')
                  &&def_db_version_ge_12      , sys_context('USERENV', 'CON_NAME')
                  &&def_db_version_ge_12      , '--Not in a CDB--' ) ,
                  '--Not in a CDB--', null )  as con_name
  from dual; 

set heading on
set feedback on

prompt
prompt **** Database info ****

select dbid
     , name
     &&def_db_version_ge_12  , cdb
     , platform_name
     , created
     , log_mode
     , force_logging
     , open_mode
     , current_scn
     , flashback_on
     , protection_mode
     , protection_level
     , database_role
     , switchover_status
     , db_unique_name
     &&def_db_version_ge_12  , con_dbid
from v$database
;

prompt
prompt **** Instance(s) ****

select instance_number
     , instance_name
     , host_name
     , version
     &&def_db_version_ge_19  , version_full
     , startup_time
     , status
     , parallel
     , thread#
     , archiver
     , log_switch_wait
     , logins
     , shutdown_pending
     , database_status
     , instance_role
     , active_state
     , blocked
from
    gv$instance
;

prompt
prompt **** Database properties ****

column property_name    format a40 word_wrapped
column property_value   format a40 word_wrapped
column description      format a70 word_wrapped

select * 
from database_properties 
order by property_name;

column property_name    clear
column property_value   clear
column description      clear


prompt
prompt ****  v$sgastats summary ****

select
    case 
        when grouping(b.pool) = 1 then '--SGA total--'
        else b.pool
    end                 as pool, 
    case 
        when grouping(b.pool) = 1 and grouping(b.name) = 1 then '--SGA total--'
        when grouping(b.pool) = 0 and grouping(b.name) = 1 then '--Total--'
        else b.name
    end                 as name,
    round( case
               when grouping(b.pool) = 1 then max(b.total_bytes)
               when grouping(b.name) = 0 then max(b.bytes)
               else max(b.pool_bytes) 
           end / power(2, 20) )     as size_mb,
    case
        when grouping(b.pool) = 1 then null
        when grouping(b.name) = 1 then 100
        when grouping(b.name) = 0 then round(100 * max(b.bytes) / max(b.pool_bytes))
    end                 as "POOL%",
    round( case
               when grouping(b.pool) = 0 and grouping(b.name) = 1 
               then max(b.rem_bytes)
           end / power(2, 20) )     as unacc_mb,
    case
        when grouping(b.pool) = 0 and grouping(b.name) = 1 
        then round(100 * max(b.rem_bytes) / max(b.pool_bytes))
    end                 as "UNACC%"
from
    (select
        a.pool, a.name, a.bytes, 
        a.pool_bytes,
        a.pool_bytes - sum(a.bytes) over (partition by pool) as rem_bytes,
        a.total_bytes
    from
        (select 
            pool, name, 
            bytes,
            sum(bytes) over (partition by pool)  as pool_bytes,
            sum(bytes) over ()                   as total_bytes
        from 
            v$sgastat
        ) a
    where 
        a.bytes >= a.total_bytes * 0.0075
    ) b
group by rollup (pool, name)
order by
    grouping(b.pool) asc,
    max(b.pool_bytes) desc,
    b.pool asc nulls first,
    grouping(b.name) asc,
    max(b.bytes) desc nulls last
;


prompt
prompt **** v$pgastat ****
select
    name,
    case
        when unit = 'bytes'
        then round(value / power(2, 20), 1)
        else value
    end     as value,
    case
        when unit = 'bytes' then 'mbytes'
        else unit
    end as unit
from 
    v$pgastat;
    

prompt
prompt **** Memory-related DB params [+ misc.] ****

column con_name         format a12
column Parameter_Name   format a35 wrapped
column Value            format a20 word_wrapped
column Description      format a70 word_wrapped
column inst_id          format 9999999

select &&def_db_version_ge_12 b.name  as con_name ,
       a.name                 as "Parameter_Name" 
     , a.value                as "Value"
     , a.description          as "Description"
     , a.inst_id
  from gv$system_parameter a
       &&def_db_version_ge_12  , gv$pdbs b
 where a.name in ( 'memory_max_target'
                 , 'memory_target'
                 , 'pga_aggregate_target'
                 , 'pga_max_size'
                 , 'sga_target'
                 , 'sga_max_size'
                 , 'sga_min_size'
                 , 'bitmap_merge_area_size'
                 , 'create_bitmap_area_size'
                 , 'db_16k_cache_size'
                 , 'db_2k_cache_size'
                 , 'db_32k_cache_size'
                 , 'db_4k_cache_size'
                 , 'db_8k_cache_size'
                 , 'db_block_size'
                 , 'db_cache_size'
                 , 'db_flash_cache_size'
                 , 'db_keep_cache_size'
                 , 'db_recycle_cache_size'
                 , 'hash_area_size'
                 , 'java_pool_size'
                 , 'java_max_sessionspace_size'
                 , 'large_pool_size'
                 , 'olap_page_pool_size'
                 , 'result_cache_max_size'
                 , 'shared_pool_reserved_size'
                 , 'shared_pool_size'
                 , 'sort_area_retained_size'
                 , 'sort_area_size'
                 , 'streams_pool_size'
                 , 'workarea_size_policy'
                 , 'inmemory_size'
                 , 'inmemory_xmem_size'
                 , 'data_transfer_cache_size'
                 , 'max_string_size'
                 , 'memoptimize_pool_size'
                 )
   and (a.name not in ( 'db_16k_cache_size'
                      , 'db_2k_cache_size'
                      , 'db_32k_cache_size'
                      , 'db_4k_cache_size'
                      , 'db_8k_cache_size'
                      , 'db_flash_cache_size'
                      , 'db_keep_cache_size'
                      , 'db_recycle_cache_size'
                      , 'olap_page_pool_size'
                      , 'java_pool_size'
                      , 'inmemory_xmem_size'
                      , 'sga_min_size'
                      , 'data_transfer_cache_size'
                      ) or value > 0) 
   &&def_db_version_ge_12  and a.inst_id = b.inst_id (+)
   &&def_db_version_ge_12  and a.con_id = b.con_id (+)
   &&def_db_version_ge_12  and ( b.name is null or sys_context('USERENV', 'CON_NAME') = b.name )
 order by decode( a.name
                , 'memory_max_target'           , 10
                , 'memory_target'               , 20
                , 'sga_max_size'                , 30
                , 'sga_target'                  , 40
                , 'sga_min_size'                , 45
                , 'pga_max_size'                , 50
                , 'pga_aggregate_target'        , 60
                , 'db_block_size'               , 1000
                , 'db_cache_size'               , 1010
                , 'db_keep_cache_size'          , 1020
                , 'db_recycle_cache_size'       , 1030
                , 'db_2k_cache_size'            , 1040
                , 'db_4k_cache_size'            , 1050
                , 'db_8k_cache_size'            , 1060
                , 'db_16k_cache_size'           , 1070
                , 'db_32k_cache_size'           , 1080
                , 'db_flash_cache_size'         , 1100
                , 'inmemory_size'               , 1200
                , 'inmemory_xmem_size'          , 1210
                , 'memoptimize_pool_size'       , 1250
                , 'data_transfer_cache_size'    , 1300
                , 'shared_pool_size'            , 2000
                , 'shared_pool_reserved_size'   , 2010
                , 'streams_pool_size'           , 2020
                , 'java_pool_size'              , 2030
                , 'java_max_sessionspace_size'  , 2035
                , 'large_pool_size'             , 2040
                , 'result_cache_max_size'       , 3000
                , 'max_string_size'             , 4000
                , 'workarea_size_policy'        , 5000
                , 100000 )
        , a.name
        , a.inst_id
;

column con_name         clear
column Parameter_Name   clear
column Value            clear
column Description      clear
column inst_id          clear


set verify on
@@common/util/undef_db_version
