/*
dbi-block2ext.sql

PURPOSE
    Finds the extent (or free extent) corresponding to the file id 
    and block id specified as arguments.

ORIGIN
    Almost straight from the original query published by F. Pachot in:
    https://blog.dbi-services.com/efficiently-query-dba_extents-for-file_id-block_id/

################################################################
###  IMPORTANT:                                              ### 
###    1. This script must be run as SYSDBA                  ###  
###    2. If using a CDB, this script must be run from the   ###
###       target container.                                  ###
################################################################
*/

-- Absolute file id
define def_file_id = &&1

-- Block id
define def_block_id = &&2       

prompt
prompt File id :  &&def_file_id
prompt Block id:  &&def_block_id

column owner            format a6
column segment_type     format a20
column segment_name     format a15
column partition_name   format a15

set linesize 200
set verify off

with
l as ( /* LMT extents indexed on ktfbuesegtsn, ktfbuesegfno, ktfbuesegbno */
    select 
        ktfbuesegtsn                as segtsn,
        ktfbuesegfno                as segrfn,
        ktfbuesegbno                as segbid, 
        ktfbuefno                   as extrfn,
        ktfbuebno                   as fstbid,
        ktfbuebno + ktfbueblks - 1  as lstbid,
        ktfbueblks                  as extblks,
        ktfbueextno                 as extno
    from 
        sys.x$ktfbue
),
d as ( /* DMT extents ts#, segfile#, segblock# */
    select 
        ts#                         as segtsn,
        segfile#                    as segrfn,
        segblock#                   as segbid, 
        file#                       as extrfn,
        block#                      as fstbid,
        block# + length - 1         as lstbid,
        length                      as extblks, 
        ext#                        as extno
    from 
        sys.uet$
),
s as ( /* segment information for the tablespace that contains afn file */
    select /*+ materialized */
        s.ts#                       as segtsn,
        s.file#                     as segrfn,
        s.block#                    as segbid,
        s.type#                     as segtype,
        t.name                      as tsname,
        t.blocksize
    from 
        sys.seg$ s, 
        sys.ts$ t
    where
        s.ts# = t.ts#
),
m as ( /* extent mapping for the tablespace that contains afn file */
    select /*+ use_nl(s) use_nl(e) ordered */
        f.fenum                         as afn,
        s.segtsn,
        s.segrfn,
        s.segbid,
        e.extrfn,
        e.fstbid,
        e.lstbid,
        e.extblks,
        e.extno, 
        s.segtype,
        s.tsname,
        s.blocksize
    from 
        sys.x$kccfe f,
        s,
        l e
    where 
        s.segtsn = f.fetsn
        and e.segtsn = s.segtsn 
        and e.segrfn = s.segrfn 
        and e.segbid = s.segbid
        and e.extrfn = f.ferfn 
    union all
    select /*+ use_nl(s) use_nl(e) ordered */ 
        f.fenum                         as afn,
        s.segtsn,
        s.segrfn,
        s.segbid,
        e.extrfn,
        e.fstbid,
        e.lstbid,
        e.extblks,
        e.extno, 
        s.segtype,
        s.tsname,
        s.blocksize
    from
        sys.x$kccfe f,
        s,
        d e
    where 
        s.segtsn = f.fetsn
        and e.segtsn = s.segtsn
        and e.segrfn = s.segrfn
        and e.segbid = s.segbid
        and e.extrfn = f.ferfn 
    union all
    select /*+ use_nl(e) use_nl(t) ordered */
        f.fenum                         as afn,
        null                            as segtsn,
        null                            as segrfn,
        null                            as segbid,
        f.ferfn                         as extrfn,
        e.ktfbfebno                     as fstbid,
        e.ktfbfebno + e.ktfbfeblks - 1  as lstbid,
        e.ktfbfeblks                    as extblks,
        null                            as extno, 
        null                            as segtype,
        t.name                          as tsname,
        t.blocksize
    from
        sys.x$kccfe f,
        sys.x$ktfbfe e,
        sys.ts$ t
    where 
        t.ts# = f.fetsn 
        and e.ktfbfetsn = f.fetsn
        and e.ktfbfefno = f.ferfn
    union all
    select /*+ use_nl(e) use_nl(t) ordered */
        f.fenum                         as afn,
        null                            as segtsn,
        null                            as segrfn,
        null                            as segbid,
        f.ferfn                         as extrfn,
        e.block#                        as fstbid,
        e.block# + e.length - 1         as lstbid,
        e.length                        as extblks,
        null                            as extno,
        null                            as segtype,
        t.name                          as tsname,
        t.blocksize
    from
        sys.x$kccfe f,
        sys.fet$ e,
        sys.ts$ t
    where 
        t.ts# = f.fetsn
        and e.ts# = f.fetsn
        and e.file# = f.ferfn
),
o as (
    select 
        s.tablespace_id                 as segtsn,
        s.relative_fno                  as segrfn,
        s.header_block                  as segbid,
        s.segment_type,
        s.owner,
        s.segment_name,
        s.partition_name
    from 
        sys_dba_segs s
),
datafile_map as (
    select
        m.afn                           as file_id,
        m.fstbid                        as block_id,
        m.extblks                       as blocks,
        nvl(o.segment_type, 
            decode(m.segtype, null, 'free space',
                    'type = ' || m.segtype)
           )                            as segment_type,
        o.owner,
        o.segment_name,
        o.partition_name,
        m.extno                         as extent_id,
        m.extblks * m.blocksize         as bytes,
        m.tsname                        as tablespace_name,
        m.extrfn                        as relative_fno,
        m.segtsn,
        m.segrfn,
        m.segbid
    from 
        m,
        o 
    where 
        m.segtsn = o.segtsn (+) 
        and m.segrfn = o.segrfn (+)
        and m.segbid = o.segbid (+)
    union all
    select
        file_id + (select to_number(value) 
                   from v$parameter where name = 'db_files') 
                                        as file_id,
        1                               as block_id,
        blocks,
        'tempfile'                      as segment_type,
        null                            as owner,
        file_name                       as segment_name,
        null                            as partition_name,
        0                               as extent_id,
        bytes,
        tablespace_name,
        relative_fno,
        0                               as segtsn,
        0                               as segrfn,
        0                               as segbid
    from 
        dba_temp_files
)
select * 
from 
    datafile_map 
where 
    file_id = &&def_file_id
    and &&def_block_id between block_id and block_id + blocks
;

column owner            clear
column segment_type     clear
column segment_name     clear
column partition_name   clear

undefine def_file_id
undefine def_block_id