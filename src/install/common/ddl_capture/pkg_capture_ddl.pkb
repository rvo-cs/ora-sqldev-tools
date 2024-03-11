create or replace package body pkg_capture_ddl as
/*
 * SPDX-FileCopyrightText: 2024 R.Vassallo
 * SPDX-License-Identifier: BSD Zero Clause License
 */

    procedure capture_pre
    is
        l_ddl_text    clob;
        l_sql_text    ora_name_list_t;
        l_n           pls_integer;
        l_event_type  &&def_pre_ddl_table..event_type %type;
       $if $$ddl_capture_grant_details $then
        l_seq_num     &&def_pre_ddl_table..seq_num    %type;
        l_ddl_time    &&def_pre_ddl_table..ddl_time   %type;
       $end
    begin
        l_event_type := ora_sysevent;
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
            l_event_type, 
            substrb(ora_dict_obj_type, 1, 20), 
            substrb(ora_dict_obj_owner, 1, 128),
            substrb(ora_dict_obj_name, 1, 261),
            l_ddl_text
        )
       $if $$ddl_capture_grant_details $then
        returning
            seq_num, 
            ddl_time
        into
            l_seq_num,
            l_ddl_time
       $end
        ;
       $if $$ddl_capture_grant_details $then
        if l_event_type in ('GRANT', 'REVOKE') then
            <<grant_or_revoke_details>>
            declare
                l_cnt_grantees    pls_integer;
                l_cnt_privileges  pls_integer;
                l_grantees        ora_name_list_t;
                l_privileges      ora_name_list_t;
                l_grant_option    &&def_pre_grant_table..grant_option %type;
            begin
                if ora_with_grant_option then
                    l_grant_option := 'Y';
                end if;
                l_cnt_privileges := ora_privilege_list(l_privileges);
                if l_event_type = 'GRANT' then
                    l_cnt_grantees := ora_grantee(l_grantees);
                else
                    l_cnt_grantees := ora_revokee(l_grantees);
                end if;
                <<privs_loop>>
                for i in 1 .. l_cnt_privileges loop
                    <<grantees_loop>>
                    for j in 1 .. l_cnt_grantees loop
                        insert into &&def_pre_grant_table (
                            seq_num,
                            ddl_time,
                            privilege,
                            grantee,
                            grant_option
                        )
                        values (
                            l_seq_num,
                            l_ddl_time,
                            substrb(l_privileges(i), 1, 261),
                            substrb(l_grantees(j), 1, 261),
                            l_grant_option
                        );
                    end loop grantees_loop;
                end loop privs_loop;
            end grant_or_revoke_details;
        end if;
       $end
    end capture_pre;
    
    /*
      Remark: capture_post is 100% similar to capture_pre, the only difference being
      that capture_post uses "post" tables + sequence, whereas capture_pre uses the
      corresponding "pre" tables + sequence.
     */
     
    procedure capture_post
    is
        l_ddl_text    clob;
        l_sql_text    ora_name_list_t;
        l_n           pls_integer;
        l_event_type  &&def_post_ddl_table..event_type %type;
       $if $$ddl_capture_grant_details $then
        l_seq_num     &&def_post_ddl_table..seq_num    %type;
        l_ddl_time    &&def_post_ddl_table..ddl_time   %type;
       $end
    begin
        l_event_type := ora_sysevent;
        l_n := ora_sql_txt(l_sql_text);
        for i in 1 .. l_n loop
            l_ddl_text := l_ddl_text || l_sql_text(i);
        end loop;
        insert into &&def_post_ddl_table (
            seq_num,
            event_type,
            object_type,
            object_owner,
            object_name,
            ddl_text
        )
        values (
            seq_ddl_post.nextval,
            l_event_type, 
            substrb(ora_dict_obj_type, 1, 20), 
            substrb(ora_dict_obj_owner, 1, 128),
            substrb(ora_dict_obj_name, 1, 261),
            l_ddl_text
        )
       $if $$ddl_capture_grant_details $then
        returning
            seq_num, 
            ddl_time
        into
            l_seq_num,
            l_ddl_time
       $end
        ;
       $if $$ddl_capture_grant_details $then
        if l_event_type in ('GRANT', 'REVOKE') then
            <<grant_or_revoke_details>>
            declare
                l_cnt_grantees    pls_integer;
                l_cnt_privileges  pls_integer;
                l_grantees        ora_name_list_t;
                l_privileges      ora_name_list_t;
                l_grant_option    &&def_post_grant_table..grant_option %type;
            begin
                if ora_with_grant_option then
                    l_grant_option := 'Y';
                end if;
                l_cnt_privileges := ora_privilege_list(l_privileges);
                if l_event_type = 'GRANT' then
                    l_cnt_grantees := ora_grantee(l_grantees);
                else
                    l_cnt_grantees := ora_revokee(l_grantees);
                end if;
                <<privs_loop>>
                for i in 1 .. l_cnt_privileges loop
                    <<grantees_loop>>
                    for j in 1 .. l_cnt_grantees loop
                        insert into &&def_post_grant_table (
                            seq_num,
                            ddl_time,
                            privilege,
                            grantee,
                            grant_option
                        )
                        values (
                            l_seq_num,
                            l_ddl_time,
                            substrb(l_privileges(i), 1, 261),
                            substrb(l_grantees(j), 1, 261),
                            l_grant_option
                        );
                    end loop grantees_loop;
                end loop privs_loop;
            end grant_or_revoke_details;
        end if;
       $end
   end capture_post;

end pkg_capture_ddl;
/
