clear screen

define def_username_impl = "&1"

set linesize 400

prompt ==============================
prompt User privilege details report
prompt ------------------------------

prompt

prompt ~~~~~~~~~~~~~~~~
prompt User information
prompt ----------------

column item format a31
column value format a80 word_wrapped
set heading off
set feedback off

select
    item, value
from
    (select
        sys_context('USERENV', 'DB_NAME')               as db_name,
        a.username,
        to_char(a.user_id)                              as user_id,
        to_char(a.created, 'YYYY-MM-DD HH24:MI:SS')     as created,
        a.account_status,
        to_char(a.expiry_date, 'YYYY-MM-DD HH24:MI:SS') as expiry_date,
        to_char(a.lock_date, 'YYYY-MM-DD HH24:MI:SS')   as lock_date,
        a.profile,
        a.authentication_type,
        a.external_name,
        a.initial_rsrc_consumer_group,
        a.default_tablespace,
        a.temporary_tablespace
    from
        dba_users a
    where
        a.username = '&&def_username_impl'
    )
    unpivot exclude nulls 
    (value for item in (
        db_name                         as 'Database                     : ',
        username                        as 'Username                     : ',
        user_id                         as 'User id                      : ', 
        created                         as 'Date created                 : ',
        account_status                  as 'Account status               : ',
        expiry_date                     as 'Expiry date                  : ',
        lock_date                       as 'Lock date                    : ',
        profile                         as 'Profile                      : ',
        authentication_type             as 'Authentication type          : ',
        external_name                   as 'External name                : ',
        initial_rsrc_consumer_group     as 'Initial rsrc. consumer group : ',
        default_tablespace              as 'Default tablespace           : ',
        temporary_tablespace            as 'Temp. tablespace             : '
    ))
;

set feedback on
set heading on

prompt

prompt ~~~~~~~~~~~~~~~~~
prompt Tablespace quotas
prompt -----------------

select
    a.tablespace_name,
    case
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
       end  as quota
from
    dba_ts_quotas a,
    dba_tablespaces b
where
    a.username = '&&def_username_impl'
    and a.dropped = 'NO'
    and a.tablespace_name = b.tablespace_name
    and b.contents <> 'TEMPORARY'
;


prompt ~~~~~~~~~~~~~~~~~~~~
prompt Proxy authentication
prompt --------------------

column proxy                    format a20  wrapped
column client                   format a30  wrapped
column authentication	        format a7   wrapped
column authorization_constraint	format a35  wrapped
column role	                    format a30  wrapped
column proxy_authority	        format a15  wrapped

select
    proxy, client, authentication,
    authorization_constraint, role, proxy_authority
from
    dba_proxies
where 
    client = '&&def_username_impl'
;

column proxy                    clear
column client                   clear
column authentication	        clear
column authorization_constraint	clear
column role	                    clear
column proxy_authority	        clear


prompt ~~~~~~~~~~~
prompt Role grants
prompt -----------

column grantee                  format a30 wrapped
column granted_role             format a30 wrapped
column admin_option             format a9
column delegate_option          format a12
column default_role             format a12 
column common                   format a6
column inherited                format a9

select
    a.grantee
    , a.granted_role 
    , a.default_role
    , a.admin_option
    &&def_db_version_ge_12 , a.delegate_option 
    &&def_db_version_ge_12 &&def_hide_column_common , a.common
    &&def_db_version_ge_12 &&def_hide_column_inherited , a.inherited 
from
    dba_role_privs a
where
    a.grantee = '&&def_username_impl'
order by
    a.granted_role
;

column grantee                  clear
column granted_role             clear
column admin_option             clear
column delegate_option          clear
column default_role             clear
column common                   clear
column inherited                clear


prompt ~~~~~~~~~~~~~~~~~~~~~~~
prompt System privilege grants
prompt -----------------------

column grantee                  format a30 wrapped
column privilege                format a40 word_wrapped
column admin_option             format a9
column common                   format a6
column inherited                format a9

select
    a.grantee
    , a.privilege
    , a.admin_option
    &&def_db_version_ge_12 &&def_hide_column_common , a.common
    &&def_db_version_ge_12 &&def_hide_column_inherited , a.inherited
from
    dba_sys_privs a
where
    a.grantee = '&&def_username_impl'
order by
    a.privilege
;

column grantee                  clear
column privilege                clear
column admin_option             clear
column common                   clear
column inherited                clear


