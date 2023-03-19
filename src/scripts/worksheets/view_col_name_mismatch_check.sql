/* 
    An attempt to find differences between declared names of view columns
    and corresponding column names / aliases in the select-list of each
    view's defining query. While such differences are commonplace, they
    may also happen by mistake, hence being able to detect and review 
    them might be useful.
    
    #######################################
    ### Status: experimental (unstable) ###
    #######################################
*/

with
view_like_in as (
    select
        :VIEW_LIKE_LIST  as str,
        '\s* ( ( [^"[:space:]] "? )+ | " ( [^"] )* " ) \s*'  as rex
    from
        dual
),
view_pattrn_raw as (
    select
        regexp_substr(a.str, a.rex, 1, level, 'x')  as tok
    from
        view_like_in a
    connect by
        regexp_instr (a.str, a.rex, 1, level, 0, 'x') > 0
),
view_pattrn_trimmed as (
    select
        regexp_replace(regexp_replace(b.tok, '^\s*'), '\s*$')  as tok
    from
        view_pattrn_raw b
),
view_pattrn_dequoted as (
    select 
        regexp_replace(c.tok, '^" (.*) "$', '\1', 1, 1, 'nx')  as tok
    from
        view_pattrn_trimmed c
),
view_like_list as (
    select /*+ materialize */
        d.tok  as view_like
    from
        view_pattrn_dequoted d
    where
        d.tok is not null
),
matching_views as (
    select /*+ materialize */
        a.owner,
        a.view_name,
        listagg(b.view_like, ' | ') within group (order by b.view_like)
            as matching_patterns
    from
        dba_views a,
        view_like_list b
    where
        (:OWNER_LIKE is null or upper(a.owner) like upper(:OWNER_LIKE) escape '\') 
        and (:OWNER_RE is null or regexp_like(a.owner, :OWNER_RE, 'i'))
        and upper(a.view_name) like upper(b.view_like) escape '\'
    group by
        a.owner, a.view_name
)
-- Remark: must use nested subqueries in the FROM clause from this point on if using 11.2,
-- because of Bug 16342156 - Wrong results from XMLTable in WITH clause (Doc ID 16342156.8)
select
    col.owner,
    col.view_name,
    col.view_status,
    col.column_id,
    col.column_name,
    case
        when col.column_name = coalesce(sli.sel_alias_name, sli.sel_column_name) then
            '='
        when col.column_name <> coalesce(sli.sel_alias_name, sli.sel_column_name) then
            'mismatch' -- Orange
    end as eq,
    coalesce(sli.sel_alias_name, sli.sel_column_name)  as sel_alias_or_column_name,
    case
        when col.column_name = coalesce(sli.sel_alias_name, sli.sel_column_name) then
            'SQLDEV:GAUGE:0:100:0:0:0' -- Green
        when col.column_name <> coalesce(sli.sel_alias_name, sli.sel_column_name) then
            'SQLDEV:GAUGE:0:100:0:100:0' -- Orange
    end as eq_wl,
    col.matching_patterns
from
    (select
        v2.owner,
        v2.view_name,
        sli0.col_position,
        sli0.alias_name  as sel_alias_name,
        sli0.column_name as sel_column_name
    from 
        (select
            v1.*,
            c##pkg_dba_parse_util.parsequery(
                p_parsing_schema => v1.owner,
                --p_parsing_userid => (select u.user_id from all_users u where u.username = v1.owner),
                p_sqltext => v1.text
            ) as parsed_query_xml
        from
            (select
                v0.owner,
                v0.view_name,
                c##pkg_dba_parse_util.view_text_as_clob(v0.owner, v0.view_name) as text
            from
                matching_views v0
            ) v1
        ) v2,
        xmltable(
            '(//QUERY/*[not(ancestor::WITH)]/SELECT_LIST)[1]/SELECT_LIST_ITEM'
            passing v2.parsed_query_xml
            columns 
                col_position for ordinality,
                alias_name  varchar2(128) path 'COLUMN_ALIAS',
                column_name varchar2(128) path 'COLUMN_REF/COLUMN'
        ) sli0
    ) sli,
    (select
        v.owner,
        v.view_name,
        c.column_id,
        c.column_name,
        o.status  as view_status,
        v.matching_patterns
    from
        matching_views v,
        dba_objects o,
        dba_tab_cols c
    where
        v.owner = c.owner (+)
        and v.view_name = c.table_name (+)
        and o.owner = v.owner
        and o.object_name = v.view_name
        and o.object_type = 'VIEW'
    ) col
where
    sli.owner (+) = col.owner
    and sli.view_name (+) = col.view_name
    and sli.col_position (+) = col.column_id
order by
    col.owner,
    col.view_name,
    col.column_id
;


