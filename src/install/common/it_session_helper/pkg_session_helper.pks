create or replace package pkg_session_helper authid definer as
/*
 * PACKAGE
 *      pkg_session_helper
 *
 * PURPOSE
 *      Procedures in this package enable users to perform privileged actions
 *      on sessions (theirs, or that of other users), provided they have been
 *      authorized to do so by granting them a role authorizing the action.
 *
 * SECURITY
 *      This package is AUTHID DEFINER, hence it runs with the privileges of
 *      its owner. Each procedure in this package runs its own security checks,
 *      and either denies or authorizes the action depending on roles enabled
 *      in the calling session. Therefore, EXECUTE permission on this package
 *      can be granted to PUBLIC.
 */

    subtype t_role_name is user_role_privs.granted_role %type;

    gc_role_end_session_self   constant t_role_name := '&&def_it_role_end_session_self';
    gc_role_end_session_prefix constant t_role_name := '&&def_it_role_end_session_prefix';

    /*
       Calls ALTER SYSTEM DISCONNECT SESSION on the specified session,
       iff the session user is authorized to do so through an enabled role.
        
       Supported roles are as follows:
          . DBA
                Users with the DBA role may terminate any session
          . IT_END_SESS_SELF
                This role grants permission to kill one's own sessions
          . "IT_END_SESS:username"
                This role grants the bearer permission to end sessions
                of the specified username
        
        The action is logged in the log table; callers are encouraged to
        supply a reason for terminating the target session.
     */
    procedure disconnect_session(
        p_session_id        in number,
        p_session_serial#   in number,
        p_reason            in varchar2  default null,
        p_post_transaction  in boolean   default false
    );

end pkg_session_helper;
/
