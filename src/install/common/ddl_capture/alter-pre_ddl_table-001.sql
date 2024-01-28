alter table &&def_pre_ddl_table modify (
    object_owner                            null
  , object_name     varchar2(261 byte)      null
);

comment on column &&def_pre_ddl_table..object_owner   is 'Target object info: object owner';

