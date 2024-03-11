create or replace package body pkg_pub_stats_helper as
/*
 * SPDX-FileCopyrightText: 2018-2021 R.Vassallo
 * SPDX-License-Identifier: BSD Zero Clause License
 */

    function raw_value_as_vc2 (p_raw in raw, p_data_type in varchar2) return varchar2 
    is 
        l_varchar2_value        varchar2(200 char);
        l_nvarchar2_value       nvarchar2(200 char);
        l_float_value           float;
        l_binary_double_value   binary_double;
        l_date_value            date;
        l_timestamp_value       t_precise_timestamp;
        l_timestamp_tz_value    t_precise_timestamp_tz;
        l_local_timestamp_value t_precise_local_timestamp;
        l_yminterval_value      t_precise_ym_interval;
        l_dsinterval_value      t_precise_ds_interval;
        l_number_value          number;
        l_rowid_value           rowid;

    begin
        case 
            when p_raw is null 
            then
                null;
                
            when p_data_type in ('VARCHAR2', 'CHAR') then 
                dbms_stats.convert_raw_value(rawval => p_raw, resval => l_varchar2_value);
        
            when p_data_type = 'NUMBER' then
                dbms_stats.convert_raw_value (rawval => p_raw, resval => l_number_value);
                l_varchar2_value := to_char(l_number_value);
            
            when p_data_type = 'DATE' then
                l_date_value := decode_date(p_raw);
                l_varchar2_value := ltrim(to_char(l_date_value, 'SYYYY.MM.DD HH24:MI:SS'));
            
            when regexp_like(p_data_type, '^ TIMESTAMP ( \( \d+ \) )? $', 'ix') then
                l_timestamp_value := decode_timestamp(p_raw);
                l_varchar2_value := ltrim(to_char(l_timestamp_value, 'SYYYY.MM.DD HH24:MI:SSXFF'));
            
            when regexp_like(p_data_type,
                    '^ TIMESTAMP ( \(\d+\) )? \s WITH \s LOCAL \s TIME \s ZONE $', 'ix') then
                l_local_timestamp_value := decode_local_timestamp(p_raw);
                l_varchar2_value := ltrim(to_char(l_local_timestamp_value, 'SYYYY.MM.DD HH24:MI:SSXFF'));
            
            when regexp_like(p_data_type,
                    '^ TIMESTAMP ( \(\d+\) )? \s WITH \s TIME \s ZONE $', 'ix') then
                l_timestamp_tz_value := decode_timestamp_tz(p_raw);
                l_varchar2_value := ltrim(to_char(l_timestamp_tz_value, 'SYYYY.MM.DD HH24:MI:SSXFF TZR'));
            
            when regexp_like(p_data_type,
                    '^ INTERVAL \s YEAR ( \(\d+\) )? \s TO \s MONTH $', 'ix') then
                l_yminterval_value := decode_yminterval(p_raw);
                l_varchar2_value :=  regexp_replace(to_char(l_yminterval_value),
                        '^([-+])([0]+)(\d\d)', '\1\3');
            
            when regexp_like(p_data_type,
                    '^ INTERVAL \s DAY ( \(\d+\) )? \s TO \s SECOND ( \(\d+\) )? $', 'ix') then
                l_dsinterval_value := decode_dsinterval(p_raw);
                l_varchar2_value := regexp_replace(to_char(l_dsinterval_value),
                        '^([-+])([0]+)(\d\d)', '\1\3');
            
            when p_data_type = 'FLOAT' then
                dbms_stats.convert_raw_value (rawval => p_raw, resval => l_float_value);
                l_varchar2_value := to_char(l_float_value);

            when p_data_type in ('BINARY_FLOAT', 'BINARY_DOUBLE') then
                dbms_stats.convert_raw_value (rawval => p_raw, resval => l_binary_double_value);
                l_varchar2_value := to_char(l_binary_double_value);
            
            when p_data_type in ('ROWID', 'UROWID') then
                dbms_stats.convert_raw_value_rowid (rawval => p_raw, resval => l_rowid_value);
                l_varchar2_value := to_char(l_rowid_value);
            else
                null;
        end case;
            
        return l_varchar2_value;
    exception
        when others then
            return '### ORA' || to_char(sqlcode) || ' ###';
    end raw_value_as_vc2;


    function decode_date_as_vc2 ( p_raw in raw ) 
    return varchar2
    is
    begin
        return
            to_char(
                100 * (to_number(substr(p_raw, 1, 2), 'XX') - 100)   -- century (excess-100) 
                    + (to_number(substr(p_raw, 3, 2), 'XX') - 100),  -- year    (excess-100)
                '0000')
                    ||'.'|| to_char(to_number(substr(p_raw, 5, 2), 'XX'), 'FM00')        -- month   (as is)
                    ||'.'|| to_char(to_number(substr(p_raw, 7, 2), 'XX'), 'FM00')        -- day     (as is)
                    ||' '|| to_char(to_number(substr(p_raw, 9, 2), 'XX') - 1, 'FM00')    -- hours   (excess-1)
                    ||':'|| to_char(to_number(substr(p_raw, 11, 2), 'XX') - 1, 'FM00')   -- minutes (excess-1)
                    ||':'|| to_char(to_number(substr(p_raw, 13, 2), 'XX') - 1, 'FM00');  -- seconds (excess-1)
    end decode_date_as_vc2;

    
    function decode_timestamp_as_vc2 (p_raw in raw, p_is_with_tz in boolean)
    return varchar2
    is
    begin
        return decode_date_as_vc2(p_raw)
                || '.'|| to_char(nvl(to_number(substr(p_raw, 15, 8), 'XXXXXXXX'), 0), 'FM000000000')
                || case when p_is_with_tz then ' UTC' end;
    end decode_timestamp_as_vc2;
    

    function decode_date (p_raw in raw) 
    return date
    is
    begin
        return to_date(decode_date_as_vc2(p_raw), 'SYYYY.MM.DD HH24:MI:SS');
    end decode_date;

    
    function decode_timestamp (p_raw in raw)
    return t_precise_timestamp
    is
    begin
        return to_timestamp( decode_timestamp_as_vc2(p_raw, false)
                           , 'SYYYY.MM.DD HH24:MI:SSXFF' );
    end decode_timestamp;
    
    
    function decode_timestamp_tz (p_raw in raw)
    return t_precise_timestamp_tz
    is
    begin
        return to_timestamp_tz( decode_timestamp_as_vc2(p_raw, true)
                              , 'SYYYY.MM.DD HH24:MI:SSXFF TZR' );
    end decode_timestamp_tz;
    

    function decode_local_timestamp (p_raw in raw)
    return t_precise_local_timestamp
    is
    begin
        return cast( to_timestamp( decode_timestamp_as_vc2(p_raw, false)
                                 , 'SYYYY.MM.DD HH24:MI:SSXFF' )  
                     as t_precise_local_timestamp );
    end decode_local_timestamp;
    
 
    function decode_yminterval (p_raw in raw)
    return t_precise_ym_interval
    is
    begin
        return numtoyminterval(to_number(substr(p_raw, 1, 8), 'XXXXXXXX') - power(2,31), 'YEAR')
                + numtoyminterval(to_number(substr(p_raw, 9, 2), 'XX') - 60, 'MONTH');
    end decode_yminterval;
 

    function decode_dsinterval (p_raw in raw)
    return t_precise_ds_interval
    is
    begin
        return
            numtodsinterval(to_number(substr(p_raw, 1, 8), 'XXXXXXXX') - power(2,31), 'DAY')
                    + numtodsinterval(to_number(substr(p_raw, 9, 2), 'XX') - 60, 'HOUR')
                    + numtodsinterval(to_number(substr(p_raw, 11, 2), 'XX') - 60, 'MINUTE')
                    + numtodsinterval(to_number(substr(p_raw, 13, 2), 'XX') - 60, 'SECOND')
                    + numtodsinterval((to_number(substr(p_raw, 15, 8), 'XXXXXXXX') - power(2,31))
                            / power(10, 9), 'SECOND');
    end decode_dsinterval;

end pkg_pub_stats_helper;
