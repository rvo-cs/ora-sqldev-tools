create or replace package body pkg_optim_bundle_helper as
/*
 * SPDX-FileCopyrightText: 2025 R.Vassallo
 * SPDX-License-Identifier: BSD Zero Clause License
 */

    gc_bundlefcp_dir    constant all_directories.directory_name %type := 'DBMS_OPTIM_ADMINDIR';
    gc_bundlefcp_fname  constant varchar2(50) := 'bundlefcp_DBBP.xml';

    gc_pp_indent_step     constant pls_integer := 4; 
    gc_pp_bugno_value_len constant pls_integer := 16;
    gc_pp_stmt_separator  constant varchar2(1) := ';';
    
    gc_max_fcp_in_list    constant pls_integer := 255;

    -- Forward decl.
    function normalize_bool_flag (in_arg in varchar2) return varchar2;
    function to_tab_fixctl (in_fcp_list in sys.odcivarchar2list) return tab_fixctl;
    function exists_session(in_inst_id in number, in_session_id in number, 
            in_session_serial# in number default null) return boolean;

    function optim_bundle_fixes_tab(in_bundle_id in number default null) 
    return t_bundlefcp
    is
        l_bundlefcp_bfile bfile;
        l_bundlefcp_clob  clob;
        l_src_pos         number;
        l_dst_pos         number;
        l_lang_ctx        number;
        l_warning_indic   number;

        l_tab_bundlefcp   t_bundlefcp;
    begin
        l_bundlefcp_bfile := bfilename(gc_bundlefcp_dir, gc_bundlefcp_fname);
        dbms_lob.open(l_bundlefcp_bfile);
        
        dbms_lob.createtemporary(l_bundlefcp_clob, cache => true, dur => dbms_lob.session);

        l_src_pos := 1;
        l_dst_pos := 1;
        l_lang_ctx := dbms_lob.default_lang_ctx;

        dbms_lob.loadclobfromfile(
            src_bfile    => l_bundlefcp_bfile,
            dest_lob     => l_bundlefcp_clob,
            amount       => dbms_lob.getlength(l_bundlefcp_bfile),
            src_offset   => l_src_pos,
            dest_offset  => l_dst_pos, 
            bfile_csid   => nls_charset_id('UTF8'),
            lang_context => l_lang_ctx, 
            warning      => l_warning_indic
        );
        
        dbms_lob.close(l_bundlefcp_bfile);

        select
            fcp.bundle_id, 
            fcp.description, 
            fcp.bug_id, 
            fcp.fix_control, 
            fcp.bundle_value
        bulk collect into l_tab_bundlefcp
        from
            xmltable(
                '/bundlefcp/bundle/fcbuglist/bug/fix_control' 
                passing xmlparse(document l_bundlefcp_clob)
                returning sequence by ref
                columns
                    bundle_id    number         path '../../../@id',
                    description  varchar2(50)   path '../../../@description',
                    bug_id       number         path '../@id',
                    fix_control  number         path './text()',
                    bundle_value number         path './@default_value'
            ) fcp
        where
            in_bundle_id is null
            or fcp.bundle_id <= in_bundle_id
        order by
            fcp.bundle_id,
            fcp.bug_id;
            
        dbms_lob.freetemporary(l_bundlefcp_clob);
        
        return l_tab_bundlefcp;
    end optim_bundle_fixes_tab;
    

    function optim_bundle_fixes(in_bundle_id in number default null) return t_bundlefcp
    pipelined
    is
        l_tab_bundlefcp t_bundlefcp;
    begin
        l_tab_bundlefcp := optim_bundle_fixes_tab(in_bundle_id);
        if l_tab_bundlefcp is not null then
            for i in 1 .. l_tab_bundlefcp.count loop
                pipe row(l_tab_bundlefcp(i));
            end loop;
        end if;
    end optim_bundle_fixes;


    function cmp_sysfc_spfile (
        in_bundle_id in number default null     -- target bundle-id level
    )
    return t_cmp_sysfc_spp
    pipelined
    is
        cursor c_cmp_sysfc_spfile (
            in_bundle_id         in  number, 
            in_tab_optim_bundle  in  t_bundlefcp
        ) is
            with
            fc_spfile_instances as (
                /* Parameter values set for specific instances in the spfile
                   take precedence over values specified for all instances */
                select
                    ins.inst_id,
                    spp.name,
                    nvl(max(spp.sid) keep (dense_rank first
                            order by decode(ins.instance_name, spp.sid, 0, 1)), '*') as sid
                from
                    gv$instance ins
                    left outer join
                    gv$spparameter spp on
                        spp.inst_id = ins.inst_id
                        and spp.name in ('_fix_control', '_fix_control_1', '_fix_control_2', '_fix_control_3',
                                         '_fix_control_4', '_fix_control_5', '_fix_control_6', '_fix_control_7',
                                         '_fix_control_8', '_fix_control_9')
                        and spp.isspecified = 'TRUE'
                        and spp.ordinal in (0, 1)
                            /* ordinal starts at 1 for each SID, unless the 
                               instance was not started using a spfile */
                group by
                    ins.inst_id,
                    spp.name
            ),
            fc_spfile_param as (
                select
                    inst_id,
                    sid,
                    con_id,  /* note: con_id is always the current container here */
                    to_number(fc_bugno_vc2)  as bugno,
                    case 
                        when UPPER(fc_value_vc2) = 'ON' then
                            1
                        when UPPER(fc_value_vc2) = 'OFF' then
                            0
                        else
                            to_number(fc_value_vc2)
                    end as value,
                    display_value,
                    ordinal,
                    update_comment
                from    
                    (select
                        sp.inst_id,
                        sp.sid,
                        sp.con_id,
                        substr(sp.value, 1, instr(sp.value, ':') - 1) as fc_bugno_vc2,
                        substr(sp.value, instr(sp.value, ':') + 1)    as fc_value_vc2,
                        sp.display_value,
                        sp.ordinal,
                        max(sp.update_comment) over (
                                partition by
                                    sp.inst_id,
                                    sp.con_id,
                                    sp.name
                            ) as update_comment,
                        row_number() over (
                                partition by
                                    sp.inst_id, 
                                    sp.con_id, 
                                    substr(sp.value, 1, instr(sp.value, ':') - 1)
                                order by 
                                    /* highest (name, ordinal) "wins" */
                                    sp.name desc,
                                    sp.ordinal desc
                            ) as rn
                    from
                        gv$spparameter sp
                        inner join
                        fc_spfile_instances fi on
                            sp.inst_id = fi.inst_id
                            and sp.name = fi.name
                            and sp.sid = fi.sid
                    where
                        sp.name in ('_fix_control', '_fix_control_1', '_fix_control_2', '_fix_control_3',
                                    '_fix_control_4', '_fix_control_5', '_fix_control_6', '_fix_control_7',
                                    '_fix_control_8', '_fix_control_9')
                        and sp.isspecified = 'TRUE'
                        and sp.ordinal > 0   /* ordinal is equal to 0 if the instance
                                                was not started using a spfile */
                    )
                where
                    rn = 1
            ),
            all_system_fc as (
                select
                    fc.inst_id,
                    fc.con_id,
                    fc.bugno,
                    fc.value,
                    fc.is_default,
                    fc.optimizer_feature_enable,
                    fc.sql_feature,
                    fc.description
                from 
                    gv$system_fix_control fc
                where
                    fc.con_id = to_number(sys_context('USERENV', 'CON_ID'))  
                        /* always true; added just in case */
            ),
            all_optim_bundle_fcp as (
                select
                    bu.fix_control_id,
                    bu.bug_id,
                    bu.bundle_value,
                    bu.bundle_id,
                    bu.bundle_description
                from
                    table(in_tab_optim_bundle) bu
            )
            select
                coalesce(spp.inst_id, afc.inst_id)  as inst_id,
                coalesce(spp.con_id, afc.con_id)    as con_id,
                coalesce(spp.bugno, afc.bugno)      as bugno,
                afc.is_default,
                afc.value                           as sysfc_value,
                spp.value                           as spfile_value,
                obu.bundle_value,
                case
                    when afc.value = spp.value then
                        'YES'
                    when afc.value <> spp.value then
                        'NO'
                    when spp.value is null and afc.is_default = 1 then
                        'YES (absent param.)'
                    when spp.value is null and afc.is_default = 0 then
                        'NO (missing param.)'
                end                                 as spp_eq_sysfc,
                case
                    when obu.bundle_id is not null then
                        case
                            when spp.value = obu.bundle_value then
                                'YES'
                            when spp.value <> obu.bundle_value then
                                'NO'
                            when spp.value is null and afc.is_default = 1 
                                and afc.value = obu.bundle_value
                            then
                                'YES (absent param.)'
                            when spp.value is null and afc.is_default = 1 
                                and afc.value <> obu.bundle_value
                            then
                                'NO (absent param.)'
                            when spp.value is null and afc.is_default = 0 then
                                'UNKNOWN (missing param.)'
                        end
                    else
                        'N/A'
                end                                 as spp_eq_bundle,
                case
                    when obu.fix_control_id is not null 
                        and obu.bundle_id > in_bundle_id 
                    then
                        obu.bundle_id
                end                                 as hi_bundle_ind,
                spp.sid                             as spfile_sid,
                spp.display_value                   as spfile_display_value,
                spp.update_comment,
                afc.optimizer_feature_enable,
                afc.sql_feature,
                afc.description,
                obu.bundle_id,
                obu.bundle_description              as bundle_descr,
                obu.bug_id
            from 
                fc_spfile_param spp
                full outer join
                all_system_fc afc on
                    afc.inst_id = spp.inst_id
                    and afc.bugno = spp.bugno
                left outer join
                all_optim_bundle_fcp obu on
                    obu.fix_control_id = afc.bugno
            where
                spp.bugno is not null 
                or afc.is_default = 0
                or obu.bundle_id <= nvl(in_bundle_id, 99999999)
            order by
                coalesce(spp.bugno, afc.bugno),
                coalesce(spp.con_id, afc.con_id),
                coalesce(spp.inst_id, afc.inst_id);
            
        l_tab_sysfc_spfile t_cmp_sysfc_spp;
    begin
        open c_cmp_sysfc_spfile(in_bundle_id, optim_bundle_fixes_tab);
        fetch c_cmp_sysfc_spfile bulk collect into l_tab_sysfc_spfile;
        close c_cmp_sysfc_spfile;
        if l_tab_sysfc_spfile is not null then
            for i in 1 .. l_tab_sysfc_spfile.count loop
                pipe row(l_tab_sysfc_spfile(i));
            end loop;
        end if;
    end cmp_sysfc_spfile;
    

    function cmp_sysfc_syspar (
        in_bundle_id in number default null     -- target bundle-id level
    )
    return t_cmp_sysfc_syspar
    pipelined
    is
        cursor c_cmp_sysfc_syspar (
            in_bundle_id         in  number,
            in_tab_optim_bundle  in  t_bundlefcp
        )
        is
            with
            fc_system_parameter as (
                /* _fix_control params for the current container */
                select
                    inst_id,
                    con_id,  /* con_id is the originating container of this parameter */
                    to_number(fc_bugno_vc2)  as bugno,
                    case 
                        when UPPER(fc_value_vc2) = 'ON' then
                            1
                        when UPPER(fc_value_vc2) = 'OFF' then
                            0
                        else
                            to_number(fc_value_vc2)
                    end as value,
                    display_value,
                    ordinal,
                    ismodified,
                    update_comment
                from    
                    (select
                        sy2.inst_id,
                        sy2.con_id,
                        substr(sy2.value, 1, instr(sy2.value, ':') - 1) as fc_bugno_vc2,
                        substr(sy2.value, instr(sy2.value, ':') + 1)    as fc_value_vc2,
                        sy2.display_value,
                        sy2.ordinal,
                        sy2.ismodified,
                        sy2.update_comment,
                        row_number() over (
                                partition by 
                                    sy2.inst_id,
                                    sy2.con_id, 
                                    substr(sy2.value, 1, instr(sy2.value, ':') - 1)
                                order by 
                                    /* highest (name, ordinal) "wins" */
                                    sy2.name desc,
                                    sy2.ordinal desc
                            ) as rn
                    from
                        (select
                            sy0.inst_id,
                            sy0.con_id,
                            sy0.name,
                            row_number() over (partition by sy0.inst_id, sy0.name order by sy0.con_id desc) as rn0
                        from
                            gv$system_parameter sy0
                        where 
                            sy0.name in ('_fix_control', '_fix_control_1', '_fix_control_2', '_fix_control_3',
                                     '_fix_control_4', '_fix_control_5', '_fix_control_6', '_fix_control_7',
                                     '_fix_control_8', '_fix_control_9')
                            and ( /* parameters applicable to the current container */
                                  sy0.con_id = 0 
                                  or sy0.con_id = sys_context('USERENV', 'CON_ID') )
                        ) sy,
                        gv$system_parameter2 sy2
                    where
                        sy.rn0 = 1  /* probably unnecessary; added just in case */
                        and sy2.inst_id = sy.inst_id
                        and sy2.con_id = sy.con_id
                        and sy2.name = sy.name
                    )
                where
                    rn = 1
            ),
            all_system_fc as (
                select
                    fc.inst_id,
                    fc.con_id,
                    fc.bugno,
                    fc.value,
                    fc.is_default,
                    fc.optimizer_feature_enable,
                    fc.sql_feature,
                    fc.description
                from 
                    gv$system_fix_control fc
                where
                    fc.con_id = to_number(sys_context('USERENV', 'CON_ID'))
                        /* always true; added just in case */
            ),
            all_optim_bundle_fcp as (
                select
                    bu.fix_control_id,
                    bu.bug_id,
                    bu.bundle_value,
                    bu.bundle_id,
                    bu.bundle_description
                from
                    table(in_tab_optim_bundle) bu
            )
            select
                coalesce(par.inst_id, afc.inst_id)  as inst_id,
                coalesce(par.con_id, afc.con_id)    as con_id,
                coalesce(par.bugno, afc.bugno)      as bugno,
                afc.is_default,
                afc.value                           as sysfc_value,
                par.value                           as syspar_value,
                obu.bundle_value,
                case
                    when afc.value = par.value then
                        'YES'
                    when afc.value <> par.value then
                        'NO'
                    when par.value is null and afc.is_default = 1 then
                        'YES (absent param.)'
                    when par.value is null and afc.is_default = 0 then
                        'NO (missing param.)'
                end                                 as syspar_eq_sysfc,
                case
                    when obu.bundle_id is not null then
                        case
                            when par.value = obu.bundle_value then
                                'YES'
                            when par.value <> obu.bundle_value then
                                'NO'
                            when par.value is null and afc.is_default = 1 
                                and afc.value = obu.bundle_value
                            then
                                'YES (absent param.)'
                            when par.value is null and afc.is_default = 1 
                                and afc.value <> obu.bundle_value
                            then
                                'NO (absent param.)'
                            when par.value is null and afc.is_default = 0 then
                                'UNKNOWN (missing param.)'
                        end
                    else
                        'N/A'
                end                                 as syspar_eq_bundle,
                case
                    when obu.fix_control_id is not null 
                        and obu.bundle_id > in_bundle_id 
                    then
                        obu.bundle_id
                end                                 as hi_bundle_ind,
                par.display_value                   as syspar_display_value,
                par.ismodified                      as syspar_ismodified,
                par.update_comment,
                afc.optimizer_feature_enable,
                afc.sql_feature,
                afc.description,
                obu.bundle_id,
                obu.bundle_description              as bundle_descr,
                obu.bug_id
            from 
                fc_system_parameter par
                full outer join
                all_system_fc afc on
                    afc.inst_id = par.inst_id
                    and afc.bugno = par.bugno
                left join
                all_optim_bundle_fcp obu on
                    obu.fix_control_id = afc.bugno
            where
                par.bugno is not null 
                or afc.is_default = 0
                or obu.bundle_id <= nvl(in_bundle_id, 99999999)
            order by
                coalesce(par.bugno, afc.bugno),
                coalesce(par.con_id, afc.con_id),
                coalesce(par.inst_id, afc.inst_id);
        
        l_tab_sysfc_syspar t_cmp_sysfc_syspar;
    begin
        open c_cmp_sysfc_syspar(in_bundle_id, optim_bundle_fixes_tab);
        fetch c_cmp_sysfc_syspar bulk collect into l_tab_sysfc_syspar;
        close c_cmp_sysfc_syspar;
        if l_tab_sysfc_syspar is not null then
            for i in 1 .. l_tab_sysfc_syspar.count loop
                pipe row(l_tab_sysfc_syspar(i));
            end loop;
        end if;
    end cmp_sysfc_syspar;
    

    function cmp_spfile_syspar (
        in_bundle_id in number default null     -- target bundle-id level
    )
    return t_cmp_spp_syspar
    pipelined
    is
        cursor c_cmp_spp_syspar (
            in_bundle_id         in  number,
            in_tab_optim_bundle  in  t_bundlefcp
        )
        is
            with
            fc_spfile_instances as (
                /* Parameter values set for specific instances in the spfile
                   take precedence over values specified for all instances */
                select
                    ins.inst_id,
                    spp.name,
                    nvl(max(spp.sid) keep (dense_rank first
                            order by decode(ins.instance_name, spp.sid, 0, 1)), '*') as sid
                from
                    gv$instance ins
                    left outer join
                    gv$spparameter spp on
                        spp.inst_id = ins.inst_id
                        and spp.name in ('_fix_control', '_fix_control_1', '_fix_control_2', '_fix_control_3',
                                         '_fix_control_4', '_fix_control_5', '_fix_control_6', '_fix_control_7',
                                         '_fix_control_8', '_fix_control_9')
                        and spp.isspecified = 'TRUE'
                        and spp.ordinal in (0, 1)
                            /* ordinal starts at 1 for each SID, unless the 
                               instance was not started using a spfile */
                group by
                    ins.inst_id,
                    spp.name
            ),
            fc_spfile_param as (
                select
                    inst_id,
                    sid,
                    con_id,  /* note: con_id is always the current container here */
                    to_number(fc_bugno_vc2)  as bugno,
                    case 
                        when UPPER(fc_value_vc2) = 'ON' then
                            1
                        when UPPER(fc_value_vc2) = 'OFF' then
                            0
                        else
                            to_number(fc_value_vc2)
                    end as value,
                    display_value,
                    ordinal,
                    update_comment
                from    
                    (select
                        sp.inst_id,
                        sp.sid,
                        sp.con_id,
                        substr(sp.value, 1, instr(sp.value, ':') - 1) as fc_bugno_vc2,
                        substr(sp.value, instr(sp.value, ':') + 1)    as fc_value_vc2,
                        sp.display_value,
                        sp.ordinal,
                        max(sp.update_comment) over (
                                partition by
                                    sp.inst_id,
                                    sp.con_id,
                                    sp.name
                            ) as update_comment,
                        row_number() over (
                                partition by
                                    sp.inst_id, 
                                    sp.con_id, 
                                    substr(sp.value, 1, instr(sp.value, ':') - 1)
                                order by 
                                    /* highest (name, ordinal) "wins" */
                                    sp.name desc,
                                    sp.ordinal desc
                            ) as rn
                    from
                        gv$spparameter sp
                        inner join
                        fc_spfile_instances fi on
                            sp.inst_id = fi.inst_id
                            and sp.name = fi.name
                            and sp.sid = fi.sid
                    where
                        sp.name in ('_fix_control', '_fix_control_1', '_fix_control_2', '_fix_control_3',
                                    '_fix_control_4', '_fix_control_5', '_fix_control_6', '_fix_control_7',
                                    '_fix_control_8', '_fix_control_9')
                        and sp.isspecified = 'TRUE'
                        and sp.ordinal > 0   /* ordinal is equal to 0 if the instance
                                                was not started using a spfile */
                    )
                where
                    rn = 1
            ),
            fc_system_parameter as (
                /* _fix_control params for the current container */
                select
                    inst_id,
                    con_id,  /* con_id is the originating container of this parameter */
                    to_number(fc_bugno_vc2)  as bugno,
                    case 
                        when UPPER(fc_value_vc2) = 'ON' then
                            1
                        when UPPER(fc_value_vc2) = 'OFF' then
                            0
                        else
                            to_number(fc_value_vc2)
                    end as value,
                    display_value,
                    ordinal,
                    ismodified,
                    update_comment
                from    
                    (select
                        sy2.inst_id,
                        sy2.con_id,
                        substr(sy2.value, 1, instr(sy2.value, ':') - 1) as fc_bugno_vc2,
                        substr(sy2.value, instr(sy2.value, ':') + 1)    as fc_value_vc2,
                        sy2.display_value,
                        sy2.ordinal,
                        sy2.ismodified,
                        sy2.update_comment,
                        row_number() over (
                                partition by 
                                    sy2.inst_id,
                                    sy2.con_id, 
                                    substr(sy2.value, 1, instr(sy2.value, ':') - 1)
                                order by 
                                    /* highest (name, ordinal) "wins" */
                                    sy2.name desc,
                                    sy2.ordinal desc
                            ) as rn
                    from
                        (select
                            sy0.inst_id,
                            sy0.con_id,
                            sy0.name,
                            row_number() over (partition by sy0.inst_id, sy0.name order by sy0.con_id desc) as rn0
                        from
                            gv$system_parameter sy0
                        where 
                            sy0.name in ('_fix_control', '_fix_control_1', '_fix_control_2', '_fix_control_3',
                                     '_fix_control_4', '_fix_control_5', '_fix_control_6', '_fix_control_7',
                                     '_fix_control_8', '_fix_control_9')
                            and ( /* parameters applicable to the current container */
                                  sy0.con_id = 0 
                                  or sy0.con_id = sys_context('USERENV', 'CON_ID') )
                        ) sy,
                        gv$system_parameter2 sy2
                    where
                        sy.rn0 = 1  /* probably unnecessary; added just in case */
                        and sy2.inst_id = sy.inst_id
                        and sy2.con_id = sy.con_id
                        and sy2.name = sy.name
                    )
                where
                    rn = 1
            ),
            all_system_fc as (
                select
                    fc.inst_id,
                    fc.con_id,
                    fc.bugno,
                    fc.value,
                    fc.is_default,
                    fc.optimizer_feature_enable,
                    fc.sql_feature,
                    fc.description
                from 
                    gv$system_fix_control fc
                where
                    fc.con_id = to_number(sys_context('USERENV', 'CON_ID'))
                        /* always true; added just in case */
            ),
            all_optim_bundle_fcp as (
                select
                    bu.fix_control_id,
                    bu.bug_id,
                    bu.bundle_value,
                    bu.bundle_id,
                    bu.bundle_description
                from
                    table(in_tab_optim_bundle) bu
            )
            select
                coalesce(spp.inst_id, par.inst_id, afc.inst_id)     as inst_id,
                coalesce(spp.con_id, par.con_id, afc.con_id)        as con_id,
                coalesce(spp.bugno, par.bugno, obu.fix_control_id)  as bugno,
                spp.value                                           as spfile_value,
                par.value                                           as syspar_value,
                obu.bundle_value,
                case
                    when spp.value = par.value then
                        'YES'
                    when spp.value <> par.value then
                        'NO'
                    when par.value is null and spp.value is not null then
                        'NO (absent in memory)'
                    when par.value is not null and spp.value is null then
                        'NO (absent in spfile)'
                    when par.value is null and spp.value is null then
                        'YES (absent in both)'
                end                                 as spfile_eq_syspar,
                case
                    when obu.bundle_id is not null then
                        case
                            when par.value = obu.bundle_value then
                                'YES'
                            when par.value <> obu.bundle_value then
                                'NO'
                            when par.value is null and afc.is_default = 1
                                and afc.value = obu.bundle_value
                            then
                                'YES (absent param.)'
                            when par.value is null and afc.is_default = 1
                                and afc.value <> obu.bundle_value
                            then
                                'NO (absent param.)'
                            when par.value is null and afc.is_default = 0 then
                                'UNKNOWN (missing param.)'
                        end
                    else
                        'N/A'
                end                                 as syspar_eq_bundle,
                case
                    when obu.bundle_id is not null then
                        case
                            when spp.value = obu.bundle_value then
                                'YES'
                            when spp.value <> obu.bundle_value then
                                'NO'
                            when spp.value is null and afc.is_default = 1
                                and afc.value = obu.bundle_value
                            then
                                'YES (absent param.)'
                            when spp.value is null and afc.is_default = 1
                                and afc.value <> obu.bundle_value
                            then
                                'NO (absent param.)'
                            when spp.value is null and afc.is_default = 0 then
                                'UNKNOWN (missing param.)'
                        end
                    else
                        'N/A'
                end                                 as spfile_eq_bundle,
                case
                    when obu.fix_control_id is not null 
                        and obu.bundle_id > in_bundle_id 
                    then
                        obu.bundle_id
                end                                 as hi_bundle_ind,
                spp.sid                             as spfile_sid,
                spp.display_value                   as spfile_display_value,
                par.display_value                   as syspar_display_value,
                par.ismodified                      as syspar_ismodified,
                spp.update_comment                  as spfile_update_comment,
                par.update_comment                  as syspar_update_comment,
                obu.bundle_id,
                obu.bundle_description              as bundle_descr,
                obu.bug_id
            from
                fc_spfile_param spp
                full outer join
                fc_system_parameter par on
                    par.inst_id = spp.inst_id
                    and par.bugno = spp.bugno
                full outer join
                all_system_fc afc on 
                    afc.inst_id = coalesce(spp.inst_id, par.inst_id)
                    and afc.bugno = coalesce(spp.bugno, par.bugno)
                full outer join
                all_optim_bundle_fcp obu on
                    obu.fix_control_id = coalesce(spp.bugno, par.bugno, afc.bugno)
            where
                spp.bugno is not null
                or par.bugno is not null
                or obu.bundle_id <= nvl(in_bundle_id, 99999999)
            order by
                coalesce(spp.bugno, par.bugno, obu.fix_control_id),
                coalesce(spp.con_id, par.con_id, afc.con_id),
                coalesce(spp.inst_id, par.inst_id, afc.inst_id);
                    
        l_tab_spp_syspar t_cmp_spp_syspar;
    begin
        open c_cmp_spp_syspar(in_bundle_id, optim_bundle_fixes_tab);
        fetch c_cmp_spp_syspar bulk collect into l_tab_spp_syspar;
        close c_cmp_spp_syspar;
        if l_tab_spp_syspar is not null then
            for i in 1 .. l_tab_spp_syspar.count loop
                pipe row(l_tab_spp_syspar(i));
            end loop;
        end if;
    end cmp_spfile_syspar;
    

    function cmp_sesfc_sespar (
        in_bundle_id in number default null     -- target bundle-id level
    )
    return t_cmp_sesfc_sespar
    pipelined
    is
        cursor c_cmp_sesfc_sespar (
            in_bundle_id         in  number,
            in_tab_optim_bundle  in  t_bundlefcp
        )
        is
            with
            fc_session_parameter as (
                select
                    inst_id,
                    sid,
                    con_id,
                    to_number(fc_bugno_vc2)  as bugno,
                    case 
                        when UPPER(fc_value_vc2) = 'ON' then
                            1
                        when UPPER(fc_value_vc2) = 'OFF' then
                            0
                        else
                            to_number(fc_value_vc2)
                    end as value,
                    display_value,
                    ordinal,
                    ismodified,
                    update_comment
                from
                    (select
                        inst_id,
                        to_number(sys_context('USERENV', 'SID')) as sid,
                        con_id,
                        substr(value, 1, instr(value, ':') - 1) as fc_bugno_vc2,
                        substr(value, instr(value, ':') + 1)    as fc_value_vc2,
                        display_value,
                        ordinal,
                        ismodified,
                        update_comment,
                        row_number() over (
                                partition by
                                    inst_id,
                                    con_id,
                                    substr(value, 1, instr(value, ':') - 1)
                                order by
                                    /* highest (name, ordinal) "wins" */
                                    name desc,
                                    ordinal desc
                            ) as rn
                    from
                        gv$parameter2
                    where
                        name in ('_fix_control', '_fix_control_1', '_fix_control_2', '_fix_control_3',
                                 '_fix_control_4', '_fix_control_5', '_fix_control_6', '_fix_control_7',
                                 '_fix_control_8', '_fix_control_9')
                    )
                where
                    rn = 1
            ),
            session_fc as (
                select
                    fc.inst_id,
                    fc.session_id,
                    fc.con_id,
                    fc.bugno,
                    fc.value,
                    fc.is_default,
                    fc.optimizer_feature_enable,
                    fc.sql_feature,
                    fc.description
                from 
                    gv$session_fix_control fc
                where
                    fc.inst_id = sys_context('USERENV', 'INSTANCE')
                    and fc.session_id = sys_context('USERENV', 'SID')
            ),
            all_optim_bundle_fcp as (
                select
                    bu.fix_control_id,
                    bu.bug_id,
                    bu.bundle_value,
                    bu.bundle_id,
                    bu.bundle_description
                from
                    table(in_tab_optim_bundle) bu
            )
            select
                coalesce(par.inst_id, sfc.inst_id)  as inst_id,
                coalesce(par.sid, sfc.session_id)   as session_id,
                coalesce(par.con_id, sfc.con_id)    as con_id,
                coalesce(par.bugno, sfc.bugno)      as bugno,
                sfc.is_default,
                sfc.value                           as sesfc_value,
                par.value                           as sespar_value,
                obu.bundle_value,
                case
                    when sfc.value = par.value then
                        'YES'
                    when sfc.value <> par.value then
                        'NO'
                    when par.value is null and sfc.is_default = 1 then
                        'YES (absent param.)'
                    when par.value is null and sfc.is_default = 0 then
                        'NO (missing param.)'
                end                                 as sespar_eq_sesfc,
                case
                    when obu.bundle_id is not null then
                        case
                            when par.value = obu.bundle_value then
                                'YES'
                            when par.value <> obu.bundle_value then
                                'NO'
                            when par.value is null and sfc.is_default = 1
                                and sfc.value = obu.bundle_value
                            then
                                'YES (absent param.)'
                            when par.value is null and sfc.is_default = 1
                                and sfc.value <> obu.bundle_value
                            then
                                'NO (absent param.)'
                            when par.value is null and sfc.is_default = 0 then
                                'UNKNOWN (missing param.)'
                        end
                    else
                        'N/A'
                end                                 as sespar_eq_bundle,
                case
                    when obu.fix_control_id is not null 
                        and obu.bundle_id > in_bundle_id 
                    then
                        obu.bundle_id
                end                                 as hi_bundle_ind,
                par.display_value                   as sespar_display_value,
                par.ismodified                      as sespar_ismodified,
                par.update_comment,
                sfc.optimizer_feature_enable,
                sfc.sql_feature,
                sfc.description,
                obu.bundle_id,
                obu.bundle_description              as bundle_descr,
                obu.bug_id
            from 
                fc_session_parameter par
                full outer join
                session_fc sfc on
                    sfc.bugno = par.bugno
                left join
                all_optim_bundle_fcp obu on
                    obu.fix_control_id = sfc.bugno
            where
                par.bugno is not null 
                or sfc.is_default = 0
                or obu.bundle_id <= nvl(in_bundle_id, 99999999)
            order by
                coalesce(par.bugno, sfc.bugno);
    
        l_tab_sesfc_sespar t_cmp_sesfc_sespar;
    begin
        open c_cmp_sesfc_sespar(in_bundle_id, optim_bundle_fixes_tab);
        fetch c_cmp_sesfc_sespar bulk collect into l_tab_sesfc_sespar;
        close c_cmp_sesfc_sespar;
        if l_tab_sesfc_sespar is not null then
            for i in 1 .. l_tab_sesfc_sespar.count loop
                pipe row(l_tab_sesfc_sespar(i));
            end loop;
        end if;
    end cmp_sesfc_sespar;
    

    function cmp_sesfc_syspar (
        in_inst_id          in number       -- target session: instance
                            default sys_context('USERENV', 'INSTANCE'),
        in_session_id       in number       -- target session: sid
                            default sys_context('USERENV', 'SID'),
        in_session_serial#  in number       -- target session: serial#
                            default null,
        in_bundle_id        in number       -- target bundle-id level
                            default null
    )
    return t_cmp_sesfc_syspar
    pipelined
    is
        cursor c_cmp_sesfc_syspar (
            in_inst_id           in  number,
            in_session_id        in  number,
            in_session_serial#   in  number,
            in_bundle_id         in  number,
            in_tab_optim_bundle  in  t_bundlefcp
        )
        is
            with
            fc_system_parameter as (
                /* _fix_control params for the target instance, container */
                select
                    inst_id,
                    con_id,  /* con_id is the originating container of this parameter */
                    to_number(fc_bugno_vc2)  as bugno,
                    case 
                        when UPPER(fc_value_vc2) = 'ON' then
                            1
                        when UPPER(fc_value_vc2) = 'OFF' then
                            0
                        else
                            to_number(fc_value_vc2)
                    end as value,
                    display_value,
                    ordinal,
                    ismodified,
                    update_comment
                from    
                    (select
                        sy2.inst_id,
                        sy2.con_id,
                        substr(sy2.value, 1, instr(sy2.value, ':') - 1) as fc_bugno_vc2,
                        substr(sy2.value, instr(sy2.value, ':') + 1)    as fc_value_vc2,
                        sy2.display_value,
                        sy2.ordinal,
                        sy2.ismodified,
                        sy2.update_comment,
                        row_number() over (
                                partition by 
                                    sy2.inst_id,
                                    sy2.con_id, 
                                    substr(sy2.value, 1, instr(sy2.value, ':') - 1)
                                order by 
                                    /* highest (name, ordinal) "wins" */
                                    sy2.name desc,
                                    sy2.ordinal desc
                            ) as rn
                    from
                        (select
                            sy0.inst_id,
                            sy0.con_id,
                            sy0.name,
                            row_number() over (partition by sy0.inst_id, sy0.name order by sy0.con_id desc) as rn0
                        from
                            gv$system_parameter sy0
                        where 
                            sy0.inst_id = in_inst_id
                            and sy0.name in ('_fix_control', '_fix_control_1', '_fix_control_2', '_fix_control_3',
                                             '_fix_control_4', '_fix_control_5', '_fix_control_6', '_fix_control_7',
                                             '_fix_control_8', '_fix_control_9')
                            and ( /* parameters applicable to the target container */
                                  sy0.con_id = 0
                                  or sy0.con_id = (select
                                                       ses.con_id 
                                                   from 
                                                       gv$session ses
                                                   where 
                                                       ses.inst_id = in_inst_id 
                                                       and ses.sid = in_session_id
                                                       and ses.serial# = nvl(in_session_serial#, ses.serial#))
                                )
                        ) sy,
                        gv$system_parameter2 sy2
                    where
                        sy.rn0 = 1  /* probably unnecessary; added just in case */
                        and sy2.inst_id = sy.inst_id
                        and sy2.con_id = sy.con_id
                        and sy2.name = sy.name
                    )
                where
                    rn = 1
            ),
            target_session_fc as (
                select
                    fc.inst_id,
                    fc.con_id,
                    fc.bugno,
                    fc.value,
                    fc.is_default,
                    fc.optimizer_feature_enable,
                    fc.sql_feature,
                    fc.description
                from
                    gv$session ses,
                    gv$session_fix_control fc
                where
                    ses.inst_id = in_inst_id
                    and ses.sid = in_session_id
                    and ses.serial# = nvl(in_session_serial#, ses.serial#)
                    and fc.inst_id = ses.inst_id
                    and fc.session_id = ses.sid
            ),
            all_optim_bundle_fcp as (
                select
                    bu.fix_control_id,
                    bu.bug_id,
                    bu.bundle_value,
                    bu.bundle_id,
                    bu.bundle_description
                from
                    table(in_tab_optim_bundle) bu
            )
            select
                coalesce(par.inst_id, sfc.inst_id)  as inst_id,
                in_session_id                       as session_id,
                coalesce(par.con_id, sfc.con_id)    as con_id,
                coalesce(par.bugno, sfc.bugno)      as bugno,
                sfc.is_default,
                sfc.value                           as sessfc_value,
                par.value                           as syspar_value,
                obu.bundle_value,
                case
                    when sfc.value = par.value then
                        'YES'
                    when sfc.value <> par.value then
                        'NO'
                    when par.value is null and sfc.is_default = 1 then
                        'YES (absent param.)'
                    when par.value is null and sfc.is_default = 0 then
                        'NO (missing param.)'
                end                                 as syspar_eq_sesfc,
                case
                    when obu.bundle_id is not null then
                        case
                            when par.value = obu.bundle_value then
                                'YES'
                            when par.value <> obu.bundle_value then
                                'NO'
                            when par.value is null and sfc.is_default = 1
                                and sfc.value = obu.bundle_value
                            then
                                'YES (absent param.)'
                            when par.value is null and sfc.is_default = 1
                                and sfc.value <> obu.bundle_value
                            then
                                'NO (absent param.)'
                            when par.value is null and sfc.is_default = 0 then
                                'UNKNOWN (missing param.)'
                        end
                    else
                        'N/A'
                end                                 as syspar_eq_bundle,
                case
                    when obu.fix_control_id is not null 
                        and obu.bundle_id > in_bundle_id 
                    then
                        obu.bundle_id
                end                                 as hi_bundle_ind,
                par.display_value                   as syspar_display_value,
                par.ismodified                      as syspar_ismodified,
                par.update_comment,
                sfc.optimizer_feature_enable,
                sfc.sql_feature,
                sfc.description,
                obu.bundle_id,
                obu.bundle_description              as bundle_descr,
                obu.bug_id
            from 
                fc_system_parameter par
                full outer join
                target_session_fc sfc on
                    sfc.bugno = par.bugno
                left join
                all_optim_bundle_fcp obu on
                    obu.fix_control_id = coalesce(par.bugno, sfc.bugno)
            where
                par.bugno is not null 
                or sfc.is_default = 0
                or obu.bundle_id <= nvl(in_bundle_id, 99999999)
            order by
                coalesce(par.bugno, sfc.bugno);
    
        l_tab_sesfc_syspar t_cmp_sesfc_syspar;
    begin
        open c_cmp_sesfc_syspar(
            in_inst_id          => in_inst_id,
            in_session_id       => in_session_id,
            in_session_serial#  => in_session_serial#,
            in_bundle_id        => in_bundle_id,
            in_tab_optim_bundle => optim_bundle_fixes_tab
        );
        fetch c_cmp_sesfc_syspar bulk collect into l_tab_sesfc_syspar;
        close c_cmp_sesfc_syspar;
        if l_tab_sesfc_syspar is not null then
            for i in 1 .. l_tab_sesfc_syspar.count loop
                pipe row(l_tab_sesfc_syspar(i));
            end loop;
        end if;
    end cmp_sesfc_syspar;


    function report_sesfc (
        in_inst_id                in number         -- target session: instance
                                  default sys_context('USERENV', 'INSTANCE'),
        in_session_id             in number         -- target session: sid
                                  default sys_context('USERENV', 'SID'),
        in_session_serial#        in number         -- target session: serial# (optional)
                                  default null,
        in_bundle_id              in number         -- target bundle-id level
                                  default null,
        in_enable_optim_bundle    in varchar2       -- enable optim bundle fixes (YES/NO)
                                  default gc_option_off,
        in_keep_system_params     in varchar2       -- keep system parameters (YES/NO)
                                  default gc_option_off,
        in_keep_session_params    in varchar2       -- keep session parameters 
                                                    -- from the CURRENT session (YES/NO)
                                  default gc_option_off,
        in_keep_session_fcp       in varchar2       -- keep non-default fix controls of the
                                                    -- the target session (YES/NO)
                                  default gc_option_off,
        in_apply_fix_controls     in sys.odcivarchar2list   -- fix controls to be forcibly applied
                                  default null,
        in_show_param_source      in varchar2       -- add a comment explaining where each
                                                    -- fix control setting originates from
                                  default gc_option_off,
        in_values_per_line        in number         -- number of parameter values per line
                                                    -- in the readout
                                  default 1
    )
    return sys.odcivarchar2list
    pipelined
    is
        cursor c_cmp_sesfc_syspar (
            in_inst_id              in  number,
            in_session_id           in  number,
            in_session_serial#      in  number,
            in_bundle_id            in  number,
            in_tab_optim_bundle     in  t_bundlefcp,
            in_wt_optim_bundle      in  varchar2,
            in_wt_system_params     in  varchar2,
            in_wt_session_params    in  varchar2,
            in_wt_session_fcp       in  varchar2,
            in_tab_apply_fc         in  tab_fixctl
        )
        is
            with
            fc_system_parameter as (
                /* _fix_control params for the target instance, container */
                select
                    inst_id,
                    con_id,  /* con_id is the originating container of this parameter */
                    to_number(fc_bugno_vc2)  as bugno,
                    case 
                        when UPPER(fc_value_vc2) = 'ON' then
                            1
                        when UPPER(fc_value_vc2) = 'OFF' then
                            0
                        else
                            to_number(fc_value_vc2)
                    end as value,
                    display_value,
                    ordinal,
                    ismodified,
                    update_comment
                from    
                    (select
                        sy2.inst_id,
                        sy2.con_id,
                        substr(sy2.value, 1, instr(sy2.value, ':') - 1) as fc_bugno_vc2,
                        substr(sy2.value, instr(sy2.value, ':') + 1)    as fc_value_vc2,
                        sy2.display_value,
                        sy2.ordinal,
                        sy2.ismodified,
                        sy2.update_comment,
                        row_number() over (
                                partition by 
                                    sy2.inst_id,
                                    sy2.con_id, 
                                    substr(sy2.value, 1, instr(sy2.value, ':') - 1)
                                order by 
                                    /* highest (name, ordinal) "wins" */
                                    sy2.name desc,
                                    sy2.ordinal desc
                            ) as rn
                    from
                        (select
                            sy0.inst_id,
                            sy0.con_id,
                            sy0.name,
                            row_number() over (partition by sy0.inst_id, sy0.name order by sy0.con_id desc) as rn0
                        from
                            gv$system_parameter sy0
                        where 
                            sy0.inst_id = in_inst_id
                            and sy0.name in ('_fix_control', '_fix_control_1', '_fix_control_2', '_fix_control_3',
                                             '_fix_control_4', '_fix_control_5', '_fix_control_6', '_fix_control_7',
                                             '_fix_control_8', '_fix_control_9')
                            and ( /* parameters applicable to the target container */
                                  sy0.con_id = 0 
                                  or sy0.con_id = (select
                                                       ses.con_id 
                                                   from 
                                                       gv$session ses
                                                   where 
                                                       ses.inst_id = in_inst_id 
                                                       and ses.sid = in_session_id
                                                       and ses.serial# = nvl(in_session_serial#, ses.serial#))
                                )
                        ) sy,
                        gv$system_parameter2 sy2
                    where
                        sy.rn0 = 1  /* probably unnecessary; added just in case */
                        and sy2.inst_id = sy.inst_id
                        and sy2.con_id = sy.con_id
                        and sy2.name = sy.name
                    )
                where
                    rn = 1
            ),
            fc_session_parameter as (
                /* parameters of the current session */
                select
                    inst_id,
                    sid,
                    con_id,
                    to_number(fc_bugno_vc2)  as bugno,
                    case 
                        when UPPER(fc_value_vc2) = 'ON' then
                            1
                        when UPPER(fc_value_vc2) = 'OFF' then
                            0
                        else
                            to_number(fc_value_vc2)
                    end as value,
                    display_value,
                    ordinal,
                    ismodified,
                    update_comment
                from
                    (select
                        inst_id,
                        to_number(sys_context('USERENV', 'SID')) as sid,
                        con_id,
                        substr(value, 1, instr(value, ':') - 1) as fc_bugno_vc2,
                        substr(value, instr(value, ':') + 1)    as fc_value_vc2,
                        display_value,
                        ordinal,
                        ismodified,
                        update_comment,
                        row_number() over (
                                partition by
                                    inst_id,
                                    con_id,
                                    substr(value, 1, instr(value, ':') - 1)
                                order by
                                    /* highest (name, ordinal) "wins" */
                                    name desc,
                                    ordinal desc
                            ) as rn
                    from
                        gv$parameter2
                    where
                        name in ('_fix_control', '_fix_control_1', '_fix_control_2', '_fix_control_3',
                                 '_fix_control_4', '_fix_control_5', '_fix_control_6', '_fix_control_7',
                                 '_fix_control_8', '_fix_control_9')
                    )
                where
                    rn = 1
            ),
            target_session_fc as (
                /* non-default fix controls in the target session */
                select
                    fc.inst_id,
                    fc.con_id,
                    fc.bugno,
                    fc.value,
                    fc.is_default,
                    fc.optimizer_feature_enable,
                    fc.sql_feature,
                    fc.description
                from
                    gv$session ses,
                    gv$session_fix_control fc
                where
                    ses.inst_id = in_inst_id
                    and ses.sid = in_session_id
                    and ses.serial# = nvl(in_session_serial#, ses.serial#)
                    and fc.inst_id = ses.inst_id
                    and fc.session_id = ses.sid
                    and fc.is_default = 0
            ),
            all_optim_bundle_fcp as (
                select
                    bu.fix_control_id,
                    bu.bug_id,
                    bu.bundle_value,
                    bu.bundle_id,
                    bu.bundle_description
                from
                    table(in_tab_optim_bundle) bu
            ),
            overriding_fcp as (
                select
                    tfc.bugno,
                    tfc.value
                from
                    table(in_tab_apply_fc) tfc
            )
            select
                coalesce(sfc.bugno, syp.bugno, sep.bugno, obu.fix_control_id, ofc.bugno) as bugno,
                coalesce( 
                    ofc.value, 
                    (case when in_wt_session_fcp = gc_option_on then sfc.value end),
                    (case when in_wt_session_params = gc_option_on then sep.value end),
                    (case when in_wt_system_params = gc_option_on then syp.value end),
                    (case when in_wt_optim_bundle = gc_option_on 
                               and obu.bundle_id <= nvl(in_bundle_id, 99999999)
                          then obu.bundle_value end),
                    sfc.value
                ) as value,
                case
                    when ofc.value is not null then
                        'Included in the "apply" list'
                    when in_wt_session_fcp = gc_option_on and sfc.value is not null then
                        'From v$session_fixed_control'
                    when in_wt_session_params = gc_option_on and sep.value is not null then
                        'Set in session parameters'
                    when in_wt_system_params = gc_option_on and syp.value is not null then
                        'Set in system parameters'
                    when in_wt_optim_bundle = gc_option_on 
                        and obu.bundle_value is not null 
                        and obu.bundle_id <= nvl(in_bundle_id, 99999999)
                    then
                        'From the optimizer bundle'
                    when sfc.value is not null then
                        'From v$session_fixed_control'
                end as origin,
                case
                    when ( ofc.value is not null
                           or (in_wt_session_fcp = gc_option_on and sfc.value is not null)
                           or (in_wt_session_params = gc_option_on and sep.value is not null)
                           or (in_wt_system_params = gc_option_on and syp.value is not null)
                           or ( ( in_wt_optim_bundle is null
                                  or obu.bundle_id is null
                                  or not (in_wt_optim_bundle = gc_option_on 
                                          and obu.bundle_id <= nvl(in_bundle_id, 99999999)
                                          and obu.bundle_value is not null) 
                                )
                                and sfc.value is not null
                              )
                         )
                    then
                        obu.bundle_value
                end  as bundle_value_for_cmp
            from
                target_session_fc sfc
                full outer join
                fc_system_parameter syp on
                    syp.bugno = sfc.bugno
                full outer join
                fc_session_parameter sep on
                    sep.bugno = coalesce(sfc.bugno, syp.bugno)
                full outer join
                all_optim_bundle_fcp obu on
                    obu.fix_control_id = coalesce(sfc.bugno, syp.bugno, sep.bugno)
                full outer join
                overriding_fcp ofc on
                    ofc.bugno = coalesce(sfc.bugno, syp.bugno, sep.bugno, obu.fix_control_id)
            where
                ( syp.bugno is not null
                  or sep.bugno is not null
                  or obu.bundle_id <= nvl(in_bundle_id, 99999999)
                  or sfc.is_default = 0
                  or ofc.bugno is not null
                )
                and 
                ( in_wt_optim_bundle = gc_option_on 
                  or coalesce(sfc.bugno, syp.bugno, sep.bugno, ofc.bugno) is not null 
                )
                and
                ( in_wt_system_params = gc_option_on
                  or coalesce(sfc.bugno, sep.bugno, ofc.bugno, obu.fix_control_id) is not null
                )
                and
                ( in_wt_session_params = gc_option_on
                  or coalesce(sfc.bugno, syp.bugno, ofc.bugno, obu.fix_control_id) is not null
                )
            order by
                coalesce(sfc.bugno, syp.bugno, sep.bugno, obu.fix_control_id, ofc.bugno)
            ;

        lc_max_values_per_line constant pls_integer := 100;
         
        l_values_per_line   pls_integer;
        l_show_param_source boolean;
        l_fc_apply_list     tab_fixctl;
        l_cnt_fcp           pls_integer;
        l_fcp_param_idx     pls_integer := -1;
        l_outbuf            varchar2(2000);
    begin
        l_values_per_line   := in_values_per_line;
        l_show_param_source := (normalize_bool_flag(in_show_param_source) = gc_option_on);
        if l_show_param_source then
            l_values_per_line := 1;
        end if;
        l_values_per_line := greatest(1, least(l_values_per_line, lc_max_values_per_line));
        l_fc_apply_list := to_tab_fixctl(in_apply_fix_controls);
        l_cnt_fcp := 0;
        -- header
        pipe row('-- Fix control settings report');
        pipe row('-- Session: sid: ' || to_char(in_session_id)
                 || case when in_session_serial# is not null then 
                            ', serial#: ' || to_char(in_session_serial#) end
                 || ' (inst_id: ' || to_char(in_inst_id) || ')');
        if normalize_bool_flag(in_enable_optim_bundle) = gc_option_on
            or normalize_bool_flag(in_keep_system_params) = gc_option_on 
            or normalize_bool_flag(in_keep_session_params) = gc_option_on
            or (l_fc_apply_list is not null and l_fc_apply_list.count > 0)
        then
            pipe row('-- Additional settings:');
            if normalize_bool_flag(in_enable_optim_bundle) = gc_option_on then
                pipe row('--     Include optimizer bundle fixes: ' || gc_option_on
                         || case
                                when in_bundle_id is not null then
                                    ', bundle id: ' || to_char(in_bundle_id)
                            end);
            end if;
            if normalize_bool_flag(in_keep_system_params) = gc_option_on then
                pipe row('--     Keep system parameters: ' || gc_option_on);
            end if;
            if normalize_bool_flag(in_keep_session_params) = gc_option_on then
                pipe row('--     Keep session parameters: ' || gc_option_on);
            end if;
            if normalize_bool_flag(in_keep_session_fcp) = gc_option_on then
                pipe row('--     Keep non-default settings from v$session_fix_control: ' || gc_option_on);
            end if;
            if l_fc_apply_list is not null and l_fc_apply_list.count > 0 then
                declare
                    lc_max_apply_fc_shown constant pls_integer := 2;
                    l_apply_list_plural       varchar2(1);
                    l_apply_list_display_text varchar2(100);
                begin
                    l_apply_list_plural := case when l_fc_apply_list.count > 1 then 's' end;
                    for i in 1 .. least(lc_max_apply_fc_shown, l_fc_apply_list.count) loop
                        l_apply_list_display_text := l_apply_list_display_text
                                || case when l_apply_list_display_text is not null then ', ' end
                                || '''' || to_char(l_fc_apply_list(i).bugno) 
                                || ':' || to_char(l_fc_apply_list(i).value) || '''';
                    end loop;
                    if l_fc_apply_list.count > lc_max_apply_fc_shown then
                        l_apply_list_display_text := l_apply_list_display_text
                                || ', ... (total: ' || to_char(l_fc_apply_list.count) || ')';
                    end if;
                    pipe row('--     Overriding setting' || l_apply_list_plural || ': '
                             || l_apply_list_display_text);
                end;
            end if;
        end if;
        pipe row(' ');
        if not exists_session(in_inst_id, in_session_id, in_session_serial#) then
            pipe row('-- ERROR: session not found.');
            return;
        end if;
        <<fcp_loop>>
        for c in c_cmp_sesfc_syspar (
                    in_inst_id              =>  in_inst_id,
                    in_session_id           =>  in_session_id,
                    in_session_serial#      =>  in_session_serial#,
                    in_bundle_id            =>  in_bundle_id,
                    in_tab_optim_bundle     =>  optim_bundle_fixes_tab,
                    in_wt_optim_bundle      =>  normalize_bool_flag(in_enable_optim_bundle),
                    in_wt_system_params     =>  normalize_bool_flag(in_keep_system_params),
                    in_wt_session_params    =>  normalize_bool_flag(in_keep_session_params),
                    in_wt_session_fcp       =>  normalize_bool_flag(in_keep_session_fcp),
                    in_tab_apply_fc         =>  l_fc_apply_list
                )
        loop
            if c.value is not null then
                if mod(l_cnt_fcp, gc_max_fcp_in_list) = 0 then
                    if l_outbuf is not null then
                        pipe row(rtrim(l_outbuf));
                        pipe row(gc_pp_stmt_separator);
                        l_outbuf := null;
                    end if;
                    l_fcp_param_idx := l_fcp_param_idx + 1;
                    pipe row('alter session set "_fix_control' 
                             || case when l_fcp_param_idx > 0 then '_' || to_number(l_fcp_param_idx) end
                             || '"='); 
                end if;
                if mod(l_cnt_fcp, l_values_per_line) = 0 and l_outbuf is not null then
                    pipe row(l_outbuf);
                    l_outbuf := null;
                end if;
                l_outbuf := l_outbuf 
                        || lpad(case
                                   when mod(l_cnt_fcp, gc_max_fcp_in_list) = 0 then 
                                       ' '
                                   else
                                       ', '
                                end, gc_pp_indent_step, ' ')
                        || rpad('''' || to_char(c.bugno) || ':' || to_char(c.value) || '''',
                                gc_pp_bugno_value_len, ' ')
                        || case
                               when l_show_param_source then
                                   ' -- ' || c.origin
                                   || case
                                          when c.bundle_value_for_cmp = c.value then
                                              '; same as bundle value'
                                          when c.bundle_value_for_cmp <> c.value then
                                              '; != bundle value'
                                      end
                           end;
                l_cnt_fcp := l_cnt_fcp + 1;
            end if;
        end loop fcp_loop;
        if l_outbuf is not null then
            pipe row(rtrim(l_outbuf));
            pipe row(gc_pp_stmt_separator);
        end if;
        -- trailer
        pipe row('-- ' || case when l_cnt_fcp = 0 then 'No' else to_char(l_cnt_fcp) end
                 || ' setting' || case when l_cnt_fcp > 1 then 's' end || ' found.');
        if not exists_session(in_inst_id, in_session_id, in_session_serial#) then
            pipe row('-- WARNING: the target session has ended.');
        end if;
    end report_sesfc;
    

    function normalize_bool_flag (in_arg in varchar2) return varchar2
    is begin
        return case
                   when upper(in_arg) in ('T', 'TRUE', 'Y', 'YES', gc_option_on) then
                       gc_option_on
                   when upper(in_arg) in ('F', 'FALSE', 'N', 'NO', gc_option_off) then
                       gc_option_off
               end;
    end normalize_bool_flag;


    function to_tab_fixctl (in_fcp_list in sys.odcivarchar2list) return tab_fixctl
    is
        l_tab_fcp tab_fixctl := tab_fixctl();
    begin
        if in_fcp_list is not null then
            for c in (
                select  
                    fcp.bugno,
                    fcp.value
                from
                    (select
                        fc.rno,
                        to_number(fc.bugno_vc2) as bugno,
                        case
                            when upper(fc.value_vc2) = 'ON' then
                                1
                            when upper(fc.value_vc2) = 'OFF' then
                                0
                            else
                                to_number(fc.value_vc2)
                        end as value,
                        row_number() over ( partition by to_number(fc.bugno_vc2)
                                            order by fc.rno desc ) as rn
                    from
                        (select /*+ no_merge */
                            rownum as rno,
                            substr(column_value, 1, instr(column_value, ':') - 1) as bugno_vc2,
                            substr(column_value, instr(column_value, ':') + 1)    as value_vc2
                        from
                            table(in_fcp_list)
                        ) fc
                    ) fcp
                where
                    fcp.rn = 1
                order by
                    fcp.rno
            ) loop
                l_tab_fcp.extend();
                l_tab_fcp(l_tab_fcp.count) := obj_fixctl(c.bugno, c.value);
            end loop;
        end if;
        return l_tab_fcp;
    end to_tab_fixctl;


    function exists_session(    
        in_inst_id          in number, 
        in_session_id       in number, 
        in_session_serial#  in number  default null
    ) 
    return boolean
    is
        l_sid number;
    begin
        select  
            ses.sid into l_sid
        from
            gv$session ses
        where
            ses.inst_id = in_inst_id
            and ses.sid = in_session_id
            and ses.serial# = nvl(in_session_serial#, ses.serial#);
        return true;
    exception
        when no_data_found then
            return false;
    end exists_session;

end pkg_optim_bundle_helper;
/