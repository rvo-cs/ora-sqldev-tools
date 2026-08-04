define def_sqlcl_client_unknown       = ""
define def_sqlcl_client_errmsg        = "Javascript is not available"
define def_sqlcl_client               = ""
define def_sqlcl_client_version       = ""
define def_sqlcl_client_version_major = ""
define def_sqlcl_client_version_minor = ""

set termout off

script
    var javaCmdSqlDevClassic   = '^oracle\\.ide\\.osgi\\.boot\\.OracleIdeLauncher\\b'
    var javaCmdSqlclStandAlone = '^oracle\\.dbtools\\.raptor\\.scriptrunner\\.cmdline\\.SqlCli\\b'
    var javaCmdSqlclInVsCode   = '^com\\.oracle\\.dbtools\\.launch sql\\b'
    var JavaCmdSqlDevInVsCode  = '^com\\.oracle\\.dbtools\\.launch server\\b'

    var javaCmd   = java.lang.System.getProperty('sun.java.command')

    if (javaCmd.match(javaCmdSqlDevClassic)) {
        // SQL Developer Classic
        var sqlDevVersion = java.lang.System.getProperty('http.agent').toString().split(/^SQL Developer\/(\d+(?:\.\d+){0,2})/)[1]
        ctx.getMap().put("DEF_SQLCL_CLIENT", "sqldev-classic")
        ctx.getMap().put("DEF_SQLCL_CLIENT_VERSION", sqlDevVersion)
        ctx.getMap().put("DEF_SQLCL_CLIENT_VERSION_MAJOR", sqlDevVersion.split(/(\d+)/)[1])
        ctx.getMap().put("DEF_SQLCL_CLIENT_VERSION_MINOR", sqlDevVersion.split(/(\d+)/)[3])
        ctx.getMap().put("DEF_SQLCL_CLIENT_UNKNOWN", "--")
        ctx.getMap().put("DEF_SQLCL_CLIENT_ERRMSG", "")
    } else if (javaCmd.match(JavaCmdSqlDevInVsCode)) {
        // SQL Developer for VS Code
        var sqlDevVersion = java.lang.System.getProperty('java.home').toString().split(/\boracle\.sql-developer-(\d+(?:\.\d+){0,2})/)[1]
        ctx.getMap().put("DEF_SQLCL_CLIENT", "sqldev-vscode")
        ctx.getMap().put("DEF_SQLCL_CLIENT_VERSION", sqlDevVersion)
        ctx.getMap().put("DEF_SQLCL_CLIENT_VERSION_MAJOR", sqlDevVersion.split(/(\d+)/)[1])
        ctx.getMap().put("DEF_SQLCL_CLIENT_VERSION_MINOR", sqlDevVersion.split(/(\d+)/)[3])
        ctx.getMap().put("DEF_SQLCL_CLIENT_UNKNOWN", "--")
        ctx.getMap().put("DEF_SQLCL_CLIENT_ERRMSG", "")
    } else if (javaCmd.match(javaCmdSqlclStandAlone)) {
        // Stand-alone SQLcl
        var cmdLineVersion = ctx.getCmdlineVersion().toString().split(/^(\d+(?:\.\d+){0,2})/)[1]
        ctx.getMap().put("DEF_SQLCL_CLIENT", "sqlcl-sqlcli")
        ctx.getMap().put("DEF_SQLCL_CLIENT_VERSION", cmdLineVersion)
        ctx.getMap().put("DEF_SQLCL_CLIENT_VERSION_MAJOR", cmdLineVersion.split(/(\d+)/)[1])
        ctx.getMap().put("DEF_SQLCL_CLIENT_VERSION_MINOR", cmdLineVersion.split(/(\d+)/)[3])
        ctx.getMap().put("DEF_SQLCL_CLIENT_UNKNOWN", "--")
        ctx.getMap().put("DEF_SQLCL_CLIENT_ERRMSG", "")
    } else if (javaCmd.match(javaCmdSqlclInVsCode)) {
        // Built-in SQLcl in SQL Developer for VS Code
        var cmdLineVersion = ctx.getCmdlineVersion().toString().split(/^(\d+(?:\.\d+){0,2})/)[1]
        ctx.getMap().put("DEF_SQLCL_CLIENT", "sqlcl-vscode")
        ctx.getMap().put("DEF_SQLCL_CLIENT_VERSION", cmdLineVersion)
        ctx.getMap().put("DEF_SQLCL_CLIENT_VERSION_MAJOR", cmdLineVersion.split(/(\d+)/)[1])
        ctx.getMap().put("DEF_SQLCL_CLIENT_VERSION_MINOR", cmdLineVersion.split(/(\d+)/)[3])
        ctx.getMap().put("DEF_SQLCL_CLIENT_UNKNOWN", "--")
        ctx.getMap().put("DEF_SQLCL_CLIENT_ERRMSG", "")
    } else {
        ctx.getMap().put("DEF_SQLCL_CLIENT_ERRMSG", "the version of SQLcl could not be determined")
    }
/

set termout on
