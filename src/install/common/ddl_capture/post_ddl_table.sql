create table &&def_post_ddl_table (
    seq_num             number                                              not null
  , ddl_time            timestamp               
        default localtimestamp                                              not null
  , event_type          varchar2(20 byte)                                   not null
&&def_pdb_aware  , con_name            varchar2(128 byte)
&&def_pdb_aware        default substrb(sys_context('USERENV', 'CON_NAME'), 1, 128)         not null
  , object_type         varchar2(20 byte)                                   not null
  , object_owner        varchar2(128 byte)                                  null
  , object_name         varchar2(261 byte)                                  null
  , session_id          number
        default to_number(sys_context('USERENV', 'SID'))                    not null
  , session_user        varchar2(128 byte)  
        default substrb(sys_context('USERENV', 'SESSION_USER'), 1, 128)     not null
  , module              varchar2(64 byte)
        default substrb(sys_context('USERENV', 'MODULE'), 1, 64)            null
  , action              varchar2(64 byte)
        default substrb(sys_context('USERENV', 'ACTION'), 1, 64)            null
  , client_host         varchar2(64 byte)
        default substrb(sys_context('USERENV', 'HOST'), 1, 64)              null
  , client_ip_addr      varchar2(40 byte)
        default substrb(sys_context('USERENV', 'IP_ADDRESS'), 1, 40)        null
  , client_osuser       varchar2(128 byte)
        default substrb(sys_context('USERENV', 'OS_USER'), 1, 128)          null
  , session_auditing_id number  
        default to_number(sys_context('USERENV', 'SESSIONID'))              not null
  , ddl_text            clob                                                not null
)
segment creation deferred
storage (initial 64k next 1m pctincrease 0)
lob (ddl_text) store as basicfile (
        enable storage in row
        nocache logging
    )
partition by range (ddl_time) interval (numtodsinterval(7,'DAY')) (
    partition p0 values less than (timestamp '1970-01-01 00:00:00')
)
;

comment on table &&def_post_ddl_table is 'Table for recording DDL statements (trig_ddl_post)';

comment on column &&def_post_ddl_table..seq_num        is 'Sequence number (from seq. seq_ddl_post)';
comment on column &&def_post_ddl_table..ddl_time       is 'Time when the post-DDL trigger (trig_ddl_post) fired';
comment on column &&def_post_ddl_table..event_type     is 'Type of DDL event';
begin
    &&def_pdb_aware execute immediate q'<comment on column &&def_post_ddl_table..con_name  is 'Container name'>';
    null;
end;
/
comment on column &&def_post_ddl_table..object_type    is 'Target object info: object type';
comment on column &&def_post_ddl_table..object_owner   is 'Target object info: object owner';
comment on column &&def_post_ddl_table..object_name    is 'Target object info: object name';
comment on column &&def_post_ddl_table..session_id     is 'Calling session info: session id';
comment on column &&def_post_ddl_table..session_user   is 'Calling session info: session user';
comment on column &&def_post_ddl_table..module         is 'Calling session info: module (if set)';
comment on column &&def_post_ddl_table..action         is 'Calling session info: action (if set)';
comment on column &&def_post_ddl_table..client_host    is 'Calling session info! client hostname';
comment on column &&def_post_ddl_table..client_ip_addr is 'Calling session info! client IP address';
comment on column &&def_post_ddl_table..client_osuser  is 'Calling session info: client OS user';
comment on column &&def_post_ddl_table..session_auditing_id is 'Calling session info: session auditing id';
comment on column &&def_post_ddl_table..ddl_text       is 'DDL statement text';

