/*
    PURPOSE
        This worksheet is about listing database objects in dependency order
        (i.e. dependents after referenced objects). This can be useful, e.g. 
        to determine in which order to run DDL scripts to recreate a schema 
        on another database, etc. In order to do that, we use 2 sources of
        information:
            1. DBA_DEPENDENCIES
            2. DBA_CONSTRAINTS  (for foreign keys)
    
    CAVEATS
        There are several difficulties and issues here, especially:
        
        1. Not every dependency is shown in DBA_DEPENDENCIES. In particular,
           virtual column definitions referencing stored procedures are not
           listed in that view (actually; they're not listed anywhere).
           
        2. There are situations (post schema-import, mostly) when the state
           of compiled PL/SQL objects is such that not all dependencies are
           yet correctly listed in DBA_DEPENDENCIES, i.e. some dependencies
           will only be "discovered" by attempting the compilation again.
           
        3. If the notion of "dependency" is extended by adding foreign key
           relationships, as we do here, and/or virtual columns definitions
           (we won't try that), then cycles in dependency graphs may happen. 
           This may make it a lot harder to define the "right order" for running
           all the DDL scripts required for recreating all objects in a database
           or schema: if cyclic dependencies exist, then "CREATE something" DDL
           scripts run in the "right order" are not sufficient any longer: there
           must be "ALTER something" DDL scripts at some point later to account
           for the cyclic dependencies. This makes the whole "dependency order"
           idea far more complex than it would seem at first glance.
*/


/*=======================================================================================+
  Dependencies from DBA_DEPENDENCIES + foreign-keys-as-dependencies
*/

select /*+ no_parallel */
    owner,
    name,
    type,
    referenced_owner,
    referenced_name,
    referenced_type,
    null as fk_constraint
from
    dba_dependencies
where
    ( :B_OWNER_LIKE is null
      or upper(owner) like upper(:B_OWNER_LIKE)
      or upper(referenced_owner) like upper(:B_OWNER_LIKE)
    )
    and 
    ( :B_NAME_LIKE is null
      or upper(name) like upper(:B_NAME_LIKE)
      or upper(referenced_name) like upper(:B_NAME_LIKE)
    )
union
select /*+ no_parallel */
    b.owner,
    b.table_name        as name,
    nvl2(d.view_name, 
        'VIEW', 
        'TABLE')        as type,
    a.owner             as referenced_owner, 
    a.table_name        as referenced_name,
    nvl2(c.view_name, 
        'VIEW', 
        'TABLE')        as referenced_type,
    b.constraint_name   as fk_constraint
from
    dba_constraints a,
    dba_constraints b,
    dba_views c,
    dba_views d
where
    a.constraint_type in ('U', 'P')
    and b.r_owner = a.owner
    and b.r_constraint_name = a.constraint_name
    and b.constraint_type = 'R'
    and a.owner = c.owner (+)
    and a.table_name = c.view_name (+)
    and b.owner = d.owner (+)
    and b.table_name = d.view_name (+)
    and ( :B_OWNER_LIKE is null
          or upper(a.owner) like upper(:B_OWNER_LIKE)
          or upper(b.owner) like upper(:B_OWNER_LIKE)
        )
    and ( :B_NAME_LIKE is null
          or upper(a.table_name) like upper(:B_NAME_LIKE)
          or upper(b.table_name) like upper(:B_NAME_LIKE)
        )
;


/*=======================================================================================+
  Show dependency paths for each object in a schema, taking FKs into account.

  ##############################################################################
  ###  CAUTION: slow query! Consider excluding dependencies with respect to  ###
  ###  Oracle objects (owned by SYS, etc.) from the analysis if necessary.   ###
  ##############################################################################
*/ 

