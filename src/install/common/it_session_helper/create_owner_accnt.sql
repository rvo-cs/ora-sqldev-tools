set verify on

create user &&def_it_sess_helper_user
&&def_db_version_ge_18 no authentication
&&def_db_version_lt_18 identified by "jq5^81=42F%*:"
&&def_db_version_lt_18 password expire
&&def_db_version_lt_18 account lock
default tablespace "&&def_it_sess_helper_tabspc"
temporary tablespace "&&def_it_sess_helper_temp_tabspc"
;

set verify off