prompt ~~~~~~~~~~~~~~~~~~~~~~~
prompt Object privilege grants
prompt -----------------------

set pagesize 18

column grantee                  format a30 wrapped
column object_privs             format a50 word_wrapped
column owner                    format a30 wrapped
column object_type              format a23 wrapped
column object_name              format a30 wrapped
column grantable                format a9
column hierarchy                format a9
column common                   format a6
column inherited                format a9

select
    grantee
    , listagg(privilege, ', ') within group (order by 
            /* Fancy ordering of privileges */
            case 
                when object_type = 'TABLE' 
                    then decode(privilege, 'ALTER', '1', 'READ', '2', 'SELECT', '3',
                                'INSERT', '4', 'UPDATE', '5', 'DELETE', '6', privilege)
                when object_type = 'VIEW'
                    then decode(privilege, 'READ', '1', 'SELECT', '2', 'INSERT', '3',
                                'UPDATE', '4', 'DELETE', '5', privilege)
                when object_type = 'DIRECTORY'
                    then decode(privilege, 'READ', '1', 'WRITE', '2', 'EXECUTE', '3')
                else
                    privilege
            end)        as object_privs
    , owner
    , object_name
    , object_type
    , grantable
    , hierarchy
    &&def_db_version_ge_12 &&def_hide_column_common , common
    &&def_db_version_ge_12 &&def_hide_column_inherited , inherited
from
    (select distinct  /* Note: each priv may have been granted
                         more than once by distinct grantors */
        a.grantee
        , a.privilege
        , b.owner
        , b.object_type
        , b.object_name
        , a.grantable
        , a.hierarchy
        &&def_db_version_ge_12 &&def_hide_column_common , a.common
        &&def_db_version_ge_12 &&def_hide_column_inherited , a.inherited
    from
        dba_tab_privs a,
        dba_objects b
    where
        a.grantee = '&&def_username_impl'
        and a.table_name = b.object_name
        &&def_db_version_ge_12 and a.type = b.object_type
        and b.object_type in (
                /* Namespace: 1 */
                'FUNCTION', 'INDEXTYPE', 'JOB CLASS', 'JOB'
                , 'LIBRARY', 'OPERATOR', 'PACKAGE', 'PROCEDURE'
                , 'PROGRAM', 'SCHEDULE', 'SCHEDULER GROUP'
                , 'SEQUENCE'
                --, 'SYNONYM' /* Grants on synonyms are the same as grants on the base object */
                , 'TABLE', 'TYPE', 'VIEW', 'WINDOW'
                /* Namespace: 9 */
                , 'DIRECTORY'
                /* Namespace: 10 */
                , 'QUEUE'
                /* Namespace: 19 */
                --, 'MATERIALIZED VIEW' /* Privs on MVs are linked to container tables */
                /* Namespace :64 */
                , 'EDITION'
            )
    )
group by
    grantee
    , owner
    , object_type
    , object_name
    , grantable
    , hierarchy
    &&def_db_version_ge_12 &&def_hide_column_common , common
    &&def_db_version_ge_12 &&def_hide_column_inherited , inherited
order by
    owner
    , object_type
    , object_name
    , object_privs
    , grantable
    , hierarchy
    &&def_db_version_ge_12 &&def_hide_column_common , common
    &&def_db_version_ge_12 &&def_hide_column_inherited , inherited
;

column grantee                  clear
column object_privs             clear
column owner                    clear
column object_type              clear
column object_name              clear
column grantable                clear
column hierarchy                clear
column common                   clear
column inherited                clear


prompt ~~~~~~~~~~~~~~~~~~~~~
prompt All system privileges
prompt ---------------------

column grantee                  format a30 wrapped
column privilege                format a40 word_wrapped
column admin_option             format a9
column direct_grant             format a6
column granted_role             format a30 wrapped
column default_role             format a12
column grant_chain              format a100 word_wrapped

