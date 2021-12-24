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
    function raw_value_as_vc2 ( p_raw in raw, p_data_type in varchar2 ) return varchar2;

    /*
     * NOTE: subtypes are needed here, otherwise return values implicitly use 
     * the default precision of the corresponding type. For timestamps this 
     * may result in rounding, whereas for intervals it may cause ORA-01873.
     */
    subtype t_precise_timestamp         is timestamp(9);
    subtype t_precise_timestamp_tz      is timestamp(9) with time zone;
    subtype t_precise_local_timestamp   is timestamp(9) with local time zone;
    subtype t_precise_ym_interval       is interval year(9) to month;
    subtype t_precise_ds_interval       is interval day(9) to second(9);

    /*
     * DECODE_XXX: converts a raw low/high value from ALL_TAB_COL_STATISTICS into
     * the corresponding data type value, or raises an exception in case of failure
     * (usually caused by invalid data in the originating column).
     *
     * Remark: for timestamps with time zone, the time zone region information 
     * is NOT decoded, therefore the equivalent timestamp in the UTC time zone
     * region is returned.
     */
    function decode_date            ( p_raw in raw ) return date;
    function decode_timestamp       ( p_raw in raw ) return t_precise_timestamp;
    function decode_timestamp_tz    ( p_raw in raw ) return t_precise_timestamp_tz;
    function decode_local_timestamp ( p_raw in raw ) return t_precise_local_timestamp;
    function decode_yminterval      ( p_raw in raw ) return t_precise_ym_interval;
    function decode_dsinterval      ( p_raw in raw ) return t_precise_ds_interval;

end pkg_pub_stats_helper;
