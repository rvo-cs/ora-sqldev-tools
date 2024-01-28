alter table &&def_post_ddl_table modify (
    object_owner                            null
  , object_name     varchar2(261 byte)      null
);

comment on column &&def_post_ddl_table..object_owner   is 'Target object info: object owner';
