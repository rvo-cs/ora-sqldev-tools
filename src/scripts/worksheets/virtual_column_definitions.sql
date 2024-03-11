/*
 * SPDX-FileCopyrightText: 2021 R.Vassallo
 * SPDX-License-Identifier: BSD Zero Clause License
 */

/*
    Sample query for extracting the definitions of all virtual columns
    from all tables in the database AND convert the DATA_DEFAULT column
    from LONG to VARCHAR2 (if possible), so it can be manipulated by
    ordinary SQL functions, e.g. regexp_xxxx, without the ORA-00997
    exception ("illegal use of LONG datatype").
*/

select
    b.*
from
    (select
        dbms_xmlgen.getxmltype(
            /* 
                Unfortunately, the argument of DBMS_XMLGEN.getxmltype
                here is the _text_ of the query, so we can't use binds.
                Trying something smarter using a SYS_REFCURSOR instead
                would only bring back the ORA-00997 exception  :-(
             */
            q'{select   
                    owner, table_name, column_name, 
                    column_id, internal_column_id,
                    data_default, hidden_column
               from 
                    dba_tab_cols
               where 
                    virtual_column = 'YES'
                    and data_default is not null
              }'
        ) as xml_tab_cols
    from dual
    ) a,
    xmltable(
        '/ROWSET/ROW'
        passing a.xml_tab_cols
        columns
            owner               varchar2(128 byte)  path 'OWNER', 
            table_name          varchar2(128 byte)  path 'TABLE_NAME', 
            column_name         varchar2(128 byte)  path 'COLUMN_NAME', 
            column_id           number              path 'COLUMN_ID', 
            internal_column_id  number              path 'INTERNAL_COLUMN_ID', 
            hidden_column       varchar2(3 byte)    path 'HIDDEN_COLUMN', 
            data_default        varchar2(4000 byte) path 'DATA_DEFAULT' 
    ) b
;
