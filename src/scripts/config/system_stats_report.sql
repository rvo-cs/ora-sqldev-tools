clear screen
---------------------------
set pagesize 50000
set linesize 160
set define off
set feedback off
---------------------------

/* Get the container name (if any) into :CON_NAME */
variable con_name varchar2(128)
declare
    e_invalid_identifier exception;
    pragma exception_init(e_invalid_identifier, -904);
begin
    execute immediate q'{ 
        select sys_context('USERENV', 'CON_NAME')
        from v$database
        where cdb = 'YES' 
    }' into :CON_NAME;
exception
    when no_data_found              /* DB version >= 12.1, non-CDB */
         or e_invalid_identifier    /* DB version < 12.1 */
    then
        null;
end;
/

/* Print the DB name, container name, date-time */
set heading off
column item format a10
column value format a50
select item, value 
from
    (select
        sys_context('USERENV', 'DB_NAME') as db_name,
        nvl(:CON_NAME, 'n/a (non-CDB)') as con_name,
        to_char(sysdate, 'YYYY-MM-DD HH24:MI:SS') as dte
    from
        dual
    )
    unpivot include nulls
    (value for item in (
        db_name     as 'Database :'
      , con_name    as 'Container:'
      , dte         as 'Date     :'
    ))
;
set heading on

Prompt
Prompt *** State of System Statistics ***
Prompt

set serveroutput on format word_wrapped
declare
    procedure output_system_stat(
        p_name          in varchar2,
        p_description   in varchar2,
        p_is_header     in boolean default false
    )
    is
        l_status  varchar2(20);
        l_dstart  date;
        l_dstop   date;
        l_value   number;
        gc_colsep constant varchar2(2) := '  '; 
    begin
        dbms_stats.get_system_stats(
            pname   => p_name,
            pvalue  => l_value,
            status  => l_status,
            dstart  => l_dstart,
            dstop   => l_dstop
        );
        if p_is_header then
            dbms_output.put_line(
                rpad('Param. Name', 11)
                || gc_colsep || rpad('Value', 12)
                || gc_colsep || rpad('Status', 16)
                || gc_colsep || rpad('Date start', 19)
                || gc_colsep || rpad('Date stop', 19)
                || gc_colsep || 'Description'
            );
            dbms_output.put_line(
                rpad('-', 11, '-')
                || gc_colsep || rpad('-', 12, '-')
                || gc_colsep || rpad('-', 16, '-')
                || gc_colsep || rpad('-', 19, '-')
                || gc_colsep || rpad('-', 19, '-')
                || gc_colsep || rpad('-', 60, '-')
            );
        end if;
        dbms_output.put_line(
            rpad(p_name, 11)
            || gc_colsep || lpad(nvl(to_char(l_value), '(null)'), 12)
            || gc_colsep || rpad(nvl(l_status, ' '), 16)
            || gc_colsep || nvl(to_char(l_dstart, 'YYYY-MM-DD HH24:MI:SS'), rpad(' ', 19))
            || gc_colsep || nvl(to_char(l_dstop, 'YYYY-MM-DD HH24:MI:SS'), rpad(' ', 19))
            || gc_colsep || p_description
        );
    end output_system_stat;
begin
    output_system_stat('cpuspeednw' , '[NOWORLOAD] Avg CPU speed, in millions of cycles/s', true);
    output_system_stat('iotfrspeed' , '[NOWORLOAD] I/O transfer speed, in bytes/ms');
    output_system_stat('ioseektim'  , '[NOWORLOAD] Seek + latency + OS overhead time, in ms');
    output_system_stat('sreadtim'   , 'Avg time to read single block (random read), in ms');
    output_system_stat('mreadtim'   , 'Avg time to read mbrc blocks at once (seq. read), in ms');
    output_system_stat('cpuspeed'   , 'Avg CPU speed, in millions of cycles/s');
    output_system_stat('mbrc'       , 'Avg multiblock read count for sequential reads, in blocks');
    output_system_stat('maxthr'     , 'Max. I/O system throughput, in bytes/s');
    output_system_stat('slavethr'   , 'Avg slave I/O throughput, in bytes/s');
end;
/

prompt
prompt *** Optimizer Mode & Costing Adj. for Indexes ***

column name format a40 wrapped
column value format a10 wrapped
column description format a70 word_wrapped

select
    name, value, description
from
    v$system_parameter
where
    name like '%optimizer%'
    and name in ( 'optimizer_mode'
                , 'optimizer_index_caching'
                , 'optimizer_index_cost_adj'
                )
order by 
    decode ( 'optimizer_mode'           , 1
           , 'optimizer_index_caching'  , 2
           , 'optimizer_index_cost_adj' , 3
           );

prompt
prompt *** Other Optimizer-Related Parameters ***

select
    name, value, description
from
    v$system_parameter
where
    name like '%optimizer%'
    and name not in ( 'optimizer_mode'
                    , 'optimizer_index_caching'
                    , 'optimizer_index_cost_adj'
                    )
order by 1;

prompt
prompt *** End ***
prompt

---------------------------
set define on
set feedback 6
---------------------------