with
dba_views_sub as (
    select /*+ materialize */
        owner, view_name
    from
        dba_views
),
extended_dependencies as (
    select /*+ no_parallel */
        owner,
        name,
        type,
        referenced_owner,
        referenced_name,
        referenced_type
    from
        dba_dependencies
    union
    select /*+ no_parallel */
        b.owner,
        b.table_name        as name,
        nvl2(d.view_name, 
            'VIEW', 
            'TABLE')        as type,
        a.owner             as referenced_owner, 
        a.table_name        as referenced_name,
        nvl2(c.view_name, 
            'VIEW', 
            'TABLE')        as referenced_type
    from
        dba_constraints a,
        dba_constraints b,
        dba_views_sub c,
        dba_views_sub d
    where
        a.constraint_type in ('U', 'P')
        and b.r_owner = a.owner
        and b.r_constraint_name = a.constraint_name
        and b.constraint_type = 'R'
        and /* exclude FKs where child and parent are the same table */
            (a.owner <> b.owner or a.table_name <> b.table_name)
        and a.owner = c.owner (+)
        and a.table_name = c.view_name (+)
        and b.owner = d.owner (+)
        and b.table_name = d.view_name (+)
),
extended_dependencies_sub as (
    select /*+ materialize */ 
        * 
    from 
        extended_dependencies
),
first_level_obj as (
    select
        o.owner,
        o.object_name as name,
        o.object_type as type 
    from
        dba_objects o,
        dba_dependencies d
    where
        o.owner = d.owner (+)
        and o.object_name = d.name (+)
        and o.object_type = d.type (+)
        and d.owner is null
        and o.object_type not in (
            'TABLE PARTITION', 'TABLE SUBPARTITION',
            'INDEX', 'INDEX PARTITION', 'INDEX SUBPARTITION',
            'LOB', 'LOB PARTITION'
        )
        /* exclude mview container tables, except if prebuilt */
        and not exists (select 1 from dba_mviews m
                        where o.object_type = 'TABLE'
                          and m.owner = o.owner
                          and m.container_name = o.object_name
                          and m.build_mode <> 'PREBUILT')
        /* exclude mview logs */
        and not exists (select 1 from dba_mview_logs m
                        where o.object_type = 'TABLE'
                          and m.log_owner = o.owner
                          and m.log_table = o.object_name)
),
dependency_chains (
    owner,
    name,
    type,
    root_owner,
    root_name,
    root_type,
    dependency_path,
    dependency_chain_len
) as (
    select
        owner,
        name,
        type,
        owner   as root_owner,
        name    as root_name,
        type    as root_type,
        '"' || owner || '"."' || name || '" (' || type || ')'  as dependency_path,
        0       as dependency_chain_len
    from 
        first_level_obj
    union all
    select
        b.owner,
        b.name,
        b.type,
        a.root_owner,
        a.root_name,
        a.root_type,
        a.dependency_path || ' <-- "' || b.owner || '"."' 
                || b.name || '" (' || b.type || ')'         as dependency_path,
        a.dependency_chain_len + 1                          as dependency_chain_len
    from
        dependency_chains a,
        extended_dependencies_sub b
    where
        a.owner = b.referenced_owner
        and a.name = b.referenced_name
        and a.type = b.referenced_type
)
cycle owner, name, type
set is_cycle to 'Y' default 'N',
dependency_chains_out as (
    select
        owner, name, type, 
        dependency_chain_len,
        is_cycle,
        dependency_path
    from
        dependency_chains
    where
        owner = :B_OWNER
)
select
    *
from
    dependency_chains_out
order by
    max(case when is_cycle = 'N' then dependency_chain_len end) 
            over (partition by owner, name, type) asc,
    owner, type, name,
    dependency_chain_len asc
;


/*=======================================================================================+
  List objects in a schema in "dependency order", taking FKs into account.
  WARNING: please see comments on top of this file for issues.

  ##############################################################################
  ###  CAUTION: slow query! Consider excluding dependencies with respect to  ###
  ###  Oracle objects (owned by SYS, etc.) from the analysis if necessary.   ###
  ##############################################################################
*/

