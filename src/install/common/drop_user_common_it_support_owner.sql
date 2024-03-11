/*
 * SPDX-FileCopyrightText: 2020 R.Vassallo
 * SPDX-License-Identifier: Apache License 2.0
 */

whenever sqlerror exit failure rollback

set serveroutput on format word_wrapped

variable v_username varchar2(30)

exec :v_username := '&IT_SUPPORT_USERNAME';

declare
    l_username varchar2(30) := :v_username;

    procedure exec_stmt (p_stmt in varchar2)
    is begin
        execute immediate p_stmt;
        dbms_output.put_line('Done:  ' || p_stmt);
    exception
        when others then
            dbms_output.put_line('FAILED:  ' || p_stmt);
            raise;
    end exec_stmt;
begin
    dbms_output.enable(null);

    for c in ( select a.synonym_name from dba_synonyms a
                where a.owner = 'PUBLIC'
                  and a.table_owner = l_username )
    loop
        exec_stmt('drop public synonym '
                || dbms_assert.enquote_name(c.synonym_name, false));
    end loop;
    
    exec_stmt('drop user ' || dbms_assert.enquote_name(l_username, false)
            || ' cascade');
end;
/

