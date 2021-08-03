create or replace view &&def_post_ddl_view
as 
select * 
  from &&def_post_ddl_table
 where object_owner not in /* Oracle-maintained accounts */
                           ( 'ANONYMOUS'
                           , 'APEX_050000'
                           , 'APEX_PUBLIC_USER'
                           , 'APPQOSSYS'
                           , 'AUDSYS'
                           , 'CTXSYS'
                           , 'DBSFWUSER'
                           , 'DBSNMP'
                           , 'DGPDB_INT'
                           , 'DIP'
                           , 'DVF'
                           , 'DVSYS'
                           , 'FLOWS_FILES'
                           , 'GGSYS'
                           , 'GSMADMIN_INTERNAL'
                           , 'GSMCATUSER'
                           , 'GSMUSER'
                           , 'LBACSYS'
                           , 'MDDATA'
                           , 'MDSYS'
                           , 'OLAPSYS'
                           , 'OUTLN'
                           , 'ORACLE_OCM' 
                           , 'ORDDATA'
                           , 'ORDPLUGINS'
                           , 'ORDSYS'
                           , 'REMOTE_SCHEDULER_AGENT'
                           , 'SI_INFORMTN_SCHEMA'
                           , 'SPATIAL_CSW_ADMIN_USR' 
                           , 'SPATIAL_WFS_ADMIN_USR'
                           , 'SYS'
                           , 'SYSBACKUP'
                           , 'SYSDG'
                           , 'SYSKM'
                           , 'SYSRAC'
                           , 'SYSTEM'
                           , 'WMSYS'
                           , 'XDB'
                           , 'XS$NULL' 
                           )
;

comment on table &&def_post_ddl_view is 'DDL statements recorded by the post-DDL trigger (trig_ddl_post), excluding DDL events on Oracle-maintained accounts';

comment on column &&def_post_ddl_view..seq_num        is 'Sequence number (from seq. seq_ddl_post)';
comment on column &&def_post_ddl_view..ddl_time       is 'Time when the post-DDL trigger (trig_ddl_post) fired';
comment on column &&def_post_ddl_view..event_type     is 'Type of DDL event';
begin
    &&def_pdb_aware execute immediate q'<comment on column &&def_post_ddl_view..con_name  is 'Container name'>';
    null;
end;
/
comment on column &&def_post_ddl_view..object_type    is 'Target object info: object type';
comment on column &&def_post_ddl_view..object_owner   is 'Target object info! object owner';
comment on column &&def_post_ddl_view..object_name    is 'Target object info: object name';
comment on column &&def_post_ddl_view..session_id     is 'Calling session info: session id';
comment on column &&def_post_ddl_view..session_user   is 'Calling session info: session user';
comment on column &&def_post_ddl_view..module         is 'Calling session info: module (if set)';
comment on column &&def_post_ddl_view..action         is 'Calling session info: action (if set)';
comment on column &&def_post_ddl_view..client_host    is 'Calling session info! client hostname';
comment on column &&def_post_ddl_view..client_ip_addr is 'Calling session info! client IP address';
comment on column &&def_post_ddl_view..client_osuser  is 'Calling session info: client OS user';
comment on column &&def_post_ddl_view..session_auditing_id is 'Calling session info: session auditing id';
comment on column &&def_post_ddl_view..ddl_text       is 'DDL statement text';

set verify on
grant                                                       &&def_echo
    &&def_db_version_lt_12 SELECT
    &&def_db_version_ge_12 READ
on                                                          &&def_echo
    &&def_post_ddl_view
to                                                          &&def_echo
    &&def_read_captured_ddl_role
;
set verify off
