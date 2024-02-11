create or replace trigger trig_ddl_post
after ddl
    or create
    or alter 
    or drop
&&def_ddl_capture_grants    or grant
&&def_ddl_capture_grants    or revoke
on database
disable
begin
    if sys_context('USERENV', 'SESSION_USER') in ('SYS', 'SYSTEM')
        and ora_dict_obj_owner in ('SYS', 'SYSTEM')
    then
        return;
    end if;
    pkg_capture_ddl.capture_post;
exception
    when others then
        null;
end;
/
