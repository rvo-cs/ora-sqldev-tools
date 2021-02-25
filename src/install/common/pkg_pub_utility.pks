create or replace package pkg_pub_utility authid current_user as
/*
 * PACKAGE
 *      pkg_pub_utility
 *
 * PURPOSE
 *      A package for miscellaneous utility routines for which no better
 *      place was found.
 *
 *      Remark: this package is stateless.
 *
 * SECURITY
 *      This package is defined as AUTHID CURRENT_USER and runs with the
 *      privileges of the caller.
 *
 *      EXECUTE on this package is expected to be granted to PUBLIC.
 *
 */

    /*
        Returns the Oracle Database major version number, e.g. 11, 12, 19...
        The returned value is the DBMS_DB_VERSION.version constant.
     */
    function db_version
    return number 
    deterministic;
    
    /*
        Returns the Oracle Database release number, e.g. 2 for 11.2, 1 for 12.1,
        and so forth.
        
        There's a catch for recent releases, as a distinction has been introduced
        between the Database "full version" string, e.g. 19.5.0.0, which includes
        the Database RU number, and the simple "version" string, e.g. 19.0.0.0,
        which does not. Unless the p_use_version_full argument is 'Y', the returned
        value is simply the DBMS_DB_VERSION.release constant, corresponding to the
        simple version string. Otherwise, the returned value is extracted from the
        FULL_VERSION column of the PRODUCT_COMPONENT_VERSION view.
     */
    function db_release (p_use_version_full in varchar2 default null)
    return number
    deterministic;
 
    /*
        Returns the contents of the CLOB argument, line by line. The line
        terminating character [chr(10) aka linefeed] is trimmed from returned
        rows. Prerequisite: lines in the argument must not exceed 4000 bytes.
     */
    function clob_as_varchar2list (p_clob in clob)
    return sys.odcivarchar2list
    pipelined;


    /*
        Returns the p_arg argument, rounded to at least p_digits places past
        the most significant digit. This guarantees that enough precision is
        retained in small quantities, while getting rid of unnecessary decimal
        figures (aka deceptive precision).
        
        Remark: rounding may happen on the first digit to the left of the decimal
        point, but not to any digit on its left. This means that large quantities
        are always rounded to the nearest integer.
        
        Examples:
            prec_round (   0.007777 )  =   0.00778
            prec_round (   0.077777 )  =   0.0778
            prec_round (   0.777777 )  =   0.778
            prec_round (   7.777777 )  =   7.78
            prec_round (  77.77777  )  =  77.8
            prec_round ( 777.7777   )  = 778
     */
    function prec_round(
        p_arg     in number,    /* The quantity to be rounded */
        p_digits  in number  default 2
                                /* Count of decimal places, to the right of the
                                   most significant digit, where rounding happens. */
    )
    return number
    deterministic;

end pkg_pub_utility;
/
