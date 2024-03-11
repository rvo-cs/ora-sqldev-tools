create or replace package body pkg_pub_utility as
/*
 * SPDX-FileCopyrightText: 2021-2023 R.Vassallo
 * SPDX-License-Identifier: BSD Zero Clause License
 */

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
       $IF dbms_db_version.ver_le_10 $THEN
        return dbms_db_version.release;
       $ELSIF dbms_db_version.ver_le_11 $THEN
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
    

    procedure assert_arg_null_or_yesno (
        p_arg_value  in varchar2,
        p_arg_name   in varchar2
    )
    is
    begin
        if p_arg_value is not null and upper(p_arg_value) not in ('Y', 'N') 
        then
            raise_application_error(-20000, 
                    'bad argument: ' || p_arg_name || ' must by ''Y'', ''N'', or null');
        end if;
    end assert_arg_null_or_yesno;


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


    function strtok (
        p_str            in varchar2,
        p_unquote        in varchar2  default 'Y',
        p_backslash_esc  in varchar2  default 'N'
    )
    return sys.odcivarchar2list
    is
        lc_re_no_esc constant varchar2(100) := 
                '\s* ( ( [^"[:space:]] "? )+ | " ( [^"] )* " ) \s*';

        lc_re_wt_esc constant varchar2(100) := 
                '\s* ( ( [^"\[:space:]] | \\. )+ | " ( [^\"] | \\. )* " ) \s*';
        
        l_re     varchar2(100);
        l_result sys.odcivarchar2list;
        
    begin
        assert_arg_null_or_yesno( p_unquote       , 'p_unquote' );
        assert_arg_null_or_yesno( p_backslash_esc , 'p_backslash_esc' );
        
        if p_str is null or regexp_like(p_str, '^[[:space:]]+$') then
            /* 
               Empty or all-blank string 
               => return an empty collection 
             */
            return sys.odcivarchar2list();
        end if;
        
        l_re := case 
                    when upper(p_backslash_esc) = 'Y'
                    then lc_re_wt_esc 
                    else lc_re_no_esc
                end;
        
        with
        inputs as (
            select
                p_str  as str,
                l_re   as rex
            from
                dual
        ),
        tokens as (
            select
                level                                       as rn,
                regexp_substr(a.str, a.rex, 1, level, 'x')  as tok
            from
                inputs a
            connect by
                regexp_instr (a.str, a.rex, 1, level, 0, 'x') > 0
        ),
        trimmed_tokens as (
            select
                b.rn,
                regexp_replace(regexp_replace(b.tok, '^\s*'), '\s*$')  as tok
            from
                tokens b
        ),
        refined_tokens as (
            select 
                c.rn,
                case
                    when upper(p_unquote) = 'Y' 
                    then regexp_replace(c.tok, '^" (.*) "$', '\1', 1, 1, 'nx')
                    else c.tok
                end  as tok
            from
                trimmed_tokens c
        )
        select
            case 
                when upper(p_backslash_esc) = 'Y' 
                then regexp_replace(d.tok, '\\(.)', '\1', 1, 0, 'n')
                else d.tok
            end
            bulk collect into l_result
        from
            refined_tokens d
        order by 
            d.rn asc;

        return l_result;            
    end strtok;


    function enquote_name ( p_sql_name in varchar2 ) return varchar2
    is
    begin
        return dbms_assert.enquote_name(str => p_sql_name, capitalize => false);
    end enquote_name;
    

    function is_quoted_string (
        p_str        in varchar2,
        p_quote_chr  in varchar2  default '"'
    )
    return varchar2
    is
    begin
        return
            case
                when substr(p_str, 1, 1) = p_quote_chr and substr(p_str, -1, 1) = p_quote_chr
                then 'Y'
                else 'N'
            end;
    end is_quoted_string;
    

    function dequote_string ( 
        p_str        in varchar2,
        p_quote_chr  in varchar2  default '"'
    )
    return varchar2
    is
    begin
        return 
            case
                when is_quoted_string(p_str, p_quote_chr) = 'Y'
                then substr(p_str, 2, length(p_str) - 2)
                else p_str
            end;
    end dequote_string;


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
            else round( p_arg, greatest(0, p_digits - floor(log(10, abs(p_arg)))) )
           end;
    end prec_round;

end pkg_pub_utility;
/
