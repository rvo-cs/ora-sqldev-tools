-- Find out if Javascript is enabled; fail if it is not

define def_script_suffix = "a0-no_javascript"

whenever sqlerror continue none
set termout off
script
    ctx.getMap().put("DEF_SCRIPT_SUFFIX", "a")
/
set termout on
whenever sqlerror exit failure rollback

@@copy_tracefile_impl_&&def_script_suffix

undefine def_script_suffix
