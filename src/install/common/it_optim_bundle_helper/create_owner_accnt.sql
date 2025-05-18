set verify on

create user &&def_fix_cntrl_hlpr_user
&&def_db_version_ge_18 no authentication
&&def_db_version_lt_18 identified by "7+b%8o\1#4~3"
&&def_db_version_lt_18 password expire
&&def_db_version_lt_18 account lock
default tablespace "&&def_fix_cntrl_hlpr_tabspc"
temporary tablespace "&&def_fix_cntrl_hlpr_temp_tabspc"
;

alter user  &&def_fix_cntrl_hlpr_user default role none
;

set verify off
