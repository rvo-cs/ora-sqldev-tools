/*
 * SPDX-FileCopyrightText: 2024 R.Vassallo
 * SPDX-License-Identifier: BSD Zero Clause License
 */

/*
    sqlcl_aliases-post_23_4.sql

    DESCRIPTION
        This script creates or redefines SQLcl aliases.

    SQLCL VERSION
        SQLcl >= 23.4 : new syntax of the ALIAS command
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
