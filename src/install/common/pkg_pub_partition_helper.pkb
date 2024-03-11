create or replace package body pkg_pub_partition_helper as
/*
 * SPDX-FileCopyrightText: 2018-2021 R.Vassallo
 * SPDX-License-Identifier: BSD Zero Clause License
 */

    gc_sqlstmt_hv_all_tab_part constant varchar2(500 byte) := 
            q'{select a.high_value 
                 from all_tab_partitions a
                where a.table_owner = :B_OWNER
                  and a.table_name  = :B_TABLE_NAME
                  and a.partition_name = :B_PART_NAME}';

    gc_sqlstmt_hv_dba_tab_part constant varchar2(500 byte) := 
            q'{select a.high_value 
                 from dba_tab_partitions a
                where a.table_owner = :B_OWNER
                  and a.table_name  = :B_TABLE_NAME
                  and a.partition_name = :B_PART_NAME}';

    gc_sqlstmt_hv_all_tab_subpart constant varchar2(500 byte) := 
            q'{select a.high_value
                 from all_tab_subpartitions a
                where a.table_owner = :B_OWNER
                  and a.table_name  = :B_TABLE_NAME
                  and a.partition_name    = :B_PART_NAME
                  and a.subpartition_name = :B_SUBPART_NAME}';

    gc_sqlstmt_hv_dba_tab_subpart constant varchar2(500 byte) := 
            q'{select a.high_value
                 from dba_tab_subpartitions a
                where a.table_owner = :B_OWNER
                  and a.table_name  = :B_TABLE_NAME
                  and a.partition_name    = :B_PART_NAME
                  and a.subpartition_name = :B_SUBPART_NAME}';


    function high_value_as_vc2(
        p_owner in varchar2,
        p_table_name in varchar2,
        p_part_name in varchar2,
        p_subpart_name in varchar2 default null
    )
    return varchar2 
    is
        l_high_value    varchar2(4000 byte);
        l_use_dba_views boolean;
    begin
        l_use_dba_views :=
                (dbms_session.is_role_enabled('SELECT_CATALOG_ROLE')
                 or sys_context('USERENV', 'ISDBA') = 'TRUE');
        if p_subpart_name is null then
            execute immediate 
                case 
                    when l_use_dba_views then gc_sqlstmt_hv_dba_tab_part
                    else gc_sqlstmt_hv_all_tab_part
                end
            into l_high_value
            using p_owner, p_table_name,
                  p_part_name;
        else
            execute immediate
                case
                    when l_use_dba_views then gc_sqlstmt_hv_dba_tab_subpart
                    else gc_sqlstmt_hv_all_tab_subpart
                end
            into l_high_value
            using p_owner, p_table_name,
                  p_part_name, p_subpart_name;
        end if;
        return l_high_value;
    end high_value_as_vc2;

end pkg_pub_partition_helper;

