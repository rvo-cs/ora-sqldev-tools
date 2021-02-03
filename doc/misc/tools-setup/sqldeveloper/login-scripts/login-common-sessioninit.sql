/*-----------------*/
/* PL/SQL settings */
/*-----------------*/

alter session set plsql_code_type = 'INTERPRETED';
--alter session set plsql_code_type = 'NATIVE';

alter session set plsql_optimize_level = 2;

/* Deprecated: use plsql_optimize_level=1 to compile in debug mode */
alter session set plsql_debug = false;

/*
    PL/SQL disabled warnings:
    . PLW-06009: procedure "string" OTHERS handler does not end in RAISE or RAISE_APPLICATION_ERROR
    . PLW-05018: unit string omitted optional AUTHID clause; default value DEFINER used
 */
alter session set plsql_warnings = 'ENABLE:ALL,DISABLE:6009';
--alter session set plsql_warnings = 'ENABLE:ALL,DISABLE:6009,DISABLE:5018';


