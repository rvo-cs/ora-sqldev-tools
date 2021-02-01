/*
    sqlplus_aliases.sql

    DESCRIPTION
        This script sets SQL*Plus substitution variables which reference
        other SQL scripts here.

    PREREQUISITE
        The following substitution variable must be defined and
        point to the _root_ directory of your working copy of the
        ora-sqldev-tools Git repository.
        
        DEFINE RVOCS_ORASQLDEVTOOLS_DIR = "path to working copy root dir."

        E.g. &RVOCS_ORASQLDEVTOOLS_DIR\src\scripts\sqlplus_aliases.sql
        is the full path to this script.
        
 */

define show_system_stats = "&RVOCS_ORASQLDEVTOOLS_DIR\src\scripts\config\system_stats_report"
