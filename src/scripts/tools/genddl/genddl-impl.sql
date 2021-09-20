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
    gc_sql_terminator constant varchar2(1) := ';';
    
    g_fetch_ddl_cnt number := 0;    /* Count of DDL statements printed in the 
                                       previous call to print_ddl_pieces */

    gc_schema_name constant user_users.username      %type := '&&def_schema_name';
    gc_object_type constant user_objects.object_type %type := '&&def_object_type';
    gc_object_name constant user_objects.object_name %type := '&&def_object_name';

    gc_primary_key_as_alter         constant boolean := &&def_constraint_pk_as_alter;
    gc_unique_key_as_alter          constant boolean := &&def_constraint_unique_as_alter;
    gc_check_constraints_as_alter   constant boolean := &&def_constraint_check_as_alter;
    gc_foreign_key_as_alter         constant boolean := &&def_constraint_foreign_as_alter;
    gc_not_null_as_alter            constant boolean := &&def_constraint_not_null_as_alter;
    gc_print_private_synonyms       constant boolean := &&def_print_private_synonyms;
    gc_print_public_synonyms        constant boolean := &&def_print_public_synonyms;
    gc_strip_object_schema          constant boolean := &&def_strip_object_schema;

    procedure create_table_sxml_xslt (p_clob in out nocopy clob);
    procedure create_synonym_sxml_xslt (p_clob in out nocopy clob);

    procedure print_synonyms (p_schema_name in varchar2, p_table_name in varchar2);
    
    procedure print_nl;
    procedure print_clob (p_clob in clob);
    function as_literal (p_bool in boolean) return varchar2;

    
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
        l_sxml := l_sxml.transform(l_xslt);
        dbms_lob.freetemporary(l_xslt_text);

        /*
           Convert from SXML to DDL
         */
        dbms_lob.createtemporary(l_ddl, true);

        l_mh := dbms_metadata.openw('TABLE');

        l_th := dbms_metadata.add_transform(l_mh, 'SXMLDDL');
        dbms_metadata.set_transform_param(l_th, 'SEGMENT_ATTRIBUTES' , true);  
        dbms_metadata.set_transform_param(l_th, 'STORAGE'            , false);
        dbms_metadata.set_transform_param(l_th, 'TABLESPACE'         , true);  

        dbms_metadata.convert(l_mh, l_sxml, l_ddl);
        dbms_metadata.close(l_mh);
    
        dbms_lob.append(l_ddl, ' ' || gc_sql_terminator);
        print_clob(l_ddl);
        dbms_lob.freetemporary(l_ddl);
        
        g_fetch_ddl_cnt := g_fetch_ddl_cnt + 1;
    end print_table_main_ddl;
    

    procedure print_synonym_ddl (
        p_schema_name   in varchar2,
        p_synonym_name  in varchar2
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
        dbms_metadata.set_filter(l_mh, 'SCHEMA', p_schema_name);
        dbms_metadata.set_filter(l_mh, 'NAME', p_synonym_name);
        
        l_th := dbms_metadata.add_transform(l_mh, 'SXML');
        l_sxml := dbms_metadata.fetch_xml(l_mh);
        dbms_metadata.close(l_mh);
        
        /* 
           Transform using XSLT: remove the object's schema
         */
        create_synonym_sxml_xslt(l_xslt_text);
        l_xslt := xmltype(l_xslt_text);
        l_sxml := l_sxml.transform(l_xslt);
        dbms_lob.freetemporary(l_xslt_text);

        /*
           Convert from SXML to DDL
         */
        dbms_lob.createtemporary(l_ddl, true);
        
        l_mh := dbms_metadata.openw('SYNONYM');
        l_th := dbms_metadata.add_transform(l_mh, 'SXMLDDL');
        dbms_metadata.convert(l_mh, l_sxml, l_ddl);
        
        dbms_lob.append(l_ddl, gc_sql_terminator);
        print_clob(ltrim(l_ddl));
        dbms_lob.freetemporary(l_ddl);

        g_fetch_ddl_cnt := g_fetch_ddl_cnt + 1;
    end print_synonym_ddl;


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
        
        l_constraints_as_alter boolean := true;
    begin
        if p_object_type = 'TABLE' and not p_is_dependent then
            print_table_main_ddl (p_schema_name, p_object_name);
            return;
        end if;

        if p_object_type = 'SYNONYM' and not p_is_dependent then
            print_synonym_ddl (p_schema_name, p_object_name);
            return;
        end if;
    
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

        if gc_strip_object_schema and p_object_type <> 'SYNONYM' then
            l_rh := dbms_metadata.add_transform(l_mh, 'MODIFY');
            dbms_metadata.set_remap_param(l_rh, 'REMAP_SCHEMA', p_schema_name, null);
        end if;

        l_th := dbms_metadata.add_transform(l_mh, 'DDL');
        dbms_metadata.set_transform_param(l_th, 'PRETTY', true);
        dbms_metadata.set_transform_param(l_th, 'SQLTERMINATOR', true);

        if p_object_type = 'TABLE' then
            dbms_metadata.set_transform_param(l_th, 'CONSTRAINTS', true);
            dbms_metadata.set_transform_param(l_th, 'REF_CONSTRAINTS', false);
            dbms_metadata.set_transform_param(l_th, 'CONSTRAINTS_AS_ALTER', 
                    l_constraints_as_alter);
        end if;
        
        if p_object_type in ('TABLE', 'INDEX') then
            dbms_metadata.set_transform_param(l_th, 'SEGMENT_ATTRIBUTES', true);
            dbms_metadata.set_transform_param(l_th, 'STORAGE', false);
            dbms_metadata.set_transform_param(l_th, 'TABLESPACE', true);

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
                print_clob(l_ddls(i).ddltext);
            end loop;
        end loop ddl_fetch_loop;
        
        dbms_metadata.close(l_mh);
    end print_ddl_pieces;
    
    
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
             }'
        );
        dbms_lob.append(
            p_clob, 
            '<xsl:variable name="primary-key-as-alter" select="'
                || as_literal(gc_primary_key_as_alter)
                || '()" />'
        );
        dbms_lob.append(
            p_clob, 
            '<xsl:variable name="unique-key-as-alter" select="'
                || as_literal(gc_unique_key_as_alter)
                || '()" />'
        );
        dbms_lob.append(
            p_clob, 
            '<xsl:variable name="check-constraints-as-alter" select="'
                || as_literal(gc_check_constraints_as_alter)
                || '()" />'
        );
        dbms_lob.append(
            p_clob, 
            '<xsl:variable name="foreign-key-as-alter" select="'
                || as_literal(gc_foreign_key_as_alter)
                || '()" />'
        );
        dbms_lob.append(
            p_clob, 
            '<xsl:variable name="not-null-as-alter" select="'
                || as_literal(gc_not_null_as_alter)
                || '()" />'
        );
        dbms_lob.append(
            p_clob, 
            '<xsl:variable name="remove-object-schema" select="'
                || as_literal(gc_strip_object_schema)
                || '()" />'
        );
        dbms_lob.append(
            p_clob,
            q'{ <xsl:output omit-xml-declaration="yes"/>
                
                <xsl:template match="node()|@*">
                    <xsl:copy>
                        <xsl:apply-templates/>
                    </xsl:copy>
                </xsl:template>

                <xsl:template match="ora:TABLE/ora:SCHEMA">
                    <xsl:if test="$remove-object-schema = false()">
                        <xsl:copy>
                            <xsl:apply-templates/>
                        </xsl:copy>
                    </xsl:if>
                </xsl:template>
                
                <xsl:template match="ora:PRIMARY_KEY_CONSTRAINT_LIST">
                    <xsl:if test="$primary-key-as-alter = false()">
                        <xsl:copy>
                            <xsl:apply-templates/>
                        </xsl:copy>
                    </xsl:if>
                </xsl:template>
                
                <xsl:template match="ora:UNIQUE_KEY_CONSTRAINT_LIST">
                    <xsl:if test="$unique-key-as-alter = false()">
                        <xsl:copy>
                            <xsl:apply-templates/>
                        </xsl:copy>
                    </xsl:if>
                </xsl:template>
                
                <xsl:template match="ora:CHECK_CONSTRAINT_LIST">  
                    <xsl:if test="$check-constraints-as-alter = false()">
                        <xsl:copy>
                            <xsl:apply-templates/>
                        </xsl:copy>
                    </xsl:if>
                </xsl:template>

                <xsl:template match="ora:FOREIGN_KEY_CONSTRAINT_LIST">  
                    <xsl:if test="$foreign-key-as-alter = false()">
                        <xsl:copy>
                            <xsl:apply-templates/>
                        </xsl:copy>
                    </xsl:if>
                </xsl:template>

                <xsl:template match="ora:COL_LIST_ITEM/ora:NOT_NULL">  
                    <xsl:if test="$not-null-as-alter = false()">
                        <xsl:copy>
                            <xsl:apply-templates/>
                        </xsl:copy>
                    </xsl:if>
                </xsl:template>

            </xsl:stylesheet>}'
        );
    end create_table_sxml_xslt;
    

    procedure create_synonym_sxml_xslt (p_clob in out nocopy clob)
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
             }'
        );
        dbms_lob.append(
            p_clob, 
            '<xsl:variable name="remove-object-schema" select="'
                || as_literal(gc_strip_object_schema)
                || '()" />'
        );
        dbms_lob.append(
            p_clob,
            q'{ <xsl:output omit-xml-declaration="yes"/>
                
                <xsl:template match="node()|@*">
                    <xsl:copy>
                        <xsl:apply-templates/>
                    </xsl:copy>
                </xsl:template>
                
                <xsl:template match="ora:OBJECT_SCHEMA">
                    <xsl:if test="$remove-object-schema = false()">
                        <xsl:copy>
                            <xsl:apply-templates/>
                        </xsl:copy>
                    </xsl:if>
                </xsl:template>
            </xsl:stylesheet>}'
        );
    end create_synonym_sxml_xslt;

    
    procedure print_table_ddl (p_schema_name in varchar2, p_table_name in varchar2)
    is
    begin
        print_ddl_pieces('TABLE', p_schema_name, p_table_name);
        print_nl;

        print_ddl_pieces('INDEX', p_schema_name, p_table_name, 
                p_is_dependent => true, p_base_object_type => 'TABLE');
        print_nl;
        
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
        
        /* CHECK constraints */
        if gc_check_constraints_as_alter then
            print_ddl_pieces('CONSTRAINT', p_schema_name, p_table_name, 
                    p_is_dependent => true, p_base_object_type => 'TABLE',
                    p_custom_filter => 'TYPE_NUM = 1');
            print_nl;
        end if;

        /* PRIMARY KEY constraints */
        if gc_primary_key_as_alter then
            print_ddl_pieces('CONSTRAINT', p_schema_name, p_table_name, 
                    p_is_dependent => true, p_base_object_type => 'TABLE',
                    p_custom_filter => 'TYPE_NUM = 2');
            print_nl;
        end if;

        /* UNIQUE KEY constraints */
        if gc_unique_key_as_alter then
            print_ddl_pieces('CONSTRAINT', p_schema_name, p_table_name, 
                    p_is_dependent => true, p_base_object_type => 'TABLE',
                    p_custom_filter => 'TYPE_NUM = 3');
            print_nl;
        end if;

        if gc_foreign_key_as_alter then
            print_ddl_pieces('REF_CONSTRAINT', p_schema_name, p_table_name,
                    p_is_dependent => true, p_base_object_type => 'TABLE');
            print_nl;
        end if;

        print_ddl_pieces('OBJECT_GRANT', p_schema_name, p_table_name,
                p_is_dependent => true, p_base_object_type => 'TABLE');
        print_nl;

        print_synonyms(p_schema_name, p_table_name);
    end print_table_ddl;
    

    procedure print_view_ddl (p_schema_name in varchar2, p_view_name in varchar2)
    is
    begin
        print_ddl_pieces('VIEW', p_schema_name, p_view_name);
        print_nl;

        print_ddl_pieces('OBJECT_GRANT', p_schema_name, p_view_name,
                p_is_dependent => true, p_base_object_type => 'VIEW');
        print_nl;

        print_synonyms(p_schema_name, p_view_name);
    end print_view_ddl;


    procedure print_other_ddl (
        p_object_type in varchar2,
        p_schema_name in varchar2,
        p_object_name in varchar2
    )
    is
    begin
        print_ddl_pieces(p_object_type, p_schema_name, p_object_name);
    end print_other_ddl;


    procedure print_synonyms (p_schema_name in varchar2, p_table_name in varchar2)
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
                a.table_owner = p_schema_name
                and a.table_name = p_table_name
            order by
                decode(a.owner, 'PUBLIC', 0, 1) asc,
                a.owner, synonym_name
        )
        loop
            if (c.owner = 'PUBLIC' and gc_print_public_synonyms)
                or (c.owner <> 'PUBLIC' and gc_print_private_synonyms)
            then
                print_ddl_pieces('SYNONYM', c.owner, c.synonym_name);
                print_nl;
            end if;
        end loop;
    end print_synonyms;


    procedure print_nl
    is begin
        if g_fetch_ddl_cnt > 0 then
            dbms_output.new_line;
        end if;
    end print_nl;


    procedure print_clob (p_clob in clob)
    is
        l_pos0  pls_integer;
        l_pos   pls_integer;
    begin
        l_pos0 := 1;
        l_pos := instr(p_clob, gc_newln, l_pos0);
        while l_pos > 0 loop
            dbms_output.put_line(substr(p_clob, l_pos0, l_pos - l_pos0));
            l_pos0 := l_pos + 1;
            l_pos := instr(p_clob, gc_newln, l_pos0);
        end loop;
        if l_pos0 <= length(p_clob) then
            dbms_output.put_line(substr(p_clob, l_pos0));
        end if;
    end print_clob;


    function as_literal (p_bool in boolean) return varchar2
    is
    begin
        return case 
                when p_bool then 'true'
                when not p_bool then 'false'
               end;
    end as_literal;

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

