set verify on

grant                                                   &&def_echo
    ALTER SYSTEM                                        &&def_echo
to                                                      &&def_echo
    &&def_it_sess_helper_user
;

grant                                                   &&def_echo
    SELECT on SYS.GV_$SESSION                           &&def_echo
to                                                      &&def_echo
    &&def_it_sess_helper_user
;

grant                                                   &&def_echo
    SELECT on SYS.V_$SESSION                            &&def_echo
to                                                      &&def_echo
    &&def_it_sess_helper_user
;

grant                                                   &&def_echo
    SELECT on SYS.GV_$PX_SESSION                        &&def_echo
to                                                      &&def_echo
    &&def_it_sess_helper_user
;

grant                                                   &&def_echo
    SELECT on SYS.GV_$ACTIVE_SESSION_HISTORY            &&def_echo
to                                                      &&def_echo
    &&def_it_sess_helper_user
;

begin
    &&def_db_version_lt_12 null;  /* no action if Oracle < 12.1 */
    &&def_db_version_ge_12 execute immediate q'{
    &&def_db_version_ge_12     grant
    &&def_db_version_ge_12         SELECT on SYS.GV_$PDBS
    &&def_db_version_ge_12     to
    &&def_db_version_ge_12         &&def_it_sess_helper_user
    &&def_db_version_ge_12 }';
end;
/

grant                                                   &&def_echo
    SELECT on SYS.V_$SQLCOMMAND                         &&def_echo
to                                                      &&def_echo
    &&def_it_sess_helper_user
;

grant                                                   &&def_echo
    SELECT on SYS.V_$TOPLEVELCALL                       &&def_echo
to                                                      &&def_echo
    &&def_it_sess_helper_user
;

grant                                                   &&def_echo
    SELECT on SYS.DBA_ROLES                             &&def_echo
to                                                      &&def_echo
    &&def_it_sess_helper_user
;

alter user &&def_it_sess_helper_user quota unlimited on &&def_it_sess_helper_tabspc
;

set verify off
