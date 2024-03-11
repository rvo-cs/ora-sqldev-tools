create or replace package pkg_pub_partition_helper authid current_user as
/*
 * SPDX-FileCopyrightText: 2018 R.Vassallo
 * SPDX-License-Identifier: BSD Zero Clause License
 */

/*
 * PACKAGE
 *      pkg_pub_partition_helper
 *
 * PURPOSE
 *      Package for functions and procedures returning information
 *      about partitions and subpartitions of tables.
 *
 * SECURITY
 *      This package is defined as AUTHID CURRENT USER and runs with the
 *      privileges of the caller.
 *
 *      EXECUTE on this package is expected to be granted to PUBLIC.
 *
 */

    /*
     * Returns the high value of the specified table partition
     * or subpartition.
     */
    function high_value_as_vc2(
        p_owner in varchar2,
        p_table_name in varchar2,
        p_part_name in varchar2,
        p_subpart_name in varchar2 default null
    )
    return varchar2;

end pkg_pub_partition_helper;
/
