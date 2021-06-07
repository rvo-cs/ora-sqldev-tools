define def_role_impl = "&1"

set linesize 400

prompt ===============================================================================
prompt Role privilege details report                         Date: &&_DATE
prompt -------------------------------------------------------------------------------

prompt

prompt ~~~~~~~~~~~~~~~~
prompt Role information
prompt ----------------

set heading off
set feedback off

column item format a22
column value format a80 word_wrapped

select
    item, value
from
    (select
        sys_context('USERENV', 'DB_NAME')               as db_name
        , a.role
        , a.password_required
        , a.authentication_type
        &&def_db_version_ge_12 , a.common
        &&def_db_version_ge_12 , a.oracle_maintained
        &&def_db_version_ge_12 , a.inherited
        &&def_db_version_ge_12 , a.implicit
        &&def_db_version_ge_18 , a.external_name
    from
        dba_roles a
    where
        a.role = '&&def_role_impl'
    )
    unpivot exclude nulls 
    (value for item in (
        db_name                 as 'Database            : '
        , role                  as 'Role                : '
        , password_required     as 'Password required   : ' 
        , authentication_type   as 'Authentication type : '
        &&def_db_version_ge_12 , common                as 'Common              : '
        &&def_db_version_ge_12 , oracle_maintained     as 'Oracle-maintained   : '
        &&def_db_version_ge_12 , inherited             as 'Inherited           : '
        &&def_db_version_ge_12 , implicit              as 'Implicit            : '
        &&def_db_version_ge_18 , external_name         as 'External name       : '
    ))
;

clear columns

set feedback on
set heading on

prompt

prompt ~~~~~~~~~~~~
prompt Parent roles
prompt ------------

column parent_role              format a30 wrapped
column grant_chain              format a100 word_wrap

break on parent_role noduplicates

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
)
select
    role  as parent_role,
    grant_chain
from
    (select distinct
        a.role,
        a.grant_chain,
        a.grant_chain_len 
    from 
        role_chain a
    where
        a.granted_role = '&&def_role_impl'
        and a.role <> a.granted_role
    )
order by
    role,
    grant_chain_len asc,
    grant_chain asc
;

clear columns
clear breaks


prompt ~~~~~~~~~~~
prompt Child roles
prompt -----------

column granted_role             format a30 wrapped
column grant_chain              format a100 word_wrap

break on granted_role noduplicates

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
)
select
    granted_role,
    grant_chain
from
    (select distinct
        a.granted_role,
        a.grant_chain,
        a.grant_chain_len 
    from 
        role_chain a
    where
        a.role = '&&def_role_impl'
        and a.role <> a.granted_role
    )
order by
    granted_role,
    grant_chain_len asc,
    grant_chain asc
;

clear columns
clear breaks


prompt ~~~~~~~~~~~~~~~~~~~~~~~~~~~
prompt Role grants  (at 1st level)
prompt ---------------------------

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
    a.grantee = '&&def_role_impl'
order by
    a.granted_role
;

clear columns


prompt ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
prompt System privilege grants  (at 1st level)
prompt ---------------------------------------

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
    a.grantee = '&&def_role_impl'
order by
    a.privilege
;

clear columns


prompt ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
prompt Object privilege grants  (at 1st level)
prompt ---------------------------------------

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
        a.grantee = '&&def_role_impl'
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

clear columns


prompt ~~~~~~~~~~~~~~~~~~~~~
prompt All system privileges
prompt ---------------------

column role                     format a30 wrapped
column privilege                format a40 word_wrapped
column admin_opt                format a9
column grant_chain              format a100 word_wrapped

