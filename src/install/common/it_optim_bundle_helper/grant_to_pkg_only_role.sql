@@warn_if_not_sysdba

set verify on

grant READ on directory DBMS_OPTIM_ADMINDIR         &&def_echo
   to "&&def_fix_cntrl_hlpr_pkg_role";

grant SELECT on SYS.GV_$INSTANCE                    &&def_echo
   to "&&def_fix_cntrl_hlpr_pkg_role";

grant SELECT on SYS.GV_$SESSION                     &&def_echo
   to "&&def_fix_cntrl_hlpr_pkg_role";

grant SELECT on SYS.GV_$SESSION_FIX_CONTROL         &&def_echo
   to "&&def_fix_cntrl_hlpr_pkg_role";

grant SELECT on SYS.GV_$PARAMETER2                  &&def_echo
   to "&&def_fix_cntrl_hlpr_pkg_role";

grant SELECT on SYS.GV_$SYSTEM_FIX_CONTROL          &&def_echo
   to "&&def_fix_cntrl_hlpr_pkg_role";

grant SELECT on SYS.GV_$SYSTEM_PARAMETER            &&def_echo
   to "&&def_fix_cntrl_hlpr_pkg_role";

grant SELECT on SYS.GV_$SYSTEM_PARAMETER2           &&def_echo
   to "&&def_fix_cntrl_hlpr_pkg_role";

grant SELECT on SYS.GV_$SPPARAMETER                 &&def_echo
   to "&&def_fix_cntrl_hlpr_pkg_role";

set verify off
