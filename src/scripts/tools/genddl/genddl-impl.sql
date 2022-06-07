define def_object_type = "&&1"
define def_schema_name = "&&2"
define def_object_name = "&&3"

set verify off
set linesize 500
set trimout on
set serveroutput on size unlimited format word_wrapped

declare
    gc_fetch_ddl_max  constant number := 100;

    gc_newln          constant varchar2(1) := chr(10);
    gc_blank_or_nl    constant varchar2(2) := chr(32) || chr(10);
    gc_sql_terminator constant varchar2(1) := ';';
    
    g_fetch_ddl_cnt number := 0;    /* Count of DDL statements printed in the 
                                       previous call to print_ddl_pieces */
    
    g_pending_newln boolean := false;   /* Add a newln before the next DDL statement? */

    gc_schema_name constant user_users.username      %type := '&&def_schema_name';
    gc_object_type constant user_objects.object_type %type := '&&def_object_type';
    gc_object_name constant user_objects.object_name %type := '&&def_object_name';

    gc_primary_key_as_alter         constant boolean := &&def_constraint_pk_as_alter;
    gc_unique_key_as_alter          constant boolean := &&def_constraint_unique_as_alter;
    gc_check_constraints_as_alter   constant boolean := &&def_constraint_check_as_alter;
    gc_foreign_key_as_alter         constant boolean := &&def_cnstraint_foreign_as_alter;
    gc_not_null_as_alter            constant boolean := &&def_cnstraint_notnull_as_alter;
    gc_print_private_synonyms       constant boolean := &&def_print_private_synonyms;
    gc_print_public_synonyms        constant boolean := &&def_print_public_synonyms;
    gc_strip_object_schema          constant boolean := &&def_strip_object_schema;
    gc_strip_tablespace_clause      constant boolean := &&def_strip_tablespace_clause;
    gc_strip_segment_attrs          constant boolean := &&def_strip_segment_attrs;
    gc_sort_table_grants            constant boolean := &&def_sort_table_grants;

    procedure create_table_sxml_xslt (p_clob in out nocopy clob);
    procedure create_index_sxml_xslt (p_clob in out nocopy clob, p_object_owner in varchar2);
    procedure create_synonym_sxml_xslt (p_clob in out nocopy clob, p_object_owner in varchar2);
    procedure create_constraint_xml_xslt (p_clob in out nocopy clob);

    procedure print_dependent_indexes (p_table_owner in varchar2, p_table_name in varchar2);
    procedure print_dependent_synonyms (p_table_owner in varchar2, p_table_name in varchar2);
    procedure print_dependent_constraints (p_table_owner in varchar2, p_table_name in varchar2,
                p_constraint_type in varchar2);
    
    procedure print_nl;
    procedure print_clob (p_clob in clob);
    procedure print_vc2 (p_vc2 in varchar2);

    function xlst_transform_param (p_param_name in varchar2, p_bool_value in boolean)
    return varchar2;

    procedure append_xsl_variable (p_clob in out nocopy clob,
            p_variable_name in varchar2, p_variable_value in varchar2);

    function pp_comment (p_clob in clob) return clob;

    
    procedure print_table_main_ddl (
        p_schema_name in varchar2,
        p_table_name  in varchar2
    )
    is
        l_mh        number;
        l_th        number;
        l_sxml      sys.xmltype;
        l_xslt      sys.xmltype;
        l_xslt_text clob;
        l_ddl       clob;
    begin
        /* 
           Extract metadata of the target table as SXML 
        */
        l_mh := dbms_metadata.open('TABLE');
        dbms_metadata.set_filter(l_mh, 'SCHEMA', p_schema_name);
        dbms_metadata.set_filter(l_mh, 'NAME', p_table_name);

        l_th := dbms_metadata.add_transform(l_mh, 'SXML');
        l_sxml := dbms_metadata.fetch_xml(l_mh);
        dbms_metadata.close(l_mh);
        
        /* 
           Remove parts, in the returned SXML, for dependent objects 
           (e.g. constraints) which will be dealt with later separately
           as ALTER TABLE statements (remark: this also removes SCHEMA)
         */
        create_table_sxml_xslt(l_xslt_text);
        l_xslt := xmltype(l_xslt_text);
        l_sxml := l_sxml.transform(
            xsl       => l_xslt,
            parammap  => xlst_transform_param('remove-object-schema' , gc_strip_object_schema)
                    || xlst_transform_param('primary-key-as-alter'   , gc_primary_key_as_alter)
                    || xlst_transform_param('unique-key-as-alter'    , gc_unique_key_as_alter)
                    || xlst_transform_param('check-constraints-as-alter', gc_check_constraints_as_alter)
                    || xlst_transform_param('foreign-key-as-alter'   , gc_foreign_key_as_alter)
                    || xlst_transform_param('not-null-as-alter'      , gc_not_null_as_alter)
                    || xlst_transform_param('strip-tabspc-clause'    , gc_strip_tablespace_clause)
        );
        dbms_lob.freetemporary(l_xslt_text);

        /*
           Convert from SXML to DDL
         */
        dbms_lob.createtemporary(l_ddl, true);

        l_mh := dbms_metadata.openw('TABLE');

        l_th := dbms_metadata.add_transform(l_mh, 'SXMLDDL');
        dbms_metadata.set_transform_param(l_th, 'SEGMENT_ATTRIBUTES' , not(gc_strip_segment_attrs));  
        dbms_metadata.set_transform_param(l_th, 'STORAGE'            , false);
        dbms_metadata.set_transform_param(l_th, 'TABLESPACE', not(gc_strip_tablespace_clause));  
        /* 
           Remark: the SIZE_BYTE_KEYWORD transform param is not supported in
           the SXMLDDL transform, which is a pity: the results will only be
           valid if NLS_LENGTH_SEMANTIC is set to BYTE :-(
         */

        dbms_metadata.convert(l_mh, l_sxml, l_ddl);
        dbms_metadata.close(l_mh);
    
        dbms_lob.append(l_ddl, ' ' || gc_sql_terminator);
        print_clob(l_ddl);
        dbms_lob.freetemporary(l_ddl);
        
        g_fetch_ddl_cnt := g_fetch_ddl_cnt + 1;
    end print_table_main_ddl;
    

    procedure print_index_ddl (
        p_index_owner   in varchar2,
        p_index_name    in varchar2,
        p_object_owner  in varchar2
    )
    is
        l_mh        number;
        l_th        number;
        l_sxml      sys.xmltype;
        l_xslt      sys.xmltype;
        l_xslt_text clob;
        l_ddl       clob;
    begin
        /*
           Extract index metadata as SXML
         */
        l_mh := dbms_metadata.open('INDEX');
        dbms_metadata.set_filter(l_mh, 'SCHEMA', p_index_owner);
        dbms_metadata.set_filter(l_mh, 'NAME', p_index_name);

        l_th := dbms_metadata.add_transform(l_mh, 'SXML');
        l_sxml := dbms_metadata.fetch_xml(l_mh);
        dbms_metadata.close(l_mh);
    
        /* 
           Transform using XSLT: remove object's owner (if required), 
           storage attributes, list of partitions (if locality is local)
         */
        create_index_sxml_xslt(l_xslt_text, p_object_owner);
        l_xslt := xmltype(l_xslt_text);
        l_sxml := l_sxml.transform(
            xsl       => l_xslt,
            parammap  => xlst_transform_param('remove-object-schema' , gc_strip_object_schema)
        );
        dbms_lob.freetemporary(l_xslt_text);

        /*
           Convert from SXML to DDL
         */
        dbms_lob.createtemporary(l_ddl, true);
        
        l_mh := dbms_metadata.openw('INDEX');
        l_th := dbms_metadata.add_transform(l_mh, 'SXMLDDL');
        dbms_metadata.set_transform_param(l_th, 'TABLESPACE', not(gc_strip_tablespace_clause));  
        dbms_metadata.set_transform_param(l_th, 'SEGMENT_ATTRIBUTES', not(gc_strip_segment_attrs));
        dbms_metadata.convert(l_mh, l_sxml, l_ddl);
        dbms_metadata.close(l_mh);
       
        dbms_lob.append(l_ddl, gc_sql_terminator);
        print_clob(ltrim(regexp_replace(l_ddl, '(\s|\n)*\(\);$', ' ;')));    
                         /* ^^^--- must remove trailing "(" and ")" left over 
                                   from the list of partitions of local indexes */
        dbms_lob.freetemporary(l_ddl);

        g_fetch_ddl_cnt := g_fetch_ddl_cnt + 1;
    end print_index_ddl;


    procedure print_synonym_ddl (
        p_synonym_owner  in varchar2,
        p_synonym_name   in varchar2,
        p_object_owner   in varchar2
    )
    is
        l_mh        number;
        l_th        number;
        l_sxml      sys.xmltype;
        l_xslt      sys.xmltype;
        l_xslt_text clob;
        l_ddl       clob;
    begin
        /*
           Extract synonym metadata as SXML
         */
        l_mh := dbms_metadata.open('SYNONYM');
        dbms_metadata.set_filter(l_mh, 'SCHEMA', p_synonym_owner);
        dbms_metadata.set_filter(l_mh, 'NAME'  , p_synonym_name);
        
        l_th := dbms_metadata.add_transform(l_mh, 'SXML');
        l_sxml := dbms_metadata.fetch_xml(l_mh);
        dbms_metadata.close(l_mh);
        
        /* 
           Transform using XSLT: remove the object's schema
         */
        create_synonym_sxml_xslt(l_xslt_text, p_object_owner);
        l_xslt := xmltype(l_xslt_text);
        l_sxml := l_sxml.transform(
            xsl       => l_xslt,
            parammap  => xlst_transform_param('remove-object-schema' , gc_strip_object_schema)
        );
        dbms_lob.freetemporary(l_xslt_text);

        /*
           Convert from SXML to DDL
         */
        dbms_lob.createtemporary(l_ddl, true);
        
        l_mh := dbms_metadata.openw('SYNONYM');
        l_th := dbms_metadata.add_transform(l_mh, 'SXMLDDL');
        dbms_metadata.convert(l_mh, l_sxml, l_ddl);
        dbms_metadata.close(l_mh);
        
        dbms_lob.append(l_ddl, gc_sql_terminator);
        print_clob(ltrim(l_ddl));
        dbms_lob.freetemporary(l_ddl);

        g_fetch_ddl_cnt := g_fetch_ddl_cnt + 1;
    end print_synonym_ddl;


    procedure print_constraint_ddl (
        p_owner            in varchar2,
        p_constraint_name  in varchar2,
        p_object_type      in varchar2 := 'CONSTRAINT'
    )
    is
        l_mh        number;
        l_th        number;
        l_xml       sys.xmltype;
        l_xslt      sys.xmltype;
        l_xslt_text clob;
        l_ddl       clob;
    begin
        /*
           Extract constraint metadata as XML
           Note: SXML is _not_ avaiable for constraints.
        */
        l_mh := dbms_metadata.open(p_object_type);
        dbms_metadata.set_filter(l_mh, 'SCHEMA', p_owner);
        dbms_metadata.set_filter(l_mh, 'NAME'  , p_constraint_name);

        l_xml := dbms_metadata.fetch_xml(l_mh);
        dbms_metadata.close(l_mh);
        
        /* 
           Transform using XSLT: remove the owner name if required,
           remove details of the underlying index, etc.
         */
        create_constraint_xml_xslt(l_xslt_text);
        l_xslt := xmltype(l_xslt_text);
        l_xml := l_xml.transform(
            xsl       => l_xslt,
            parammap  => xlst_transform_param('remove-object-schema' , gc_strip_object_schema)
        );
        dbms_lob.freetemporary(l_xslt_text);
            
        /*
           Convert from XML to DDL
         */
        dbms_lob.createtemporary(l_ddl, true);
        
        l_mh := dbms_metadata.openw(p_object_type);
        l_th := dbms_metadata.add_transform(l_mh, 'DDL');
        dbms_metadata.convert(l_mh, l_xml, l_ddl);
        dbms_metadata.close(l_mh);

        print_clob(ltrim(rtrim(l_ddl, gc_blank_or_nl), gc_blank_or_nl) || gc_sql_terminator);
        dbms_lob.freetemporary(l_ddl);

        g_fetch_ddl_cnt := g_fetch_ddl_cnt + 1;
    end print_constraint_ddl;
    

    procedure print_ddl_pieces(
        p_object_type       in  varchar2,
        p_schema_name       in  varchar2,
        p_object_name       in  varchar2,
        p_is_dependent      in  boolean     default false,
        p_base_object_type  in  varchar2    default null,
        p_custom_filter     in  varchar2    default null
    )
    is
        l_mh   number;      /* handle from dbms_metadata.open */
        l_rh   number;      /* handle from dbms_metadata.add_transform */
        l_th   number;      /* handle from dbms_metadata.add_transform */
        l_ddls ku$_ddls;
    begin
        l_mh := dbms_metadata.open(p_object_type);
    
        if p_is_dependent then
            dbms_metadata.set_filter(l_mh, 'BASE_OBJECT_SCHEMA', p_schema_name);
            dbms_metadata.set_filter(l_mh, 'BASE_OBJECT_TYPE',   p_base_object_type);
            dbms_metadata.set_filter(l_mh, 'BASE_OBJECT_NAME',   p_object_name);
        else
            dbms_metadata.set_filter(l_mh, 'SCHEMA', p_schema_name);
            dbms_metadata.set_filter(l_mh, 'NAME',   p_object_name);
        end if;
        
        if p_custom_filter is not null then
            dbms_metadata.set_filter(l_mh, 'CUSTOM_FILTER', p_custom_filter);
        end if;

        if gc_strip_object_schema 
            and p_object_type not in ('COMMENT', 'SYNONYM') 
        then
            l_rh := dbms_metadata.add_transform(l_mh, 'MODIFY');
            dbms_metadata.set_remap_param(l_rh, 'REMAP_SCHEMA', p_schema_name, null);
        end if;

        l_th := dbms_metadata.add_transform(l_mh, 'DDL');
        dbms_metadata.set_transform_param(l_th, 'PRETTY', true);
        dbms_metadata.set_transform_param(l_th, 'SQLTERMINATOR', true);

        if p_object_type = 'TABLE' then
            dbms_metadata.set_transform_param(l_th, 'CONSTRAINTS', true);
            dbms_metadata.set_transform_param(l_th, 'REF_CONSTRAINTS', false);
            dbms_metadata.set_transform_param(l_th, 'CONSTRAINTS_AS_ALTER', true);
        end if;
        
        if p_object_type in ('TABLE', 'INDEX') then
            dbms_metadata.set_transform_param(l_th, 'SEGMENT_ATTRIBUTES', not(gc_strip_segment_attrs));
            dbms_metadata.set_transform_param(l_th, 'STORAGE', false);
            dbms_metadata.set_transform_param(l_th, 'TABLESPACE', not(gc_strip_tablespace_clause));

        elsif p_object_type in ('CONSTRAINT') then
            dbms_metadata.set_transform_param(l_th, 'SEGMENT_ATTRIBUTES', false);
        end if;

        dbms_metadata.set_count(l_mh, gc_fetch_ddl_max);

        g_fetch_ddl_cnt := 0;
        
        <<ddl_fetch_loop>>
        loop
            l_ddls := dbms_metadata.fetch_ddl(l_mh);
            exit when l_ddls is null or l_ddls.count = 0;
            
            for i in l_ddls.first .. l_ddls.last loop
                g_fetch_ddl_cnt := g_fetch_ddl_cnt + 1;
                print_clob(
                    case p_object_type
                        when 'COMMENT' then pp_comment(l_ddls(i).ddltext) 
                        else l_ddls(i).ddltext 
                    end
                );
            end loop;
        end loop ddl_fetch_loop;
        
        dbms_metadata.close(l_mh);
    end print_ddl_pieces;
    

    procedure print_object_grants(
        p_schema_name       in  varchar2,
        p_object_name       in  varchar2,
        p_base_object_type  in  varchar2    default null
    )
    is
        l_mh   number;      /* handle from dbms_metadata.open */
        l_rh   number;      /* handle from dbms_metadata.add_transform */
        l_th   number;      /* handle from dbms_metadata.add_transform */
        l_ddls ku$_ddls;
        
        l_tab_grant sys.odcivarchar2list := sys.odcivarchar2list();
    begin
        l_mh := dbms_metadata.open('OBJECT_GRANT');
    
        dbms_metadata.set_filter(l_mh, 'BASE_OBJECT_SCHEMA', p_schema_name);
        dbms_metadata.set_filter(l_mh, 'BASE_OBJECT_TYPE',   p_base_object_type);
        dbms_metadata.set_filter(l_mh, 'BASE_OBJECT_NAME',   p_object_name);
        
        if gc_strip_object_schema then
            l_rh := dbms_metadata.add_transform(l_mh, 'MODIFY');
            dbms_metadata.set_remap_param(l_rh, 'REMAP_SCHEMA', p_schema_name, null);
        end if;

        l_th := dbms_metadata.add_transform(l_mh, 'DDL');
        dbms_metadata.set_transform_param(l_th, 'PRETTY', true);
        dbms_metadata.set_transform_param(l_th, 'SQLTERMINATOR', true);

        dbms_metadata.set_count(l_mh, gc_fetch_ddl_max);

        g_fetch_ddl_cnt := 0;
        
        <<ddl_fetch_loop>>
        loop
            l_ddls := dbms_metadata.fetch_ddl(l_mh);
            exit when l_ddls is null or l_ddls.count = 0;

            <<inner_loop>>
            for i in l_ddls.first .. l_ddls.last loop
                g_fetch_ddl_cnt := g_fetch_ddl_cnt + 1;
                if gc_sort_table_grants then
                    l_tab_grant.extend;
                    l_tab_grant(l_tab_grant.last) := to_char(l_ddls(i).ddltext);
                    /*
                       Remark: we make 2 (sensible) assumptions here:
                        (i) There will be no more than 32K GRANTs on the same object
                        And: (ii) Each GRANT statement will fit in a varchar2(4000 byte)
                        Failing that, an exception would be raised.
                     */
                else
                    print_clob(rtrim(l_ddls(i).ddltext, gc_blank_or_nl) || gc_newln);
                end if;
                
            end loop inner_loop;
        end loop ddl_fetch_loop;
        
        dbms_metadata.close(l_mh);
        
        if gc_sort_table_grants then
            declare
                /*
                   Best effort to sort the GRANT statements so that they appear
                   in a predictable manner, not one that changes from one database
                   to the next.
                 */
                cursor c_sorted_grants is
                    with grant_pieces_1 as (
                        select 
                            coalesce(
                                regexp_substr(a.column_value, 
                                        'GRANT\s(.*)\sON\s(.*)\sTO\s(.*)\sWITH\s(.*)?;\s*$',
                                        1, 1, null, 1),
                                regexp_substr(a.column_value,
                                        'GRANT\s(.*)\sON\s(.*)\sTO\s(.*);\s*$',
                                        1, 1, null, 1)
                            ) as privilege,
                            coalesce(
                                regexp_substr(a.column_value,
                                        'GRANT\s(.*)\sON\s(.*)\sTO\s(.*)\sWITH\s(.*)?;\s*$',
                                        1, 1, null, 2),
                                regexp_substr(a.column_value,
                                        'GRANT\s(.*)\sON\s(.*)\sTO\s(.*);\s*$',
                                        1, 1, null, 2)
                            ) as object_name,
                            coalesce(
                                regexp_substr(a.column_value,
                                        'GRANT\s(.*)\sON\s(.*)\sTO\s(.*)\sWITH\s(.*)?;\s*$',
                                        1, 1, null, 3),
                                regexp_substr(a.column_value,
                                        'GRANT\s(.*)\sON\s(.*)\sTO\s(.*);\s*$',
                                        1, 1, null, 3)
                            ) as grantee,
                            regexp_substr(a.column_value,
                                    'GRANT\s(.*)\sON\s(.*)\sTO\s(.*)\sWITH\s(.*)?;\s*$',
                                    1, 1, null, 4)
                              as with_option,
                            a.column_value as stmt
                        from 
                            table(l_tab_grant) a
                    ),
                    grant_pieces_2 as (
                        select
                            a.object_name,
                            a.grantee,
                            a.privilege,
                            regexp_substr(a.privilege, '^(READ|SELECT|INSERT|UPDATE|DELETE)',
                                    1, 1, null, 1)  as crud_priv,
                            regexp_substr(a.privilege, '\( ([^)]+) \)$',
                                    1, 1, 'x', 1)   as tab_col,
                            a.with_option,
                            a.stmt
                        from
                            grant_pieces_1 a
                    )
                    select
                        a.stmt
                    from
                        grant_pieces_2 a
                    order by
                        a.object_name, 
                        a.grantee, 
                        a.tab_col  nulls first,
                        decode(a.crud_priv, 'READ', 1, 'SELECT', 2, 'INSERT', 3,
                                'UPDATE', 4, 'DELETE', 5, 100),
                        a.privilege, 
                        a.with_option  nulls last;
                
                l_stmt varchar2(4000 byte);
            begin
                open c_sorted_grants;
                loop
                    fetch c_sorted_grants into l_stmt;
                    exit when c_sorted_grants%notfound;
                    print_vc2(rtrim(l_stmt, gc_blank_or_nl) || gc_newln);
                end loop;
                close c_sorted_grants;
            end;
        end if;
    end print_object_grants;
    
   
    procedure create_table_sxml_xslt (p_clob in out nocopy clob)
    is
    begin
        dbms_lob.createtemporary(p_clob, true);
        dbms_lob.append(
            p_clob,
            q'{ <?xml version="1.0"?>
                <xsl:stylesheet version="1.0"
                        xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                        xmlns:ora="http://xmlns.oracle.com/ku"
                        xmlns="http://xmlns.oracle.com/ku"
                        exclude-result-prefixes="ora">
                    
                    <xsl:param name="remove-object-schema"        select="0" />
                    <xsl:param name="primary-key-as-alter"        select="0" />
                    <xsl:param name="unique-key-as-alter"         select="0" />
                    <xsl:param name="check-constraints-as-alter"  select="0" />
                    <xsl:param name="foreign-key-as-alter"        select="0" />
                    <xsl:param name="not-null-as-alter"           select="0" />
                    <xsl:param name="strip-tabspc-clause"         select="0" />
    
                    <xsl:output omit-xml-declaration="yes"/>

                    <xsl:template match="node()|@*" priority="0">
                        <xsl:copy>
                            <xsl:apply-templates/>
                        </xsl:copy>
                    </xsl:template>

                    <xsl:template match="ora:TABLE/ora:SCHEMA" priority="2">
                        <xsl:if test="not($remove-object-schema)">
                            <xsl:copy>
                                <xsl:apply-templates/>
                            </xsl:copy>
                        </xsl:if>
                    </xsl:template>

                    <xsl:template match="ora:PRIMARY_KEY_CONSTRAINT_LIST" priority="1">
                        <xsl:if test="not($primary-key-as-alter)">
                            <xsl:copy>
                                <xsl:apply-templates/>
                            </xsl:copy>
                        </xsl:if>
                    </xsl:template>
                    
                    <xsl:template match="ora:UNIQUE_KEY_CONSTRAINT_LIST" priority="1">
                        <xsl:if test="not($unique-key-as-alter)">
                            <xsl:copy>
                                <xsl:apply-templates/>
                            </xsl:copy>
                        </xsl:if>
                    </xsl:template>
                    
                    <xsl:template match="ora:CHECK_CONSTRAINT_LIST" priority="1">  
                        <xsl:if test="not($check-constraints-as-alter)">
                            <xsl:copy>
                                <xsl:apply-templates/>
                            </xsl:copy>
                        </xsl:if>
                    </xsl:template>
    
                    <xsl:template match="ora:FOREIGN_KEY_CONSTRAINT_LIST" priority="1">  
                        <xsl:if test="not($foreign-key-as-alter)">
                            <xsl:copy>
                                <xsl:apply-templates/>
                            </xsl:copy>
                        </xsl:if>
                    </xsl:template>
    
                    <xsl:template match="ora:COL_LIST_ITEM/ora:NOT_NULL" priority="2">  
                        <xsl:if test="not($not-null-as-alter)">
                            <xsl:copy>
                                <xsl:apply-templates/>
                            </xsl:copy>
                        </xsl:if>
                    </xsl:template>

                    <xsl:template match="ora:TABLESPACE" priority="1">  
                        <xsl:if test="not($strip-tabspc-clause)">
                            <xsl:copy>
                                <xsl:apply-templates/>
                            </xsl:copy>
                        </xsl:if>
                    </xsl:template>
    
                </xsl:stylesheet>
              }'
        );
    end create_table_sxml_xslt;
    

    procedure create_index_sxml_xslt (
        p_clob          in out nocopy  clob, 
        p_object_owner  in  varchar2
    )
    is
    begin
        dbms_lob.createtemporary(p_clob, true);
        dbms_lob.append(
            p_clob,
            q'{ <?xml version="1.0"?>
                <xsl:stylesheet version="1.0"
                        xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                        xmlns:ora="http://xmlns.oracle.com/ku"
                        xmlns="http://xmlns.oracle.com/ku"
                        exclude-result-prefixes="ora">

                    <xsl:param name="remove-object-schema" select="0" />
             }'
        );

        append_xsl_variable(p_clob, 'object-owner', p_object_owner);
        
        dbms_lob.append(
            p_clob,
            q'{ <xsl:output omit-xml-declaration="yes"/>
                
                <xsl:template match="node()|@*" priority="0">
                    <xsl:copy>
                        <xsl:apply-templates/>
                    </xsl:copy>
                </xsl:template>
                
                <xsl:template match="ora:LOCAL_PARTITIONING/ora:PARTITION_LIST" priority="2" />
                <xsl:template match="ora:INDEX_ATTRIBUTES/ora:STORAGE" priority="2" />
            
                <xsl:template match="/ora:INDEX/ora:SCHEMA" priority="2">
                    <xsl:variable name="index-owner" select="." />
                    <xsl:if test="not($remove-object-schema) or $index-owner != $object-owner">
                        <xsl:copy>
                            <xsl:apply-templates/>
                        </xsl:copy>
                    </xsl:if>
                </xsl:template>                 

                <xsl:template match="ora:TABLE_INDEX/ora:ON_TABLE/ora:SCHEMA" priority="3">
                    <xsl:variable name="table-owner" select="." />
                    <xsl:if test="not($remove-object-schema) or $table-owner != $object-owner">
                        <xsl:copy>
                            <xsl:apply-templates/>
                        </xsl:copy>
                    </xsl:if>
                </xsl:template>                    

            </xsl:stylesheet>}'
        );
    end create_index_sxml_xslt;


    procedure create_synonym_sxml_xslt (
        p_clob          in out nocopy  clob,
        p_object_owner  in  varchar2
    )
    is
    begin
        dbms_lob.createtemporary(p_clob, true);
        dbms_lob.append(
            p_clob,
            q'{ <?xml version="1.0"?>
                <xsl:stylesheet version="1.0"
                        xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                        xmlns:ora="http://xmlns.oracle.com/ku"
                        xmlns="http://xmlns.oracle.com/ku"
                        exclude-result-prefixes="ora">

                    <xsl:param name="remove-object-schema" select="0" />
             }'
        );
        
        append_xsl_variable(p_clob, 'object-owner', p_object_owner);
        
        dbms_lob.append(
            p_clob,
            q'{ <xsl:output omit-xml-declaration="yes"/>
                
                <xsl:template match="node()|@*" priority="0">
                    <xsl:copy>
                        <xsl:apply-templates/>
                    </xsl:copy>
                </xsl:template>
                
                <xsl:template match="ora:SCHEMA" priority="1">
                    <xsl:variable name="synonym-schema" select="." />
                    <xsl:if test="not($remove-object-schema)
                                  or $object-owner != $synonym-schema">
                        <xsl:copy>
                            <xsl:apply-templates/>
                        </xsl:copy>
                    </xsl:if>
                </xsl:template>

                <xsl:template match="ora:OBJECT_SCHEMA" priority="1">
                    <xsl:variable name="object-schema" select="." />
                    <xsl:if test="not($remove-object-schema)
                                  or $object-owner != $object-schema">
                        <xsl:copy>
                            <xsl:apply-templates/>
                        </xsl:copy>
                    </xsl:if>
                </xsl:template>
            </xsl:stylesheet>}'
        );
    end create_synonym_sxml_xslt;


    procedure create_constraint_xml_xslt (p_clob in out nocopy clob)
    is
    begin
        dbms_lob.createtemporary(p_clob, true);
        dbms_lob.append(
            p_clob,
            q'{<?xml version="1.0"?>
            <xsl:stylesheet version="1.0"
                     xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                     xmlns:ora="http://xmlns.oracle.com/ku"
                     xmlns="http://xmlns.oracle.com/ku"
                     exclude-result-prefixes="ora">

                <xsl:param name="remove-object-schema" select="0" />

                <xsl:variable name="object-owner" 
                        select="/ROWSET/ROW/CONSTRAINT_T/OWNER_NAME 
                                | /ROWSET/ROW/REF_CONSTRAINT_T/OWNER_NAME" />                    
                    
                <xsl:output omit-xml-declaration="yes"/>
                
                <xsl:template match="node()|@*" priority="0">
                    <xsl:copy>
                        <xsl:apply-templates/>
                    </xsl:copy>
                </xsl:template>

                <xsl:template match="CONSTRAINT_T/BASE_OBJ/OWNER_NAME" priority="2">
                    <xsl:variable name="base-object-owner" select="." />
                    <xsl:if test="not($remove-object-schema)
                                    or $base-object-owner != $object-owner">
                        <xsl:copy>
                            <xsl:apply-templates/>
                        </xsl:copy>
                    </xsl:if>
                </xsl:template>
                
                <xsl:template match="REF_CONSTRAINT_T/BASE_OBJ/OWNER_NAME" priority="2">
                    <xsl:variable name="base-object-owner" select="." />
                    <xsl:if test="not($remove-object-schema)
                                    or $base-object-owner != $object-owner">
                        <xsl:copy>
                            <xsl:apply-templates/>
                        </xsl:copy>
                    </xsl:if>
                </xsl:template>

                <xsl:template match="REF_CONSTRAINT_T/*/SCHEMA_OBJ/OWNER_NAME" priority="2">
                    <xsl:variable name="target-object-owner" select="." />
                    <xsl:if test="not($remove-object-schema)
                                    or $target-object-owner != $object-owner">
                        <xsl:copy>
                            <xsl:apply-templates/>
                        </xsl:copy>
                    </xsl:if>
                </xsl:template>
                
                <xsl:template match="IND/PCT_FREE" priority="1" />
                <xsl:template match="IND/INITRANS" priority="1" />
                <xsl:template match="IND/MAXTRANS" priority="1" />
                <xsl:template match="IND/STORAGE" priority="1" />
                <xsl:template match="IND/DEFERRED_STG" priority="1" />
                <xsl:template match="IND/PART_OBJ" priority="1" />
                <xsl:template match="IND/FLAGS" priority="1" />
                <xsl:template match="IND/TS_NAME" priority="1" />
            </xsl:stylesheet>}'
        );
    end create_constraint_xml_xslt;

    
    procedure print_table_ddl (p_schema_name in varchar2, p_table_name in varchar2)
    is
    begin
        print_table_main_ddl(p_schema_name, p_table_name);
        print_nl;

        print_ddl_pieces('COMMENT', p_schema_name, p_table_name, 
                p_is_dependent => true, p_base_object_type => 'TABLE');
        print_nl;
        
        print_dependent_indexes(p_schema_name, p_table_name);
        
        /* 
            Remark: for custom filters on constraint type, 
            see values of CDEF$.TYPE# in ?/rdbms/dcore.bsq
        */

        /* NOT NULL constraints */
        if gc_not_null_as_alter then
            print_ddl_pieces('CONSTRAINT', p_schema_name, p_table_name, 
                    p_is_dependent => true, p_base_object_type => 'TABLE',
                    p_custom_filter => 'TYPE_NUM = 7');
            print_nl;
        end if;
        
        /* PRIMARY KEY constraints */
        if gc_primary_key_as_alter then
            print_dependent_constraints(p_schema_name, p_table_name, p_constraint_type => 'P');
        end if;

        /* UNIQUE KEY constraints */
        if gc_unique_key_as_alter then
            print_dependent_constraints(p_schema_name, p_table_name, p_constraint_type => 'U');
        end if;

        /* CHECK constraints */
        if gc_check_constraints_as_alter then
            print_dependent_constraints(p_schema_name, p_table_name, p_constraint_type => 'C');
        end if;

        if gc_foreign_key_as_alter then
            print_dependent_constraints(p_schema_name, p_table_name, p_constraint_type => 'R');
        end if;

        print_object_grants(p_schema_name, p_table_name, 'TABLE');
        print_nl;

        print_dependent_synonyms(p_schema_name, p_table_name);
    end print_table_ddl;
    

    procedure print_view_ddl (p_schema_name in varchar2, p_view_name in varchar2)
    is
    begin
        print_ddl_pieces('VIEW', p_schema_name, p_view_name);
        print_nl;

        print_object_grants(p_schema_name, p_view_name, 'VIEW');
        print_nl;

        print_dependent_synonyms(p_schema_name, p_view_name);
    end print_view_ddl;


    procedure print_other_ddl (
        p_object_type in varchar2,
        p_schema_name in varchar2,
        p_object_name in varchar2
    )
    is
    begin
        print_ddl_pieces(p_object_type, p_schema_name, p_object_name);
        print_nl;
        
        if p_object_type in ('PROCEDURE', 'FUNCTION', 'PACKAGE', 'TYPE') then
            print_object_grants(p_schema_name, p_object_name, p_object_type);
            print_nl;

            print_dependent_synonyms(p_schema_name, p_object_name);
        end if;
    end print_other_ddl;


    procedure print_dependent_indexes (
        p_table_owner  in varchar2,
        p_table_name   in varchar2
    )
    is
    begin
        for c in (
            select
                a.owner,
                a.index_name,
                (select count(*) from dba_constraints b
                  where b.constraint_type = 'P' 
                    and b.index_owner = a.owner and b.index_name = a.index_name) as cnt_p
            from
                dba_indexes a
            where
                a.table_owner = p_table_owner
                and a.table_name = p_table_name
            order by
                cnt_p desc,
                a.owner, a.index_name
        )
        loop
            print_index_ddl(
                p_index_owner  => c.owner, 
                p_index_name   => c.index_name,
                p_object_owner => p_table_owner
            );
            print_nl;
        end loop;
    end print_dependent_indexes;


    procedure print_dependent_synonyms (
        p_table_owner  in varchar2, 
        p_table_name   in varchar2
    )
    is
    begin
        for c in (
            select
                a.owner,
                a.synonym_name,
                a.table_owner,
                a.table_name
            from
                dba_synonyms a
            where
                a.table_owner = p_table_owner
                and a.table_name = p_table_name
            order by
                decode(a.owner, 'PUBLIC', 0, 1) asc,
                a.owner, synonym_name
        )
        loop
            if (c.owner = 'PUBLIC' and gc_print_public_synonyms)
                or (c.owner <> 'PUBLIC' and gc_print_private_synonyms)
            then
                print_synonym_ddl(
                    p_synonym_owner => c.owner, 
                    p_synonym_name  => c.synonym_name,
                    p_object_owner  => p_table_owner
                );
                print_nl;
            end if;
        end loop;
    end print_dependent_synonyms;


    procedure print_dependent_constraints (
        p_table_owner       in varchar2, 
        p_table_name        in varchar2,
        p_constraint_type   in varchar2
    )
    is
        cursor c_constraint is
            select
                a.constraint_name
            from
                /*
                   Note: dba_constraints does _not_ expose cdef$.type#, which we
                   need to tell apart "true" check constraints (cdef$.type# = 1)
                   from plain NOT NULL constraints (cdef.$type# = 7) which must
                   not appear here because they are dealt with elsewhere.
                */
                dba_constraints a,
                dba_users b,
                sys.cdef$ c,
                sys.con$ oc
            where
                a.owner = p_table_owner
                and a.table_name = p_table_name
                and a.constraint_type = p_constraint_type
                and b.username = a.owner
                and oc.owner# = b.user_id
                and oc.name = a.constraint_name
                and oc.con# = c.con#
                and (a.constraint_type <> 'C' or c.type# <> 7)
            order by
                a.constraint_name;
    begin
        for c in c_constraint loop
            print_constraint_ddl(
                p_owner             => p_table_owner, 
                p_constraint_name   => c.constraint_name,
                p_object_type       => case
                                        when p_constraint_type = 'R' then 'REF_CONSTRAINT'
                                        else 'CONSTRAINT'
                                       end
            );
            print_nl;
        end loop;
    end print_dependent_constraints;
    

    procedure print_nl
    is begin
        if g_fetch_ddl_cnt > 0 then
            g_pending_newln := true;
        end if;
    end print_nl;


    procedure print_clob (p_clob in clob)
    is
        l_pos0  pls_integer;
        l_pos   pls_integer;
    begin
        if p_clob is null or length(p_clob) = 0 then
            return;
        end if;
        
        if g_pending_newln then
            dbms_output.new_line;
            g_pending_newln := false;
        end if;
        
        l_pos0 := 1;
        l_pos := instr(p_clob, gc_newln, l_pos0);
        while l_pos > 0 loop
            dbms_output.put_line(substr(p_clob, l_pos0, l_pos - l_pos0));
            l_pos0 := l_pos + 1;
            l_pos := instr(p_clob, gc_newln, l_pos0);
        end loop;
        if l_pos0 <= length(p_clob) + 1 then
            dbms_output.put_line(substr(p_clob, l_pos0));
        end if;
    end print_clob;


    procedure print_vc2 (p_vc2 in varchar2)
    is
    begin
        if p_vc2 is null or length(p_vc2) = 0 then
            return;
        end if;

        if g_pending_newln then
            dbms_output.new_line;
            g_pending_newln := false;
        end if;
        
        dbms_output.put_line(p_vc2);
    end print_vc2;


    function xlst_transform_param (
        p_param_name in varchar2, 
        p_bool_value in boolean
    )
    return varchar2
    is
    begin
        return p_param_name 
                || '=' 
                || case 
                     when p_bool_value      then '"1"'
                     when not p_bool_value  then '"0"'
                     else '""'
                   end
                || ' ';
    end xlst_transform_param;


    procedure append_xsl_variable (
        p_clob            in out nocopy clob,
        p_variable_name   in varchar2,
        p_variable_value  in varchar2
    )
    is
    begin
        dbms_lob.append(p_clob, '<xsl:variable name="' || p_variable_name || '">'
                || p_variable_value || '</xsl:variable>');
    end append_xsl_variable;
    
    
    function pp_comment (p_clob in clob) return clob
    is
    begin
        return rtrim(regexp_replace(
                p_clob,
                '\s*(comment\s+on\s+(table|column)\s+)"([^"]+)"\.(.*)$',
                case
                    when gc_strip_object_schema then '\1\4'
                    else '\1"\3".\4'
                end,
                1, 1, 'in'
            ), gc_blank_or_nl);
    end pp_comment;

begin
    case gc_object_type
        when 'TABLE' then 
            print_table_ddl(gc_schema_name, gc_object_name);
        when 'VIEW' then
            print_view_ddl(gc_schema_name, gc_object_name);
        else
            print_other_ddl(gc_object_type, gc_schema_name, gc_object_name);
    end case;
end;
/

