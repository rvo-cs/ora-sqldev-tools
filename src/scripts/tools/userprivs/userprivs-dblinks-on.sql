prompt ~~~~~~~~~~~~~~
prompt Database links
prompt --------------

column owner                    format a30 wrapped
column db_link                  format a30 wrapped
column username                 format a30 wrapped
column host                     format a90 word_wrapped
column shard_internal           format a9
column valid                    format a5
column intra_cdb                format a9

select
      owner
    , db_link
    , username
    , host
    &&def_db_version_ge_18 , shard_internal
    &&def_db_version_ge_18 , valid
    &&def_db_version_ge_19 , intra_cdb
from
    dba_db_links
where
    owner in ( 'PUBLIC', '&&def_username_impl' )
order by
    owner, host, username, db_link
;

column owner                    clear
column db_link                  clear
column username                 clear
column host                     clear
column shard_internal           clear
column valid                    clear
column intra_cdb                clear
