create or replace function clob_as_varchar2list(p_clob in clob)
return sys.odcivarchar2list
pipelined
is
    lc_newln constant varchar2(1) := chr(10);
    l_p0 number;
    l_p1 number;
    l_len number;
begin
    l_len := length(p_clob);
    l_p0 := 1;
    <<main_loop>> 
    while l_p0 <= l_len loop
        l_p1 := instr(p_clob, lc_newln, l_p0);
        if l_p1 = 0 then
            pipe row(substr(p_clob, l_p0));
            exit main_loop;
        else
            pipe row(substr(p_clob, l_p0, l_p1 - l_p0));
            l_p0 := l_p1 + 1;
        end if;
    end loop main_loop;
end clob_as_varchar2list;
/
