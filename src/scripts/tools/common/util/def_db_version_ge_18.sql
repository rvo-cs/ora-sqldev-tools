select
    version_major  as db_version_major,
    version_minor  as db_version_minor,
    case 
        when version_major >= 12 then
            null
        else
            '--'
    end  as def_db_version_ge_12,
    case
        when version_major < 12
            or (version_major = 12 and version_minor < 2)
        then
            null
        else
            '--'
    end  as def_db_version_lt_12_2,
    case
        when version_major > 12
            or (version_major = 12 and version_minor >= 2)
        then
            null
        else
            '--'
    end  as def_db_version_ge_12_2,
    case 
        when version_major < 18 then
            null
        else
            '--'
    end  as def_db_version_lt_18,
    case 
        when version_major >= 18 then
            null
        else
            '--'
    end  as def_db_version_ge_18,
    case 
        when version_major >= 19 then
            null
        else
            '--'
    end  as def_db_version_ge_19,
    case 
        when version_major >= 21 then
            null
        else
            '--'
    end  as def_db_version_ge_21,
    case 
        when version_major >= 23 then
            null
        else
            '--'
    end  as def_db_version_ge_23
from 
    (select
        to_number(regexp_substr(a.version_full, '(\d+)', 1, 1))  as version_major,
        to_number(regexp_substr(a.version_full, '(\d+)', 1, 2))  as version_minor
    from
        product_component_version a
    where 
        a.product like 'Oracle Database%' 
        and rownum = 1
    );

