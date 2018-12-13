create or replace package pkg_pub_stats_helper authid current_user as
/*
 * PACKAGE
 *      pkg_pub_stats_helper
 *
 * PURPOSE
 *      Helper package for functions and procedures related to statistics
 *      of objects in the Data Dictionary.
 *
 * SECURITY
 *      This package is defined as AUTHID CURRENT USER and runs with the
 *      privileges of the caller.
 *
 *      EXECUTE on this package is expected to be granted to PUBLIC.
 *
 */

    /*
     * Converts a raw low/high value from ALL_TAB_COL_STATISTICS into a human
     * readable varchar2 representation. Returns NULL if the input data type
     * is not supported by this function. Returns a string of the form
     * '### ORA-nnnnn ###' if the conversion raises an exception.
     */
    function raw_value_as_vc2(p_raw in raw, p_data_type in varchar2) return varchar2;

end pkg_pub_stats_helper;
