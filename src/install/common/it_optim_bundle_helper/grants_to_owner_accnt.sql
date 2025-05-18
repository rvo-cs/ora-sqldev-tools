@@warn_if_not_sysdba

set verify on

grant SELECT on SYS.GV_$INSTANCE                    &&def_echo
   to &&def_fix_cntrl_hlpr_user;

grant SELECT on SYS.GV_$SESSION                     &&def_echo
   to &&def_fix_cntrl_hlpr_user;

grant SELECT on SYS.GV_$SESSION_FIX_CONTROL         &&def_echo
   to &&def_fix_cntrl_hlpr_user;

grant SELECT on SYS.GV_$PARAMETER2                  &&def_echo
   to &&def_fix_cntrl_hlpr_user;

grant SELECT on SYS.GV_$SYSTEM_FIX_CONTROL          &&def_echo
   to &&def_fix_cntrl_hlpr_user;

grant SELECT on SYS.GV_$SYSTEM_PARAMETER            &&def_echo
   to &&def_fix_cntrl_hlpr_user;

grant SELECT on SYS.GV_$SYSTEM_PARAMETER2           &&def_echo
   to &&def_fix_cntrl_hlpr_user;

grant SELECT on SYS.GV_$SPPARAMETER                 &&def_echo
   to &&def_fix_cntrl_hlpr_user;

grant INHERIT ANY PRIVILEGES                        &&def_echo
   to &&def_fix_cntrl_hlpr_user;

set verify off
