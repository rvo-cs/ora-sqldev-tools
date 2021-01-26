create or replace package pkg_pub_call_stack_helper authid current_user as
/*
 * PACKAGE
 *      pkg_pub_call_stack_helper
 *
 * PURPOSE
 *      Simple wrapper around utl_call_stack for returning/printing
 *      the call stack
 *
 * SECURITY
 *      This package is defined as AUTHID CURRENT USER and runs with the
 *      privileges of the caller.
 *
 *      EXECUTE on this package is expected to be granted to PUBLIC.
 *
 */

    /*
     * Returns the current call stack as a multi-line varchar2 string.
     */
    function call_stack(
        p_skip_frames     in number   default 1,    /* Count of top-level frames to omit */
        p_pretty_print    in varchar2 default 'Y',  /* if Y, the readout is pretty-printed */
        p_quote_names     in varchar2 default 'N',  /* if Y, names in the readout will be quoted */
        p_show_start_end  in varchar2 default 'Y'   /* if Y, include start/end markers */
    )
    return varchar2;
    
    /*
     * Writes the current call stack to the DBMS_OUTPUT buffer.
     */
    procedure print_call_stack(
        p_skip_frames     in number   default 1,    /* Count of top-level frames to omit */
        p_pretty_print    in varchar2 default 'Y',  /* if Y, the readout is pretty-printed */
        p_quote_names     in varchar2 default 'N',  /* if Y, names in the readout will be quoted */
        p_show_start_end  in varchar2 default 'Y'   /* if Y, include start/end markers */
    );

end pkg_pub_call_stack_helper;
/
