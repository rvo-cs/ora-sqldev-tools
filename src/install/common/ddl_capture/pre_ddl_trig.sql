create or replace trigger trig_ddl_pre
before ddl on database
disable
declare
    l_ddl_text  clob;
    l_sql_text  ora_name_list_t;
    l_n         pls_integer;
begin
    if sys_context('USERENV', 'SESSION_USER') in ('SYS', 'SYSTEM')
        and ora_dict_obj_owner in ('SYS', 'SYSTEM')
    then
        return;
    end if;
    l_n := ora_sql_txt(l_sql_text);
    for i in 1 .. l_n loop
        l_ddl_text := l_ddl_text || l_sql_text(i);
    end loop;
    insert into &&def_pre_ddl_table (
        seq_num,
        event_type,
        object_type,
        object_owner,
        object_name,
        ddl_text
    )
    values (
        seq_ddl_pre.nextval,
        ora_sysevent, 
        substrb(ora_dict_obj_type, 1, 20), 
        substrb(ora_dict_obj_owner, 1, 128),
        substrb(ora_dict_obj_name, 1, 128),
        l_ddl_text
    );
exception
    when others then null;
end;
/
