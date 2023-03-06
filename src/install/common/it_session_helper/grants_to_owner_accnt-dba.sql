set verify on

grant                                                   &&def_echo
    ALTER SYSTEM                                        &&def_echo
to                                                      &&def_echo
    &&def_it_sess_helper_user
;

grant                                                   &&def_echo
    SELECT ANY DICTIONARY                               &&def_echo
to                                                      &&def_echo
    &&def_it_sess_helper_user
;

alter user &&def_it_sess_helper_user quota unlimited on &&def_it_sess_helper_tabspc
;

set verify off
