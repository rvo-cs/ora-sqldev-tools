clear screen

define def_username_impl = "&1"

set verify off
set serveroutput on size unlimited format word_wrapped

declare
    gc_fetch_ddl_max constant number := 100;
    
    g_fetch_ddl_cnt number := 0;    /* Count of DDL statements printed in the 
                                       previous call to print_ddl_pieces */
    procedure print_nl;    

    procedure print_heading_comment(p_object_type in varchar2, p_filter_value in varchar2);
    procedure print_user_heading_comment (p_username in varchar2);

    procedure print_ts_quotas(p_username in varchar2);
    
    
    procedure print_ddl_pieces(
        p_object_type   in varchar2,
        p_filter_name   in varchar2,
        p_filter_value  in varchar2
    )
    is
        l_mh   number;      /* handle from dbms_metadata.open */
        l_th   number;      /* handle from dbms_metadata.add_transform */
        l_ddls ku$_ddls;
    begin
        l_mh := dbms_metadata.open(p_object_type);
        dbms_metadata.set_filter(l_mh, p_filter_name, p_filter_value);

        l_th := dbms_metadata.add_transform(l_mh, 'DDL');
        dbms_metadata.set_transform_param(l_th, 'SQLTERMINATOR', true);

        dbms_metadata.set_count(l_mh, gc_fetch_ddl_max);

        g_fetch_ddl_cnt := 0;
        
        <<ddl_fetch_loop>>
        loop
            l_ddls := dbms_metadata.fetch_ddl(l_mh);
            exit when l_ddls is null or l_ddls.count = 0;
            
            if g_fetch_ddl_cnt = 0 then
                print_heading_comment(p_object_type, p_filter_value);
            end if;
            
            for i in l_ddls.first .. l_ddls.last loop
                g_fetch_ddl_cnt := g_fetch_ddl_cnt + 1;
                dbms_output.put_line(rtrim(l_ddls(i).ddltext, chr(10) || chr(32)));
            end loop;
        end loop ddl_fetch_loop;
        
        dbms_metadata.close(l_mh);
    end print_ddl_pieces;
    
    
    procedure print_user_ddl (p_username in varchar2)
    is
    begin
        print_ddl_pieces('USER', 'NAME', p_username);

        print_nl;
        print_ddl_pieces('PROXY', 'GRANTEE', p_username);
        
        print_nl;
        print_ddl_pieces('RMGR_INITIAL_CONSUMER_GROUP', 'GRANTEE', p_username);
        
        print_nl;
        print_ddl_pieces('ROLE_GRANT', 'GRANTEE', p_username);
        
        print_nl;
        print_ddl_pieces('DEFAULT_ROLE', 'GRANTEE', p_username);

        print_nl;
        print_ddl_pieces('SYSTEM_GRANT', 'GRANTEE', p_username);

        print_nl;
        print_ddl_pieces('OBJECT_GRANT', 'GRANTEE', p_username);

        print_nl;
        /* print_ddl_pieces('TABLESPACE_QUOTA', 'GRANTEE', p_username); */
        print_ts_quotas(p_username);
    end print_user_ddl;
    

    procedure print_ts_quotas(p_username in varchar2)
    is
    begin
        g_fetch_ddl_cnt := 0;
        
        for c in (
            select
                'QUOTA '
                || case
                    when a.max_bytes = -1 then 'UNLIMITED'
                    else
                        to_char(
                            decode(
                                mod(a.max_bytes, power(2,30)), 0, a.max_bytes / power(2,30),
                                decode(
                                    mod(a.max_bytes, power(2,20)), 0, a.max_bytes / power(2,20),
                                    decode(
                                        mod(a.max_bytes, power(2,10)), 0, a.max_bytes / power(2,10),
                                        a.max_bytes
                                    )
                                )
                            ) 
                        ) 
                        || decode(
                               mod(a.max_bytes, power(2,30)), 0, 'G',
                               decode(
                                   mod(a.max_bytes, power(2,20)), 0, 'M',
                                   decode(mod(a.max_bytes, power(2,10)), 0, 'K')
                               )
                           )
                   end
                || ' ON TABLESPACE "' || a.tablespace_name || '"'  as ts_quota
            from
                dba_ts_quotas a,
                dba_tablespaces b
            where
                a.username = p_username
                and a.dropped = 'NO'
                and a.tablespace_name = b.tablespace_name
                and b.contents <> 'TEMPORARY'
        )
        loop
            if g_fetch_ddl_cnt = 0 then
                print_heading_comment('TABLESPACE_QUOTA', p_username);
            end if;
            g_fetch_ddl_cnt := g_fetch_ddl_cnt + 1;
            dbms_output.put_line(
                'ALTER USER '
                || dbms_assert.enquote_name(p_username, false)
                || ' ' 
                || c.ts_quota
                || ';'
            );
        end loop;
    end print_ts_quotas;


    procedure print_nl
    is begin
        if g_fetch_ddl_cnt > 0 then
            dbms_output.new_line;
        end if;
    end print_nl;


    procedure print_heading_comment(
        p_object_type   in varchar2,
        p_filter_value  in varchar2
    )
    is
        l_head_cmt varchar2(100);
    begin
        l_head_cmt := 
            case p_object_type
                when 'PROXY'            then 'Proxy authentication'
                when 'ROLE_GRANT'       then 'Role GRANTs'
                when 'DEFAULT_ROLE'     then 'Default role'
                when 'SYSTEM_GRANT'     then 'System privileges'
                when 'OBJECT_GRANT'     then 'Object privileges'
                when 'TABLESPACE_QUOTA' then 'Tablespace quotas'
                when 'RMGR_INITIAL_CONSUMER_GROUP'  
                                        then 'Initial resource consumer group'
                else null
            end;
        if l_head_cmt is not null then
            dbms_output.put_line(
                case 
                    when p_object_type in ( 'ROLE_GRANT', 'DEFAULT_ROLE',
                                            'RMGR_INITIAL_CONSUMER_GROUP' ) 
                    then ' '
                end
                || '/* ' || l_head_cmt || ' */'
            );
        elsif p_object_type = 'USER' then
            print_user_heading_comment(p_filter_value);
        end if;
    end print_heading_comment;


    procedure print_user_heading_comment (p_username in varchar2)
    is
        l_date_created date;
    begin
        select
            a.created into l_date_created
        from
            dba_users a
        where
            a.username = p_username;
            
        dbms_output.put_line('/*');
        dbms_output.put_line('   Database: ' || sys_context('USERENV', 'DB_NAME'));
        dbms_output.put_line('   Username: ' || dbms_assert.enquote_name(p_username, false));
        dbms_output.put_line('   Created : ' || to_char(l_date_created, 'YYYY-MM-DD HH24:MI:SS'));
        dbms_output.put_line(' */');
        dbms_output.new_line;
    end print_user_heading_comment;
    
begin
    print_user_ddl('&&def_username_impl');
end;
/

undefine def_username_impl

