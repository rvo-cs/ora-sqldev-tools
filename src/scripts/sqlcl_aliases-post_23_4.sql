/*
 * SPDX-FileCopyrightText: 2024 R.Vassallo
 * SPDX-License-Identifier: BSD Zero Clause License
 */

/*
    sqlcl_aliases-post_23_4.sql

    DESCRIPTION
        This script sets SQLcl aliases for other SQL scripts here.

    VERSION
        This script is for SQLcl 23.4 and higher, using the new syntax
        of the ALIAS command.

    PREREQUISITE
        The following substitution variable must be defined and
        point to the _root_ directory of your working copy of the
        ora-sqldev-tools Git repository.
        
        DEFINE RVOCS_ORASQLDEVTOOLS_DIR = "path to working copy root dir."

        E.g. &RVOCS_ORASQLDEVTOOLS_DIR/src/scripts/sqlcl_aliases.sql is the
        full path to this script.
        
 */

set define off
alias -silent -group rvo-cs -desc "show_system_stats : a report showing the state of system statistics + related optimizer parameters" show_system_stats=q'
@&RVOCS_ORASQLDEVTOOLS_DIR/src/scripts/config/system_stats_report
'
/
set define on

@@sqlcl/aliases/sql_trace-post_23_4
@@sqlcl/aliases/sql_optimizer_trace-post_23_4
@@sqlcl/aliases/sql_compiler_trace-post_23_4
@@sqlcl/aliases/xplan_last-post_23_4
