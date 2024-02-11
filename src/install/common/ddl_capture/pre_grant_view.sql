create or replace view &&def_pre_grant_view
as 
select ddl.*,
       priv.privilege,
       priv.grantee,
       priv.grant_option
  from &&def_pre_ddl_table ddl,
       &&def_pre_grant_table priv
 where (ddl.object_owner is null
        or ddl.object_owner not in /* Oracle-maintained accounts */
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
       )
   and ddl.event_type in ('GRANT', 'REVOKE') 
   and priv.seq_num (+) = ddl.seq_num
   and priv.ddl_time (+) = ddl.ddl_time
;

comment on table &&def_pre_grant_view is 'Details of GRANT or REVOKE statements recorded by the pre-DDL trigger (trig_ddl_pre), excluding DDL events on Oracle-maintained accounts';

comment on column &&def_pre_grant_view..seq_num        is 'Sequence number (from seq. seq_ddl_pre)';
comment on column &&def_pre_grant_view..ddl_time       is 'Time when the pre-DDL trigger (trig_ddl_pre) fired';
comment on column &&def_pre_grant_view..event_type     is 'Type of DDL event';
begin
    &&def_pdb_aware execute immediate q'<comment on column &&def_pre_grant_view..con_name  is 'Container name'>';
    null;
end;
/
comment on column &&def_pre_grant_view..object_type    is 'Target object info: object type';
comment on column &&def_pre_grant_view..object_owner   is 'Target object info! object owner';
comment on column &&def_pre_grant_view..object_name    is 'Target object info: object name';
comment on column &&def_pre_grant_view..session_id     is 'Calling session info: session id';
comment on column &&def_pre_grant_view..session_user   is 'Calling session info: session user';
comment on column &&def_pre_grant_view..module         is 'Calling session info: module (if set)';
comment on column &&def_pre_grant_view..action         is 'Calling session info: action (if set)';
comment on column &&def_pre_grant_view..client_host    is 'Calling session info! client hostname';
comment on column &&def_pre_grant_view..client_ip_addr is 'Calling session info! client IP address';
comment on column &&def_pre_grant_view..client_osuser  is 'Calling session info: client OS user';
comment on column &&def_pre_grant_view..session_auditing_id is 'Calling session info: session auditing id';
comment on column &&def_pre_grant_view..ddl_text       is 'DDL statement text';
comment on column &&def_pre_grant_view..privilege      is 'Privilege granted or revoked in this event';
comment on column &&def_pre_grant_view..grantee        is 'Grantee or revokee';
comment on column &&def_pre_grant_view..grant_option   is '''Y'' if the GRANT was made WITH GRANT OPTION, null otherwise';

set verify on
grant                                                       &&def_echo
    &&def_db_version_lt_12 SELECT
    &&def_db_version_ge_12 READ
on                                                          &&def_echo
    &&def_pre_grant_view
to                                                          &&def_echo
    &&def_read_captured_ddl_role
;
set verify off
