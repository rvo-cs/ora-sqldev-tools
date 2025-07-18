/*
 * SPDX-FileCopyrightText: 2025 R.Vassallo
 * SPDX-License-Identifier: BSD Zero Clause License
 */

/*
FILENAME
    copy_tracefile.sql

DESCRIPTION
    This script reads from the specified trace file, and writes the 
    content of that file into a spool file.
    
USAGE
    @copy_tracefile [ arguments ]

    Where arguments can be the following:
    
        . DIR=directory_object
              Name of the directory object for the OS directory containing
              the trace file to be copied; if omitted, the default directory
              object, if configured in settings, will be used.
             
        . TRC=trace_file
              Name of the trace file to copy
        
        . DST=filespec
              File specification to be used for the copy; the default is to
              use the same filename as the input trace file, in the default
              destination directory configured in settings.

PREREQUISITES
    This script requires Javascript, therefore it can only be run in SQLcl
    or SQL Developer, using a JDK with Javascript support enabled.

NOTES
    1. This script prompts for missing arguments as needed, and also for
       the user to confirm the copy operation
    2. This version now uses the BFILE interface, so it should work regardless
       of line lengths in the source tracefile
*/
    
whenever sqlerror exit failure rollback
whenever oserror exit failure rollback

-- SQL*Plus trick for ensuring that &1, &2, &3, and &4 are defined
-- regardless of the actual arguments

set termout off
column 1 noprint new_value 1
column 2 noprint new_value 2
column 3 noprint new_value 3
column 4 noprint new_value 4
select 
    null as "1",
    null as "2",
    null as "3",
    null as "4"
from 
    dual 
where 
    null is not null;
column 1 clear
column 2 clear
column 3 clear
column 4 clear
set termout on

@@copy_tracefile-settings

-- Sanity- and syntax-checking of script arguments: there should be
-- at most 3 arguments, of the DIR=..., TRC=..., and DST=... form,
-- each being specified only once

set termout off
column tracefile_val noprint new_value def_tracefile
column tracefile_ind noprint new_value def_tracefile_ind
column dirname_val   noprint new_value def_dirname
column dirname_ind   noprint new_value def_dirname_ind
column destfile_val  noprint new_value def_destfile
column errmsg        noprint new_value def_errmsg
column script_suffix noprint new_value def_script_suffix

select
    args.tracefile_val,
    nvl2(args.tracefile_val, '--', null)  as tracefile_ind,
    coalesce(args.dirname_val, '&&def_default_trc_directory') as dirname_val,
    nvl2(coalesce(args.dirname_val, '&&def_default_trc_directory'), '--', null) as dirname_ind,
    args.destfile_val,
    coalesce(
        max(chck.column_value),
        listagg(ctrl.column_value, chr(10)) within group (order by rownum)
    ) as errmsg,        -- error message
    decode(
        count(coalesce(chck.column_value, ctrl.column_value)),
        0, '_impl_a0', 
        '-bad_args'
    ) as script_suffix  -- suffix of the impl. script to start next
from
    (select
        rownum as arg#,
        case
            when upper(substr(argv.column_value, 1, 4)) in ('DIR=', 'TRC=', 'DST=') then
                upper(substr(argv.column_value, 1, 3))
            when argv.column_value is not null then
                '???'
            end as arg_type,
        case
            when upper(substr(argv.column_value, 1, 4)) in ('DIR=', 'TRC=', 'DST=') then
                trim('"' from substr(argv.column_value, 5))
            when argv.column_value is not null then
                argv.column_value 
        end as arg_value
    from
        table(sys.odcivarchar2list(q'{&&1}', q'{&&2}', q'{&&3}', q'{&&4}')) argv
    )
    pivot (
        count(arg_type) as argc_all,
        count(distinct arg_value) as argc,
        listagg('#' || to_char(arg#), ', ') within group (order by arg#) as arg#,
        max(arg_value) keep (dense_rank last order by arg#) as val
        for arg_type in (
            'TRC' as tracefile,
            'DIR' as dirname,
            'DST' as destfile,
            '???' as bad_argument
        )
    ) args,
    table(cast(multiset(
        -- There should be at most 3 arguments
        select
            case
                when (args.dirname_argc_all
                        + args.tracefile_argc_all
                        + args.destfile_argc_all
                        + args.bad_argument_argc_all) > 3 
                then
                    'Too many arguments'
            end as msg
        from 
            dual 
    ) as sys.odcivarchar2list)) (+) chck,
    table(cast(multiset(
        select
            -- The DIR=... argument must not be repeated
            case
                when args.dirname_argc > 1 then
                    'Too many DIR= arguments (' || args.dirname_arg# || '); specify only 1'
            end as msg
        from 
            dual 
        union all
        select
            -- The TRC=... argument must not be repeated
            case
                when args.tracefile_argc > 1 then
                    'Too many TRC= arguments (' || args.tracefile_arg# || '); specify only 1'
            end as msg
        from
            dual 
        union all
        select
            -- The DST=... argument must not be repeated
            case
                when args.destfile_argc > 1 then
                    'Too many DST= arguments (' || args.destfile_arg# || '); specify only 1'
            end as msg
        from 
            dual 
        union all
        select
            -- No argument different from DIR=..., TRC=..., and DST=... is accepted
            case
                when args.bad_argument_argc > 0 then
                    'Bad argument' || case when args.bad_argument_argc > 1 then 's' end
                    || ': ' || args.bad_argument_arg#
            end as msg
        from 
            dual
    ) as sys.odcivarchar2list)) (+) ctrl
group by
    args.tracefile_val, 
    args.dirname_val, 
    args.destfile_val;    

column tracefile_val clear
column tracefile_ind clear
column dirname_val   clear
column dirname_ind   clear
column destfile_val  clear
column errmsg        clear
column script_suffix clear
set termout on

@@copy_tracefile/copy_tracefile&&def_script_suffix

undefine 1
undefine 2
undefine 3
undefine 4

undefine def_tracefile
undefine def_tracefile_ind
undefine def_dirname
undefine def_dirname_ind
undefine def_destfile
undefine def_errmsg
undefine def_script_suffix

undefine def_default_trc_directory
undefine def_default_dest_folder
undefine def_dir_sep