with 
target_sys_privs as (
    select 
        name as privilege
    from 
        system_privilege_map
),
role_chain (role, granted_role, 
            grant_chain, grant_chain_len) as (
    select 
        role, role, role, 1
    from 
        dba_roles
    union all
    select
        a.role, b.granted_role,
        a.grant_chain 
                || case when b.admin_option = 'YES' then ' >> ' else ' > ' end
                || b.granted_role,
        a.grant_chain_len + 1
    from
        role_chain a,
        dba_role_privs b
    where
        a.granted_role = b.grantee
        and b.grantee in (select c.role from dba_roles c)
),
direct_grant as (
    select distinct
        a.grantee,
        a.privilege,
        a.admin_option,
        'YES'  as direct_grant,
        null   as granted_role,
        a.grantee 
                || case when a.admin_option = 'YES' then ' >> ' else ' > ' end 
                || a.privilege  as grant_chain,
        1       as grant_chain_len,
        null    as default_role
    from
        dba_sys_privs a,
        target_sys_privs b
    where
        a.privilege = b.privilege
        and a.grantee not in (select c.role from dba_roles c)
        and a.grantee in ( '&&def_username_impl'
                         &&def_hide_grants_to_public , 'PUBLIC'
                         )
),
grant_through_roles as (
    select /*+ merge(@subr) no_merge(a) no_merge(b) no_merge(c) no_merge(d)
               leading(b a c d e@subr) */
    distinct
        d.grantee,
        a.privilege,
        a.admin_option,
        'NO'   as direct_grant,
        d.granted_role,
        d.grantee 
                || case when d.admin_option = 'YES' then ' >> ' else ' > ' end
                || c.grant_chain 
                || case when a.admin_option = 'YES' then ' >> ' else ' > ' end
                || a.privilege  as grant_chain,
        c.grant_chain_len + 1   as grant_chain_len,
        d.default_role          as default_role
    from
        dba_sys_privs a,
        target_sys_privs b,
        role_chain c,
        dba_role_privs d
    where
        a.privilege = b.privilege
        and a.grantee = c.granted_role
        and c.role = d.granted_role
        and d.grantee in ( '&&def_username_impl'
                         &&def_hide_grants_to_public , 'PUBLIC'
                         )
        and d.grantee not in (select /*+ qb_name(subr) */ e.role from dba_roles e)
)
select
    grantee, privilege, admin_option, 
    direct_grant, granted_role, default_role, 
    grant_chain
from
    (select 
        grantee, privilege, admin_option
        , direct_grant
        , granted_role
        , default_role
        , grant_chain
        , grant_chain_len
    from
        direct_grant
    union all
    select 
        grantee, privilege, admin_option
        , direct_grant
        , granted_role
        , default_role
        , grant_chain
        , grant_chain_len
    from
        grant_through_roles
    )
order by
    case when grantee = 'PUBLIC' then 1 else 0 end asc,
    regexp_substr(privilege, '.*ANY (.*)', 1, 1, null, 1), 
    privilege,
    grantee, direct_grant desc,
    grant_chain_len asc, grant_chain asc
;

column grantee                  clear
column privilege                clear
column admin_option             clear
column direct_grant             clear
column granted_role             clear
column default_role             clear
column grant_chain              clear


prompt ~~~~~~~~~~~~~~~~~~~~~
prompt All object privileges
prompt ---------------------

column grantee                  format a30 wrapped
column object_privs             format a50 word_wrapped
column owner                    format a30 wrapped
column object_type              format a23 wrapped
column object_name              format a30 wrapped
column grantable                format a9
column hierarchy                format a9
column direct_grant             format a6
column granted_role             format a30 wrapped
column default_role             format a12
column grant_chain              format a100 word_wrapped

