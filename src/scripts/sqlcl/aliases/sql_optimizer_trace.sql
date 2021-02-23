alias nulldefaults group=rvo-cs sql_optimizer_trace=q'<
/*
 *  sql_optimizer_trace: turns tracing in the SQL optimizer on/off
 *                      for this session [SQLcl alias]
 *  
 *  Examples
 *  ~~~~~~~~
 *  
 *  sql_optimizer_trace "fnzmd9dq5xhkc"   -- For the specified SQL id
 *  
 *  sql_optimizer_trace                   -- Caution: for all queries!
 *  
 *  sql_optimizer_trace off               -- Turns tracing off
 */
declare
    l_sqlid     varchar2(20);
    l_is_off    boolean;
    l_sqlcl_cmd varchar2(200);
    --
    function assert_sqlid(p_sqlid in varchar2, p_arg# in number) return varchar2
    is begin
        if not regexp_like(p_sqlid, '^[0-9a-df-hjkmnp-z]+$', 'i') then
            raise_application_error(-20000,
                    'Bad argument #' || to_char(p_arg#) || ' (invalid SQL id)');
        end if;
        return lower(p_sqlid);
    end assert_sqlid;
begin
    :sqlcl_int_first := :sqlcl_int_first;
    :sqlcl_int_second := :sqlcl_int_second;
    if :sqlcl_int_second is not null then
        raise_application_error(-20000, 'Too many arguments');
    end if;
    if upper(:sqlcl_int_first) = 'OFF' then
        l_is_off := true;
    else
        l_sqlid := assert_sqlid(:sqlcl_int_first, 1);
    end if;
    l_sqlcl_cmd := 'alter session set events = ''trace[rdbms.SQL_Optimizer.*]'
            || case when l_sqlid is not null then '[sql:' || l_sqlid || ']' end
            || case when l_is_off then ' off' else ' disk=high' end
            || '''';
    :sqlcl_int_runme := q'(set echo on
)' || l_sqlcl_cmd || q'(;
set echo off)';
exception
    when others then
        :sqlcl_int_runme :=
                'prompt ' || dbms_assert.enquote_name(rtrim(sqlerrm), false);
end;
/
alias NULLDEFAULTS sqlcl_int_runme=:sqlcl_int_runme;
sqlcl_int_runme
alias drop sqlcl_int_runme
>';

alias desc sql_optimizer_trace : turns tracing in the SQL optimizer on/off for this session

alias group=rvo-cs sql_optimizer_trace_off=q'<set echo on
alter session set events = 'trace[rdbms.SQL_Optimizer.*] off';
set echo off
>';

alias desc sql_optimizer_trace_off : turns off tracing in the SQL optimizer for this session
