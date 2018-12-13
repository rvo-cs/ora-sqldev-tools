create or replace package body pkg_pub_partition_helper as

    function high_value_as_vc2(
        p_owner in varchar2,
        p_table_name in varchar2,
        p_part_name in varchar2,
        p_subpart_name in varchar2 default null
    )
    return varchar2 
    is
        l_high_value varchar2(4000 byte);
    begin
        if p_subpart_name is null then
            select a.high_value into l_high_value
            from all_tab_partitions a
            where
                a.table_owner = p_owner
                and a.table_name = p_table_name
                and a.partition_name = p_part_name;

        else
            select a.high_value into l_high_value
            from all_tab_subpartitions a
            where
                a.table_owner = p_owner
                and a.table_name = p_table_name
                and a.partition_name = p_part_name
                and a.subpartition_name = p_subpart_name;
        end if;

        return l_high_value;
    end high_value_as_vc2;

end pkg_pub_partition_helper;

