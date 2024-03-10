set role dba;

select /*__sqlarea_search__*/
    address || ', ' || hash_value  as name, 
    sql_fulltext
from 
    v$sqlarea 
where 1 = 1
    and instr(sql_fulltext, '/*__sqlarea_search__*/') = 0
    and sql_id = '<target_sql_id>'
    --and regexp_like(sql_fulltext, '<regexp_to_match>', 'i')
    --and parsing_schema_name = '<schema_name>'
;

/*
exec sys.dbms_shared_pool.purge(flag => 'C', name => '000000007B2522F8, 3156833334');
                                                      ^                 ^
                                                      |                 |
                                                      +---ADDRESS       +---HASH VALUE

    See also: 
        o SYS.DBMS_SHARED_POOL package spec.
        o https://oracle-base.com/articles/misc/purge-the-shared-pool
*/
