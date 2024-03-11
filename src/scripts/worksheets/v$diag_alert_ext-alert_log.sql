-- SPDX-FileCopyrightText: 2022 R.Vassallo
-- SPDX-License-Identifier: BSD Zero Clause License

/*  
  ###################################################################
  ###  NOTE: the DBA role is mandatory to query V$DIAG_ALERT_EXT  ###
  ###################################################################
*/

set role all;

/*=====================*/
/* Oracle 11.2 to 12.2 */
/*---------------------*/

select
    inst_id
  , originating_timestamp
  --, component_id
  , message_text
  , supplemental_attributes
  , supplemental_details
  , filename
from
    v$diag_alert_ext
where
    component_id = 'rdbms'
    and adr_home = regexp_replace(
            (select value from v$diag_info where name = 'ADR Home'),
            '^' || (select value from v$diag_info where name = 'ADR Base') || '/', null)
            || case
                when '12' = (select regexp_replace(version, '\..*$', null) 
                               from product_component_version
                              where product like 'Oracle Database%' and rownum = 1)
                then '/'
               end
    and (:FROM_TIMESTAMP_TZ is null or originating_timestamp >= 
            to_timestamp_tz(:FROM_TIMESTAMP_TZ, 'YYYY-MM-DD HH24:MI:SS TZR'))
;


/*=====================*/
/* Oracle 12.2 to 19.x */
/*---------------------*/

select 
    con_id
  , container_name
  , originating_timestamp
  --, component_id
  , message_text
  , supplemental_attributes
  , supplemental_details
  , filename
from 
    v$diag_alert_ext
where
    component_id = 'rdbms'
    and (:FROM_TIMESTAMP_TZ is null or originating_timestamp >= 
            to_timestamp_tz(:FROM_TIMESTAMP_TZ, 'YYYY-MM-DD HH24:MI:SS TZR'))
;
