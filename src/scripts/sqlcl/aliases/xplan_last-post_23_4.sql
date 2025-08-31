alias -silent -nulldefaults -group rvo-cs -desc "xplan_last : displays the plan of the previous SQL statement" xplan_last=q'
tosub def_xplan_last_format=:plan_fmt
script
    /* save current settings: wrap, pagesize, linesize, heading, feedback */
    ctx.getMap().put("DEF_XPLAN_LAST_WRAP", ctx.getProperty(ctx.getClass().getField("SETWRAP").get(ctx)))
    ctx.getMap().put("DEF_XPLAN_LAST_PAGESIZE", ctx.getProperty(ctx.getClass().getField("SETPAGESIZE").get(ctx)).toString())
    ctx.getMap().put("DEF_XPLAN_LAST_LINESIZE", ctx.getProperty(ctx.getClass().getField("SETLINESIZE").get(ctx)).toString())
    ctx.getMap().put("DEF_XPLAN_LAST_HEADING", ctx.getProperty(ctx.getClass().getField("SETHEADING").get(ctx)))
    ctx.getMap().put("DEF_XPLAN_LAST_FEEDBACK_SQLID", ctx.getFeedbackSQLID().toString())
    ctx.getMap().put("DEF_XPLAN_LAST_FEEDBACK", ctx.getFeedback().toString())
    /* append -qbregistry to the plan format automatically, if using 19c or higher */
    var dbVersionStr = ctx.getMap().get("_O_RELEASE")
    if (dbVersionStr == null) {
        /* workaround for _O_RELEASE being defined seemingly lazily */
        ctx.setSupressOutput(true)
        sqlcl.setStmt('define _O_RELEASE')
        sqlcl.run()
        ctx.setSupressOutput(false)
        dbVersionStr = ctx.getMap().get("_O_RELEASE")
    }
    var dbVersionMajor = parseInt(dbVersionStr.substring(0, 2))
    if (dbVersionMajor >= 19) {
        var planFormat = ctx.getMap().get("DEF_XPLAN_LAST_FORMAT")
        if (planFormat.search(/[+\-]qbregistry\b/i) < 0) {
            ctx.addBind("plan_fmt", planFormat + (planFormat.isEmpty() ? "" : " ") + "-qbregistry")
        }
    }
/
set pagesize 10000
set wrap on
set heading off
set feedback off
set linesize 300
set trimout on
column plan_table_output format a300
prompt __________________________________________________________________________________________
select * from table(dbms_xplan.display_cursor(
        null, 
        null, 
        nvl2( regexp_replace(:plan_fmt, '[-+].*$')
            , regexp_replace(:plan_fmt, '[-+].*$') || ' -projection ' || regexp_substr(:plan_fmt, '[-+].*$')
            , 'Advanced -projection +iostats last ' || :plan_fmt)));
column plan_table_output clear
script
    /* restore prior settings */
    ctx.putProperty(ctx.getClass().getField("SETWRAP").get(ctx), ctx.getMap().get("DEF_XPLAN_LAST_WRAP"))
    ctx.putProperty(ctx.getClass().getField("SETPAGESIZE").get(ctx), Number(ctx.getMap().get("DEF_XPLAN_LAST_PAGESIZE")))
    ctx.putProperty(ctx.getClass().getField("SETLINESIZE").get(ctx), Number(ctx.getMap().get("DEF_XPLAN_LAST_LINESIZE")))
    ctx.putProperty(ctx.getClass().getField("SETHEADING").get(ctx), ctx.getMap().get("DEF_XPLAN_LAST_HEADING"))
    ctx.setFeedback(parseInt(ctx.getMap().get("DEF_XPLAN_LAST_FEEDBACK")))
    ctx.setFeedbackSQLID(ctx.getMap().get("DEF_XPLAN_LAST_FEEDBACK_SQLID") === "true")
/
undefine def_xplan_last_format
undefine def_xplan_last_wrap
undefine def_xplan_last_pagesize
undefine def_xplan_last_linesize
undefine def_xplan_last_heading
undefine def_xplan_last_feedback
undefine def_xplan_last_feedback_sqlid
'
/

alias -silent -nulldefaults -group rvo-cs -desc "plan_stats : sets statistics_level in the session" plan_stats=q'
tosub def_plan_stats_arg=:statistics_level
script
    /* save current settings: feedback */
    ctx.getMap().put("DEF_PLAN_STATS_FEEDBACK_SQLID", ctx.getFeedbackSQLID().toString())
    ctx.getMap().put("DEF_PLAN_STATS_FEEDBACK", ctx.getFeedback().toString())
    ctx.setFeedback(1)
    ctx.setFeedbackSQLID(false)
    var statLevel = ctx.getMap().get("DEF_PLAN_STATS_ARG").toUpperCase()
    var alterSessionStmt = 'alter session set statistics_level = "' + (statLevel.isEmpty() ? "ALL" : statLevel) + '"'
    sqlcl.setStmt(alterSessionStmt)
    ctx.write("\n" + alterSessionStmt + ";\n")
    sqlcl.run()
    /* Restore prior settings */
    ctx.setFeedback(parseInt(ctx.getMap().get("DEF_PLAN_STATS_FEEDBACK")))
    ctx.setFeedbackSQLID(ctx.getMap().get("DEF_PLAN_STATS_FEEDBACK_SQLID") === "true")
/
undefine def_plan_stats_arg
undefine def_plan_stats_feedback
undefine def_plan_stats_feedback_sqlid
'
/
