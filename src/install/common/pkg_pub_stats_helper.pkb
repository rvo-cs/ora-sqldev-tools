create or replace package body pkg_pub_stats_helper as

    function raw_value_as_vc2(p_raw in raw, p_data_type in varchar2) return varchar2 
    is 
        l_varchar2_value varchar2(200 char);
        l_nvarchar2_value nvarchar2(200 char);
        l_float_value float;
        l_binary_double_value binary_double;
        l_date_value date;
        l_number_value number;
        l_rowid_value rowid;
    begin
        case 
            when p_data_type = 'VARCHAR2' then 
                dbms_stats.convert_raw_value(rawval => p_raw, resval => l_varchar2_value);
        
            when p_data_type = 'FLOAT' then
                dbms_stats.convert_raw_value (rawval => p_raw, resval => l_float_value);
                l_varchar2_value := to_char(l_float_value);

            when p_data_type in ('BINARY_FLOAT', 'BINARY_DOUBLE') then
                dbms_stats.convert_raw_value (rawval => p_raw, resval => l_binary_double_value);
                l_varchar2_value := to_char(l_binary_double_value);
            
            when p_data_type = 'DATE' or p_data_type like 'TIMESTAMP(_)' then
                dbms_stats.convert_raw_value (rawval => p_raw, resval => l_date_value);
                l_varchar2_value := to_char(l_date_value, 'YYYY-MM-DD HH24:MI:SS');
            
            when p_data_type = 'NUMBER' then
                dbms_stats.convert_raw_value (rawval => p_raw, resval => l_number_value);
                l_varchar2_value := to_char(l_number_value);
            
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

end pkg_pub_stats_helper;
