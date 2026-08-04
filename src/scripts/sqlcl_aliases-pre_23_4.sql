/*
 * SPDX-FileCopyrightText: 2021-2024 R.Vassallo
 * SPDX-License-Identifier: BSD Zero Clause License
 */

/*
    sqlcl_aliases-pre_23_4.sql

    DESCRIPTION
        This script creates or redefines SQLcl aliases.

    SQLCL VERSION
        SQLcl <= 23.3 : legacy syntax of the ALIAS command
*/

set define off
alias group=rvo-cs show_system_stats=@&RVOCS_ORASQLDEVTOOLS_DIR/src/scripts/config/system_stats_report;
alias desc show_system_stats : a report showing the state of system statistics + related optimizer parameters
set define on

@@sqlcl/aliases/sql_trace
@@sqlcl/aliases/sql_optimizer_trace
@@sqlcl/aliases/sql_compiler_trace
@@sqlcl/aliases/xplan_last
