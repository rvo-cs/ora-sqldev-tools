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

-- Workaround for ansiconsole being disabled in SQLcl 26.2 after column ... noprint
alias -silent -group rvo-cs -desc "fix_ctx_columnmap : removes cleared columns from ctx.getColumnMap()" fix_ctx_columnmap=q'
@&RVOCS_ORASQLDEVTOOLS_DIR/src/scripts/sqlcl/misc/fix_ctx_columnmap.sql
'
/
set define on

@@sqlcl/aliases/sql_trace-post_23_4
@@sqlcl/aliases/sql_optimizer_trace-post_23_4
@@sqlcl/aliases/sql_compiler_trace-post_23_4
@@sqlcl/aliases/xplan_last-post_23_4
