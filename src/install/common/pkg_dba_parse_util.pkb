create or replace package body pkg_dba_parse_util as

   $if dbms_db_version.version >= 18 $then 
    procedure kuxparsequery (
        p_curruid  in number,
        p_schema   in varchar2,
        p_sqltext  in clob,
        p_lobloc   in out nocopy clob
    )
    is
    language c
    library sys.utl_xml_lib
    name "kuxParseQuery"
    with context parameters (
        context,
        p_curruid  ocinumber,
        p_curruid  indicator,
        p_schema   ocistring,
        p_schema   indicator,
        p_sqltext  ociloblocator,
        p_sqltext  indicator,
        p_lobloc   ociloblocator,
        p_lobloc   indicator
    );
   $end

    function parsequery(
        p_parsing_schema  in varchar2,
       $if dbms_db_version.version >= 18 $then
        p_parsing_userid  in number  default sys_context('USERENV', 'SESSION_USERID'),
       $end
        p_sqltext         in clob
    )
    return xmltype
    /*
        Note: derived from Philipp Salvisberg's parse_util.parse_query function
        https://github.com/PhilippSalvisberg/plscope-utils/blob/v1.0.0/database/utils/package/parse_util.pkb
     */
    is
        l_clob clob;
        l_xml  xmltype;
    begin
        if dbms_lob.getlength(p_sqltext) > 0 then
            dbms_lob.createtemporary(l_clob, true);
           $if dbms_db_version.version < 18 $then 
            --
            -- Using UTL_XML.parsequery
            -- Remark: there's no currUid argument in pre-18c releases,
            -- hence the p_curruid argument is not used
            --
            sys.utl_xml.parsequery(p_parsing_schema, p_sqltext, l_clob);
            --
           $else 
            --
            -- Oracle >= 18c: UTL_XML.parsequery is protected by an ACCESSIBLE BY clause
            -- so the C kuxParseQuery function is used as a workaround
            --
            kuxparsequery(
                p_curruid => p_parsing_userid,
                p_schema  => p_parsing_schema,
                p_sqltext => p_sqltext,
                p_lobloc  => l_clob
            );
           $end
            if dbms_lob.getlength(l_clob) > 0 then
                -- parse successfull
                l_xml := xmltype.createxml(l_clob);
            end if;
            dbms_lob.freetemporary(l_clob);
        end if;
        return l_xml;
    end parsequery;


    function view_text_as_clob (
        p_owner      in varchar2,
        p_view_name  in varchar2
    )
    return clob
    is
        lc_stmt_view_rowid constant varchar2(500 byte) := 
                q'{select v.rowid
                     from sys.view$ v,
                          dba_objects o
                    where v.obj# = o.object_id
                      and o.owner = :B_OWNER
                      and o.object_name = :B_VIEW_NAME
                      and o.object_type = 'VIEW'}';

        l_rowid     rowid;
        l_view_text clob;
    begin
        execute immediate lc_stmt_view_rowid
            into l_rowid
            using p_owner, p_view_name;
        
        dbms_lob.createtemporary(l_view_text, true);      
        sys.utl_xml.long2clob    (
            tab     => 'SYS.VIEW$',
            col     => 'TEXT',
            row_id  => l_rowid,
            lobloc  => l_view_text
        );
        return l_view_text;
    end view_text_as_clob;

end pkg_dba_parse_util;
/
