alias nulldefaults group=rvo-cs sql_trace=q'<
/*
 *  sql_trace : turns SQL tracing on/off in the session  [SQLcl alias]
 *  
 *  Examples
 *  ~~~~~~~~
 *  
 *  sql_trace "fnzmd9dq5xhkc" wait=true  -- For the specified SQL id
 *  
 *  sql_trace wait=false                 -- Caution: for all queries!
 *  
 *  sql_trace off                        -- Turns SQL tracing off
 */
declare
    l_sqlid     varchar2(20);
    l_wait_arg  varchar2(20);
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
    --
    function assert_wait(p_wait_arg in varchar2, p_arg# in number) return varchar2
    is begin
        if not regexp_like(p_wait_arg, '^wait=(true|false)$', 'i') then
            raise_application_error(-20000, 
                    'Bad argument #' || to_char(p_arg#) || ' (expected: wait=true|false)');
        end if;
        return lower(p_wait_arg);
    end assert_wait;
begin
    :sqlcl_int_first := :sqlcl_int_first;
    :sqlcl_int_second := :sqlcl_int_second;
    if :sqlcl_int_second is null then
        if upper(:sqlcl_int_first) = 'OFF' then
            l_is_off := true;
        elsif regexp_like(:sqlcl_int_first, '^wait=', 'i') then
            l_wait_arg := assert_wait(:sqlcl_int_first, 1);
        else
            l_sqlid := assert_sqlid(:sqlcl_int_first, 1);
        end if;
    else
        l_sqlid     := assert_sqlid(:sqlcl_int_first, 1);
        l_wait_arg  := assert_wait(:sqlcl_int_second, 2);
    end if;
    l_sqlcl_cmd := 'alter session set events = ''sql_trace'
            || case when l_sqlid is not null then '[SQL:' || l_sqlid || ']' end
            || case when l_is_off then ' off' else ' plan_stat=all_executions,bind=true' end
            || case when l_wait_arg is not null then ',' || l_wait_arg end
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

alias desc sql_trace : turns SQL tracing on/off in the session

alias group=rvo-cs sql_trace_off=q'<set echo on
alter session set events = 'sql_trace off';
set echo off
>';

alias desc sql_trace_off : turns off SQL tracing in the session
