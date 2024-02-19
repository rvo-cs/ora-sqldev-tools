-- sqlcl-version-settings.sql
--
-- PURPOSE
--      This script sets substitution variables according to the version
--      of the SQLcl client. This helps to to work around version-specific
--      changes in behaviour.

set define off
script
    var versObj = ctx.getCmdlineVersion()
    var versNum = versObj.toIntArray()
    ctx.getMap().put("DEF_SQLCL_VERSION", versObj.toString())
    
    // The ALIAS command has a new syntax beginning with SQLcl 23.4,
    // breaking compatibility with prior versions.
    
    if (versNum[0] > 23 || (versNum[0] == 23 && versNum[1] >= 4)) {
        // 23.4 and higher
        ctx.getMap().put("DEF_SQLCL_ALIAS_POST_23_4", "-post_23_4")
        ctx.getMap().put("DEF_SQLCL_ALIAS_CMD_SYNTAX", "ge_23_4")
    } else {
        // up to 23.3
        ctx.getMap().put("DEF_SQLCL_ALIAS_POST_23_4", "")
        ctx.getMap().put("DEF_SQLCL_ALIAS_CMD_SYNTAX", "lt_23_4")
    }
/
set define on
