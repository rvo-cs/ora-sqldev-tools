create or replace package pkg_dba_parse_util authid current_user as
/*
 * SPDX-FileCopyrightText: 2023 R.Vassallo
 * SPDX-License-Identifier: Apache License 2.0
 */

/*
 * PACKAGE
 *      pkg_dba_parse_util
 *
 * PURPOSE
 *      wrapper around the UTL_XML.parsequery procedure
 *      (but exposing it as a function)
 *
 * SECURITY
 *      This package is defined as AUTHID CURRENT USER and runs with the
 *      privileges of the caller.
 *
 *      The owner of this package must have the following object privs:
 *        . EXECUTE on the SYS.UTL_XML package
 *        . For Oracle >= 18c: EXECUTE on the SYS.UTL_XML_LIB library
 *
 *      WARNING: beginning with 18c, the p_parsing_userid argument, if different
 *      from the session user id, enables the caller to perform the parse AS IF
 *      having all the permissions of the specified user id, regardless of the
 *      caller's own level of privileges. (If p_parsing_userid is the same as the
 *      session user id, then the parse is performed with the privileges enabled
 *      in the session.) Therefore, EXECUTE on this package should be considered
 *      a DBA-level permission, and should be granted to selected users only.
 *      In releases < 18c, that argument is not available, and the parse is always
 *      performed with the privileges enabled in the calling session.
 */

    /*
        Wrapper around UTL_XML.parsequery -- see above comments.
     */
    function parsequery(
        p_parsing_schema  in varchar2,
       $if dbms_db_version.version >= 18 $then
        p_parsing_userid  in number  default sys_context('USERENV', 'SESSION_USERID'),
       $end
        p_sqltext         in clob
    )
    return xmltype;

    /*
        Returns the text of the specified view, as a clob; calls UTL_XML.long2clob
        to convert the value of the TEXT column of SYS.VIEW$ from LONG to CLOB.
        Required privileges: READ on DBA_OBJECTS and SYS.VIEW$
     */
    function view_text_as_clob (
        p_owner      in varchar2,
        p_view_name  in varchar2
    )
    return clob;

end pkg_dba_parse_util;
/
