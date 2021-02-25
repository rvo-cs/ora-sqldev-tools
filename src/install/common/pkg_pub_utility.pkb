create or replace package body pkg_pub_utility as

    function db_version
    return number 
    deterministic
    is begin
        return dbms_db_version.version;
    end db_version;

    
    function db_release (p_use_version_full in varchar2 default null)
    return number
    deterministic
    is begin
       $IF dbms_db_version.ver_le_11 $THEN
        return dbms_db_version.release;
       $ELSIF dbms_db_version.ver_le_12 $THEN
        return dbms_db_version.release;
       $ELSE
        if p_use_version_full is null or upper(p_use_version_full) <> 'Y' then
            return dbms_db_version.release;
        else
            declare
                l_release_str varchar2(10);
            begin
                select regexp_substr(a.version_full, '\d+\.(\d+)\.\d+\.\d+', 1, 1, null, 1)
                into l_release_str
                from product_component_version a
                where a.product like 'Oracle Database%' and rownum = 1;
                return to_number(l_release_str);
            end;
        end if;
       $END
    end db_release;
    

    function clob_as_varchar2list (p_clob in clob)
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


    function prec_round(
        p_arg     in number,    /* The quantity to be rounded */
        p_digits  in number  default 2
                                /* Count of decimal places, to the right of the
                                   most significant digit, where rounding happens. */
    )
    return number
    deterministic
    is
    begin
        return case 
            when p_arg = 0 then 0
            else round( p_arg, greatest(0, p_digits - floor(log(10, p_arg))) )
           end;
    end prec_round;

end pkg_pub_utility;
/
