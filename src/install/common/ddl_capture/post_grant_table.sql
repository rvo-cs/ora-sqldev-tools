create table &&def_post_grant_table (
    seq_num         number                      not null
  , ddl_time        timestamp                   not null
  , privilege       varchar2(261 byte)          not null
  , grantee         varchar2(261 byte)          not null
  , grant_option    varchar2(1 byte)            null
)
segment creation deferred
storage (initial 64k next 1m pctincrease 0)
partition by range (ddl_time) interval (numtodsinterval(7,'DAY')) (
    partition p0 values less than (timestamp '1970-01-01 00:00:00')
)
;

comment on table &&def_post_grant_table is 'Table for recording details of GRANT/REVOKE statements (trig_ddl_post)';

comment on column &&def_post_grant_table..seq_num       is 'Sequence number (from seq. seq_ddl_post)';
comment on column &&def_post_grant_table..ddl_time      is 'Time when the post-DDL trigger (trig_ddl_post) fired';
comment on column &&def_post_grant_table..privilege     is 'Privilege granted or revoked in this event';
comment on column &&def_post_grant_table..grantee       is 'Grantee or revokee';
comment on column &&def_post_grant_table..grant_option  is '''Y'' if the GRANT was made WITH GRANT OPTION, null otherwise';