break on privilege on role on admin_opt noduplicates

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
role_chain_sys_privs as (
    select /*+ no_merge(a) no_merge(b) */
    distinct
        b.role,
        a.privilege,
        a.admin_option,
        b.grant_chain 
                || case when a.admin_option = 'YES' then ' >> ' else ' > ' end
                || a.privilege  as grant_chain,
        b.grant_chain_len       as grant_chain_len
    from
        dba_sys_privs a,
        role_chain b
    where
        a.grantee = b.granted_role
        and b.role = '&&def_role_impl'
)
select
    a.role, a.privilege, 
    a.admin_option          as admin_opt, 
    a.grant_chain
from
    role_chain_sys_privs a
order by
    a.role,
    regexp_substr(a.privilege, '.*ANY (.*)', 1, 1, null, 1), 
    a.privilege,
    a.admin_option desc,
    a.grant_chain_len asc, a.grant_chain asc
;

clear columns
clear breaks


prompt ~~~~~~~~~~~~~~~~~~~~~
prompt All object privileges
prompt ---------------------

@@roleprivs-note-oraobj&&def_hide_ora_obj

column role                     format a30 wrapped
column object_privs             format a50 word_wrapped
column owner                    format a30 wrapped
column object_type              format a23 wrapped
column object_name              format a30 wrapped
column grantable                format a9
column hierarchy                format a9
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
    where 1 = 1
        &&def_hide_ora_obj and owner not in ( 'ANONYMOUS'
        &&def_hide_ora_obj                  , 'APPQOSSYS'
        &&def_hide_ora_obj                  , 'AUDSYS'
        &&def_hide_ora_obj                  , 'DBSFWUSER'
        &&def_hide_ora_obj                  , 'DBSNMP'
        &&def_hide_ora_obj                  , 'DIP'
        &&def_hide_ora_obj                  , 'GGSYS'
        &&def_hide_ora_obj                  , 'GSMADMIN_INTERNAL'
        &&def_hide_ora_obj                  , 'GSMCATUSER'
        &&def_hide_ora_obj                  , 'GSMUSER'
        &&def_hide_ora_obj                  , 'LBACSYS'
        &&def_hide_ora_obj                  , 'ORACLE_OCM'
        &&def_hide_ora_obj                  , 'OUTLN'
        &&def_hide_ora_obj                  , 'REMOTE_SCHEDULER_AGENT'
        &&def_hide_ora_obj                  , 'SYS'
        &&def_hide_ora_obj                  , 'SYSBACKUP'
        &&def_hide_ora_obj                  , 'SYSDG'
        &&def_hide_ora_obj                  , 'SYSKM'
        &&def_hide_ora_obj                  , 'SYSRAC'
        &&def_hide_ora_obj                  , 'SYSTEM'
        &&def_hide_ora_obj                  , 'SYS$UMF'
        &&def_hide_ora_obj                  , 'WMSYS'
        &&def_hide_ora_obj                  , 'XDB'
        &&def_hide_ora_obj                  , 'XS$NULL' 
        &&def_hide_ora_obj                  )
    group by
        owner, object_type, object_name,
        grantee, grantable, hierarchy
),
role_chain_obj_privs as (
    select /*+ no_merge(a) no_merge(b) */
    distinct
        b.role,
        a.object_privs,
        a.owner, a.object_type, a.object_name,
        b.grant_chain || ' > ' || dbms_assert.enquote_name(owner) 
                || '.' || dbms_assert.enquote_name(a.object_name)   as grant_chain,
        b.grant_chain_len + 1       as grant_chain_len,
        a.grantable, a.hierarchy
    from
        object_grant_grouped_priv a,
        role_chain b
    where
        a.grantee = b.granted_role
        and b.role = '&&def_role_impl'
)
select
    a.role, a.object_privs
    , a.owner, a.object_name, a.object_type
    , a.grantable, a.hierarchy
    , a.grant_chain
from
    role_chain_obj_privs a
order by
    role,
    owner, object_type, object_name,
    grantable desc, hierarchy desc,
    grant_chain_len asc, grant_chain asc
;

clear columns

prompt === End ===

undefine def_role_impl