with 
role_chain (role, granted_role, 
            grant_chain, grant_chain_len) as (
    select 
        role, role, role, 1
    from 
        dba_roles
    union all
    select
        a.role, b.granted_role,
        a.grant_chain 
                || case when b.admin_option = 'YES' then ' >> ' else ' > ' end
                || b.granted_role,
        a.grant_chain_len + 1
    from
        role_chain a,
        dba_role_privs b
    where
        a.granted_role = b.grantee
        and b.grantee in (select c.role from dba_roles c)
),
object_grant as (
    select /*+ materialize */ 
           distinct  /* Note: each priv may have been granted
                        more than once by distinct grantors */
        b.owner, b.object_type, b.object_name,
        a.privilege, a.grantee, a.grantable, a.hierarchy
    from
        dba_tab_privs a,
        dba_objects b
    where
        a.owner = b.owner
        and a.table_name = b.object_name
        &&def_db_version_ge_12 and a.type = b.object_type
        and b.object_type in (
                /* Namespace: 1 */
                'FUNCTION', 'INDEXTYPE', 'JOB CLASS', 'JOB'
                , 'LIBRARY', 'OPERATOR', 'PACKAGE', 'PROCEDURE'
                , 'PROGRAM', 'SCHEDULE', 'SCHEDULER GROUP'
                , 'SEQUENCE'
                --, 'SYNONYM'   /* Grants on synonyms are grants on base objects */
                , 'TABLE', 'TYPE', 'VIEW', 'WINDOW'
                /* Namespace: 9 */
                , 'DIRECTORY'
                /* Namespace: 10 */
                , 'QUEUE'
                /* Namespace: 19 */
                --, 'MATERIALIZED VIEW' /* Privs on MVs are linked to container tables */
                /* Namespace :64 */
                , 'EDITION'
            )
),
object_grant_grouped_priv as (
    select
        owner, object_type, object_name,
        grantee,
        listagg(privilege, ', ') within group (order by 
                /* Fancy ordering of privileges */
                case 
                    when object_type = 'TABLE' 
                        then decode(privilege, 'ALTER', '1', 'READ', '2', 'SELECT', '3',
                                    'INSERT', '4', 'UPDATE', '5', 'DELETE', '6', privilege)
                    when object_type = 'VIEW'
                        then decode(privilege, 'READ', '1', 'SELECT', '2', 'INSERT', '3',
                                    'UPDATE', '4', 'DELETE', '5', privilege)
                    when object_type = 'DIRECTORY'
                        then decode(privilege, 'READ', '1', 'WRITE', '2', 'EXECUTE', '3')
                    else
                        privilege
                end)  as object_privs,
        grantable, hierarchy
    from
        object_grant
    group by
        owner, object_type, object_name,
        grantee, grantable, hierarchy
),
direct_grant as (
    select 
        a.*,
        'YES'   as direct_grant,
        null    as granted_role,
        a.grantee 
                || case when a.grantable = 'YES' then ' >> ' else ' > ' end 
                || dbms_assert.enquote_name(a.owner) 
                || '.' || dbms_assert.enquote_name(a.object_name)   as grant_chain,
        1       as grant_chain_len,
        null    as admin_option,
        null    as default_role
    from
        object_grant_grouped_priv a
    where
        a.grantee not in (select b.role from dba_roles b)
        and a.grantee in ( '&&def_username_impl'
                         &&def_hide_grants_to_public , 'PUBLIC'
                         )
        and a.grantee <> a.owner    /* Exclude direct grants to self */
),
grant_through_roles as (
    select /*+ merge(@subr) no_merge(a) no_merge(b) no_merge(c)
               leading(a b c d@subr) */
    distinct
        a.owner, a.object_type, a.object_name,
        c.grantee,
        a.object_privs,
        'NO'    as direct_grant,
        c.granted_role,
        b.grant_chain_len + 1       as grant_chain_len,
        c.grantee 
                || case when c.admin_option = 'YES' then ' >> ' else ' > ' end
                || b.grant_chain || ' > ' || dbms_assert.enquote_name(owner) 
                || '.' || dbms_assert.enquote_name(a.object_name)   as grant_chain,
        a.grantable, a.hierarchy,
        c.default_role
    from
        object_grant_grouped_priv a,
        role_chain b,
        dba_role_privs c
    where
        a.grantee = b.granted_role
        and b.role = c.granted_role
        and c.grantee not in (select /*+ qb_name(subr) */ d.role from dba_roles d)
        and c.grantee in ( '&&def_username_impl'
                         &&def_hide_grants_to_public , 'PUBLIC'
                         )
        and c.grantee <> a.owner                /* Exclude indirect grants to self */
)
select
    grantee, object_privs
    , owner, object_name, object_type
    , grantable, hierarchy
    , direct_grant
    , granted_role
    , default_role
    , grant_chain
from
    (select 
        owner, object_name, object_type,
        grantee, object_privs,
        direct_grant,
        granted_role,
        default_role,
        grant_chain,
        grantable, hierarchy,
        grant_chain_len
    from
        direct_grant
    union all
    select 
        owner, object_name, object_type,
        grantee, object_privs,
        direct_grant,
        granted_role,
        default_role,
        grant_chain,
        grantable, hierarchy,
        grant_chain_len
    from
        grant_through_roles
    )
order by
    case when grantee = 'PUBLIC' then 1 else 0 end asc,
    owner, object_type, object_name,
    grantee, direct_grant desc,
    grant_chain_len asc, grant_chain asc
;    

column grantee                  clear
column object_privs             clear
column owner                    clear
column object_type              clear
column object_name              clear
column grantable                clear
column hierarchy                clear
column direct_grant             clear
column granted_role             clear
column default_role             clear
column grant_chain              clear

prompt === End ===

undefine def_username_impl
