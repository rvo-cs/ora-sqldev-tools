/*
 * SPDX-FileCopyrightText: 2026 R.Vassallo
 * SPDX-License-Identifier: BSD Zero Clause License
 */

/*
    sqlcl_aliases.sql

    DESCRIPTION
        Depending on the values of the ORA_SQLCL_VERSION_MAJOR and
        ORA_SQLCL_VERSION_MINOR substitution variables, this script
        calls the relevant alias creation scripts for the current
        version of SQLcl.
 */

define def_script_suffix = "none"

set termout off
set define off

script
    var sqlclVersMajor = ctx.getMap().get("ORA_SQLCL_CLIENT_VERSION_MAJOR")
    var sqlclVersMinor = ctx.getMap().get("ORA_SQLCL_CLIENT_VERSION_MINOR")
    if (sqlclVersMajor > 23 || (sqlclVersMajor = 23 && sqlclVersMinor >= 4)) {
        ctx.getMap().put("DEF_SCRIPT_SUFFIX", "post_23_4")
    } else if (sqlclVersMajor < 23 || (sqlclVersMajor = 23 && sqlclVersMinor < 4)) {
        ctx.getMap().put("DEF_SCRIPT_SUFFIX", "pre_23_4")
    } else {
        ctx.getMap().put("DEF_SCRIPT_SUFFIX", "none")
    }
/

set define on
set termout on

@@sqlcl_aliases-&&def_script_suffix..sql

undefine def_script_suffix
