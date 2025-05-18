create or replace package pkg_optim_bundle_helper authid current_user is
/*
 * SPDX-FileCopyrightText: 2025 R.Vassallo
 * SPDX-License-Identifier: BSD Zero Clause License
 */
    
 /*
  * PACKAGE
  *      pkg_optim_bundle_helper
  *
  * PURPOSE
  *      Functions to help in understanding the state of fix control
  *      settings (v$system_fix_control, v$session_fix_control) and
  *      parameters (v$spparameter, v$system_parameter, ...) in the
  *      database, an optionally in enabling Optimizer bundle fixes.
  *
  * SECURITY
  *      This package is AUTHID CURRENT USER, hence it runs with the 
  *      privileges of the invoker, with additional object privileges
  *      granted specifically to this package though the corresponding
  *      "package role" (named IT_OPTIM_BUNDLE_HELPER_PKG, unless that
  *      is changed in installation settings). The intent is to enable
  *      any user of this package to view fix control-related settings
  *      without necessarily having privileges on the underlying views.
  */

    gc_option_on  constant varchar2(2) := 'ON';
    gc_option_off constant varchar2(3) := 'OFF';

    -- Subtypes
    subtype t_optim_bundle_descr is varchar2(50);
    subtype t_verbose_yes_or_no  is varchar2(40);

    -- Record type for describing the content of the optimizer bundle
    -- parameter file (bundlefcp_DBBP.xml)
    --
    type r_bundlefcp is record (
        bundle_id           number,
        bundle_description  varchar2(50),
        bug_id              number,
        fix_control_id      number,
        bundle_value        number
    );

    type t_bundlefcp is table of r_bundlefcp;

    
    -- Record types for comparison functions

    -- gv$system_fix_control vs parameters in SPFILE */
    type r_cmp_sysfc_spp is record (
        inst_id                     number,
        con_id                      number,
        bugno                       number,
        is_default                  number,
        sysfc_value                 number,
        spfile_value                number,
        bundle_value                number,
        spp_eq_sysfc                t_verbose_yes_or_no,
        spp_eq_bundle               t_verbose_yes_or_no,
        hi_bundle_ind               number,
        spfile_sid                  gv$spparameter.sid %type,
        spfile_display_value        gv$spparameter.display_value %type,
        update_comment              gv$spparameter.update_comment %type,
        optimizer_feature_enable    gv$system_fix_control.optimizer_feature_enable %type,
        sql_feature                 gv$system_fix_control.sql_feature %type,
        description                 gv$system_fix_control.description %type,
        bundle_id                   number,
        bundle_descr                t_optim_bundle_descr, 
        bug_id                      number
    );

    -- gv$system_fix_control vs system parameters
    type r_cmp_sysfc_syspar is record (
        inst_id                     number,
        con_id                      number,
        bugno                       number,
        is_default                  number,
        sysfc_value                 number,
        syspar_value                number,
        bundle_value                number,
        syspar_eq_sysfc             t_verbose_yes_or_no,
        syspar_eq_bundle            t_verbose_yes_or_no,
        hi_bundle_ind               number,
        syspar_display_value        gv$system_parameter2.display_value %type,
        syspar_ismodified           gv$system_parameter2.ismodified %type,
        update_comment              gv$system_parameter2.update_comment %type,
        optimizer_feature_enable    gv$system_fix_control.optimizer_feature_enable %type,
        sql_feature                 gv$system_fix_control.sql_feature %type,
        description                 gv$system_fix_control.description %type,
        bundle_id                   number,
        bundle_descr                t_optim_bundle_descr, 
        bug_id                      number
    );
    
    -- parameters is SPFILE vs system parameters
    type r_cmp_spp_syspar is record (
        inst_id                     number,
        con_id                      number,
        bugno                       number,
        spfile_value                number,
        syspar_value                number,
        bundle_value                number,
        spfile_eq_syspar            t_verbose_yes_or_no,
        syspar_eq_bundle            t_verbose_yes_or_no,
        spfile_eq_bundle            t_verbose_yes_or_no,
        hi_bundle_ind               number,
        spfile_sid                  gv$spparameter.sid %type,
        spfile_display_value        gv$spparameter.display_value %type,
        syspar_display_value        gv$system_parameter2.display_value %type,
        syspar_ismodified           gv$system_parameter2.ismodified %type,
        spfile_update_comment       gv$spparameter.update_comment %type,
        syspar_update_comment       gv$system_parameter2.update_comment %type,
        bundle_id                   number,
        bundle_descr                t_optim_bundle_descr,
        bug_id                      number
    );
    
    -- gv$session_fix_control vs session parameters (of the current session)
    type r_cmp_sesfc_sespar is record (
        inst_id                     number,
        session_id                  number,
        con_id                      number,
        bugno                       number,
        is_default                  number,
        sesfc_value                 number,
        sespar_value                number,
        bundle_value                number,
        sespar_eq_sesfc             t_verbose_yes_or_no,
        sespar_eq_bundle            t_verbose_yes_or_no,
        hi_bundle_ind               number,
        sespar_display_value        gv$parameter2.display_value %type,
        sespar_ismodified           gv$parameter2.ismodified %type,
        update_comment              gv$parameter2.update_comment %type,
        optimizer_feature_enable    gv$session_fix_control.optimizer_feature_enable %type,
        sql_feature                 gv$session_fix_control.sql_feature %type,
        description                 gv$session_fix_control.description %type,
        bundle_id                   number,
        bundle_descr                t_optim_bundle_descr,
        bug_id                      number
    );
    
    -- gv$session_fix_control vs system parameters
    type r_cmp_sesfc_syspar is record (
        inst_id                     number,
        session_id                  number,
        con_id                      number,
        bugno                       number,
        is_default                  number,
        sessfc_value                number,
        syspar_value                number,
        bundle_value                number,
        syspar_eq_sesfc             t_verbose_yes_or_no,
        syspar_eq_bundle            t_verbose_yes_or_no,
        hi_bundle_ind               number,
        syspar_display_value        gv$system_parameter2.display_value %type,
        syspar_ismodified           gv$system_parameter2.ismodified %type,
        update_comment              gv$system_parameter2.update_comment %type,
        optimizer_feature_enable    gv$session_fix_control.optimizer_feature_enable %type,
        sql_feature                 gv$session_fix_control.sql_feature %type,
        description                 gv$session_fix_control.description %type,
        bundle_id                   number,
        bundle_descr                t_optim_bundle_descr,
        bug_id                      number
    );
    
    type t_cmp_sysfc_spp    is table of r_cmp_sysfc_spp;
    type t_cmp_sysfc_syspar is table of r_cmp_sysfc_syspar;
    type t_cmp_spp_syspar   is table of r_cmp_spp_syspar;
    type t_cmp_sesfc_sespar is table of r_cmp_sesfc_sespar;
    type t_cmp_sesfc_syspar is table of r_cmp_sesfc_syspar;

    /* 
      Returns the contents of the optimizer bundle parameter file 
      (bundlefcp_DBBP.xml), up to the specified bundle identifier
     */
    function optim_bundle_fixes (
        in_bundle_id in number default null
    ) 
    return t_bundlefcp
    pipelined;
    
    /*
      Returns a comparison of fix controls between the spfile and the present
      state of gv$system_fix_control. The readout contains non-default system
      fix controls, "_fix_control" parameters from the spfile, and fix controls
      from the optimizer bundle file (bundlefcp_DBBP.xml), side by side.
     */
    function cmp_sysfc_spfile (
        in_bundle_id in number default null     -- target bundle-id level
    )
    return t_cmp_sysfc_spp
    pipelined;
    
    /*
      Returns a comparison of fix controls between actual system parameters
      (in memory) and the present state of gv$system_fix_control. The readout
      contains non-default system fix controls, "_fix_control" system parameters,
      and fix controls from the optimizer bundle file (bundlefcp_DBBP.xml),
      side by side.
     */
    function cmp_sysfc_syspar (
        in_bundle_id in number default null     -- target bundle-id level
    )
    return t_cmp_sysfc_syspar
    pipelined;
    
    /*
      Returns a comparison of "_fix_control" parameters in the spfile
      and in the present state of system parameters. The readout contains 
      "_fix_control" parameters from either side, along with settings from
      the optimizer bundle file (bundlefcp_DBBP.xml).
     */
    function cmp_spfile_syspar (
        in_bundle_id in number default null     -- target bundle-id level
    )
    return t_cmp_spp_syspar
    pipelined;
    
    /*
      Returns a comparison of fix controls between session parameters of
      the current session and the present state of gv$session_fix_control.
      The readout contains non-default session fix controls, "_fix_control"
      session parameters, and fix controls from the optimizer bundle file
      (bundlefcp_DBBP.xml), side by side.
     */
    function cmp_sesfc_sespar (
        in_bundle_id in number default null     -- target bundle-id level
    )
    return t_cmp_sesfc_sespar
    pipelined;
    
    /*
      Returns a comparison of fix controls between the present state of
      gv$session_fix_control for the specified session, and the present
      state of system parameters. The readout contains non-default fix controls
      of the specified session, "_fix_control" system parameters in memory,
      and fix controls from the optimizer bundle file (bundlefcp_DBBP.xml),
      side by side.
     */
    function cmp_sesfc_syspar (
        in_inst_id          in number       -- target session: instance
                            default sys_context('USERENV', 'INSTANCE'),
        in_session_id       in number       -- target session: sid
                            default sys_context('USERENV', 'SID'),
        in_session_serial#  in number       -- target session: serial# (optional)
                            default null,
        in_bundle_id        in number       -- target bundle-id level
                            default null
    )
    return t_cmp_sesfc_syspar
    pipelined;

    /*
      Returns a report of non-default fix controls settings of the specified
      session, in the form of an ALTER SESSION statement reproducing that
      session's settings.
      
      Optionally, additional settings can be merged into the results, by way
      of the following optional arguments:

         1. fix control settings from the in_apply_fix_controls argument
            (if provided)
         
         2. fix control settings from session parameters of the _current_
            session (as opposed to session parameters of the _target_ session),
            including those whose value is the same as the default, if the
            argument in_keep_session_params is 'ON'
            
         3. fix control settings from system parameters, including those
            whose value is the same as the default, if the argument
            in_keep_system_params is 'ON'
            
         4. fix control from the Optimizer bundle, if the argument
            in_enable_optim_bundle is 'ON'; optionally, the in_bundle_id
            argument can be used to specify which bundle level to use

      The above list is processed in decreasing order of precedence: 
      settings from the in_apply_fix_controls list are always applied,
      then (if in_keep_session_params is 'ON') session parameters from
      the current session, then (if in_keep_system_params is 'ON') system
      parameters, then (if in_enable_optim_bundle is 'ON') settings from
      the Optimizer bundle.
      
      However, if the in_keep_session_fcp argument is 'ON', non-default
      settings of the target session (from gv$session_fixed_controls) take 
      precedence over anything else except the in_apply_fix_controls list.
     */
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
    pipelined;
    
end pkg_optim_bundle_helper;
/