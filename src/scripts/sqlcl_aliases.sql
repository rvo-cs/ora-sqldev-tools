/*
    sqlcl_aliases.sql

    DESCRIPTION
        This script sets SQLcl aliases for other SQL scripts here.

    PREREQUISITE
        The following substitution variable must be defined and
        point to the _root_ directory of your working copy of the
        ora-sqldev-tools Git repository.
        
        DEFINE RVOCS_ORASQLDEVTOOLS_DIR = "path to working copy root dir."

        E.g. &RVOCS_ORASQLDEVTOOLS_DIR/src/scripts/sqlcl_aliases.sql is the
        full path to this script.
        
 */

alias group=rvo-cs show_system_stats=@&RVOCS_ORASQLDEVTOOLS_DIR/src/scripts/config/system_stats_report;
alias desc show_system_stats : a report showing the state of system statistics + related optimizer parameters

@@sqlcl/aliases/sql_trace
@@sqlcl/aliases/sql_optimizer_trace
@@sqlcl/aliases/sql_compiler_trace
@@sqlcl/aliases/xplan_last
