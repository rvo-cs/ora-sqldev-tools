set verify on

/* 
   DB >= 12.2: the trigger owner must have the ADMINISTER DATABASE TRIGGER 
   privilege (directly granted, not through a role -- see MOS 2275535.1)
*/
grant                                                       &&def_echo
    ADMINISTER DATABASE TRIGGER                             &&def_echo
&&def_common_ddl_capture_user  , SET CONTAINER
to                                                          &&def_echo
    &&def_ddl_capture_user
&&def_common_ddl_capture_user container = all
;

alter user &&def_ddl_capture_user quota unlimited on &&def_ddl_capture_tabspc
;

set verify off
