create table &&def_it_sess_helper_log_table (
    seq_num                     number                                      not null
  , log_time                    timestamp
        default localtimestamp                                              not null
  , event_type                  varchar2(30 byte)                           not null
  , target_session_id           number                                      not null
  , target_session_serial#      number                                      not null
  , target_session_logon_time   date                                        not null
  , target_session_userid       number                                      not null
  , target_session_username     varchar2(128 byte)
  , target_session_module       varchar2(64 byte)
  , target_session_action       varchar2(64 byte)
  , session_id                  number
        default to_number(sys_context('USERENV', 'SID'))                    not null
  , session_user                varchar2(128 byte)  
        default substrb(sys_context('USERENV', 'SESSION_USER'), 1, 128)     not null
  , client_host                 varchar2(64 byte)
        default substrb(sys_context('USERENV', 'HOST'), 1, 64)              null
  , client_ip_addr              varchar2(40 byte)
        default substrb(sys_context('USERENV', 'IP_ADDRESS'), 1, 40)        null
  , client_osuser               varchar2(128 byte)
        default substrb(sys_context('USERENV', 'OS_USER'), 1, 128)          null
  , session_auditing_id         number  
        default to_number(sys_context('USERENV', 'SESSIONID'))              not null
  , role_used                   varchar2(128 byte)                          not null
  , reason                      varchar2(4000 byte)                         null
)
segment creation deferred
storage (initial 64k next 64k pctincrease 0)
partition by range (log_time) interval (numtodsinterval(7,'DAY')) (
    partition p0 values less than (timestamp '1970-01-01 00:00:00')
)
;

comment on table &&def_it_sess_helper_log_table
    is 'Table for recording actions performed using the IT session helper facility';

comment on column &&def_it_sess_helper_log_table..seq_num                   is 'Sequence number (from seq. seq_sess_helper)';
comment on column &&def_it_sess_helper_log_table..log_time                  is 'Time when the action was recorded';
comment on column &&def_it_sess_helper_log_table..event_type                is 'Type of event';
comment on column &&def_it_sess_helper_log_table..target_session_id         is 'Target session info: session id';
comment on column &&def_it_sess_helper_log_table..target_session_serial#    is 'Target session info: session serial#';
comment on column &&def_it_sess_helper_log_table..target_session_logon_time is 'Target session info: logon time';
comment on column &&def_it_sess_helper_log_table..target_session_userid     is 'Target session info: user id';
comment on column &&def_it_sess_helper_log_table..target_session_username   is 'Target session info: username';
comment on column &&def_it_sess_helper_log_table..target_session_module     is 'Target session info: module (if set)';
comment on column &&def_it_sess_helper_log_table..target_session_action     is 'Target session info: action (if set)';
comment on column &&def_it_sess_helper_log_table..session_id                is 'Calling session info: session id';
comment on column &&def_it_sess_helper_log_table..session_user              is 'Calling session info: session user';
comment on column &&def_it_sess_helper_log_table..client_host               is 'Calling session info: client hostname';
comment on column &&def_it_sess_helper_log_table..client_ip_addr            is 'Calling session info: client IP address';
comment on column &&def_it_sess_helper_log_table..client_osuser             is 'Calling session info: client OS user';
comment on column &&def_it_sess_helper_log_table..session_auditing_id       is 'Calling session info: session auditing id';
comment on column &&def_it_sess_helper_log_table..role_used                 is 'Role used to authorize the action';
comment on column &&def_it_sess_helper_log_table..reason                    is 'Reason for performing the action';