with
dba_views_sub as (
    select /*+ materialize */
        owner, view_name
    from
        dba_views
),
extended_dependencies as (
    select /*+ no_parallel */
        owner,
        name,
        type,
        referenced_owner,
        referenced_name,
        referenced_type
    from
        dba_dependencies
    union
    select /*+ no_parallel */
        b.owner,
        b.table_name        as name,
        nvl2(d.view_name, 
            'VIEW', 
            'TABLE')        as type,
        a.owner             as referenced_owner, 
        a.table_name        as referenced_name,
        nvl2(c.view_name, 
            'VIEW', 
            'TABLE')        as referenced_type
    from
        dba_constraints a,
        dba_constraints b,
        dba_views_sub c,
        dba_views_sub d
    where
        a.constraint_type in ('U', 'P')
        and b.r_owner = a.owner
        and b.r_constraint_name = a.constraint_name
        and b.constraint_type = 'R'
        and /* exclude FKs where child and parent are the same table */
            (a.owner <> b.owner or a.table_name <> b.table_name)
        and a.owner = c.owner (+)
        and a.table_name = c.view_name (+)
        and b.owner = d.owner (+)
        and b.table_name = d.view_name (+)
),
extended_dependencies_sub as (
    select /*+ materialize */ 
        * 
    from 
        extended_dependencies
),
first_level_obj as (
    select
        o.owner,
        o.object_name as name,
        o.object_type as type 
    from
        dba_objects o,
        dba_dependencies d
    where
        o.owner = d.owner (+)
        and o.object_name = d.name (+)
        and o.object_type = d.type (+)
        and d.owner is null
        and o.object_type not in (
            'TABLE PARTITION', 'TABLE SUBPARTITION',
            'INDEX', 'INDEX PARTITION', 'INDEX SUBPARTITION',
            'LOB', 'LOB PARTITION'
        )
        /* exclude mview container tables, except if prebuilt */
        and not exists (select 1 from dba_mviews m
                        where o.object_type = 'TABLE'
                          and m.owner = o.owner
                          and m.container_name = o.object_name
                          and m.build_mode <> 'PREBUILT')
        /* exclude mview logs */
        and not exists (select 1 from dba_mview_logs m
                        where o.object_type = 'TABLE'
                          and m.log_owner = o.owner
                          and m.log_table = o.object_name)
),
dependency_chains (
    owner,
    name,
    type,
    root_owner,
    root_name,
    root_type,
    dependency_path,
    dependency_chain_len
) as (
    select
        owner,
        name,
        type,
        owner   as root_owner,
        name    as root_name,
        type    as root_type,
        '"' || owner || '"."' || name || '" (' || type || ')'  as dependency_path,
        0       as dependency_chain_len
    from 
        first_level_obj
    union all
    select
        b.owner,
        b.name,
        b.type,
        a.root_owner,
        a.root_name,
        a.root_type,
        a.dependency_path || ' <-- "' || b.owner || '"."' 
                || b.name || '" (' || b.type || ')'         as dependency_path,
        a.dependency_chain_len + 1                          as dependency_chain_len
    from
        dependency_chains a,
        extended_dependencies_sub b
    where
        a.owner = b.referenced_owner
        and a.name = b.referenced_name
        and a.type = b.referenced_type
)
cycle owner, name, type
set is_cycle to 'Y' default 'N',
dependency_chain_groups as (
    select
        owner, name, type, 
        max(case when is_cycle = 'N' then dependency_chain_len end)  as max_chain_len,
        max(is_cycle)  as is_in_cyclic_chain,
        max(dependency_path) keep
                (dense_rank first 
                 order by (case when is_cycle = 'N' then dependency_chain_len end) 
                         desc nulls last
                )  as sample_dependancy_path,
        listagg(case when is_cycle = 'Y' then dependency_path end, chr(10)) within group 
                (order by is_cycle desc, dependency_chain_len desc)  as cyclic_path_list 
    from
        dependency_chains
    where
        owner = :B_OWNER
    group by
        owner, name, type
)
select
    *
from
    dependency_chain_groups
order by
    max_chain_len asc,
    owner, type, name
;
