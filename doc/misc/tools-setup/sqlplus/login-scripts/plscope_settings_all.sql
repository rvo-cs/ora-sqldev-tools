set feedback off

declare
   e_invalid_param_value exception;
   e_invalid_option      exception;
   pragma exception_init(e_invalid_param_value, -96);
   pragma exception_init(e_invalid_option     , -2248);

   function is_oracle_maintained (in_schema_name in varchar2) return boolean
   is
      l_oracle_maintained varchar2(1 char);
   begin
      <<check_username>>
      begin
         execute immediate
            case
               when dbms_db_version.version >= 12 then
                  q'[select usr.oracle_maintained
                       from sys.all_users usr
                      where usr.username = :name]'
               else
                  /* 11g: static list of known Oracle-maintained accounts */
                  q'[select case
                               when usr.username in (
                                  'ANONYMOUS'    , 'APPQOSSYS'        , 'AUDSYS',
                                  'CTXSYS'       , 'DBSFWUSER'        , 'DBSNMP',
                                  'DVF'          , 'DVSYS'            , 'EXFSYS',
                                  'GGSYS'        , 'GSMADMIN_INTERNAL', 'GSMCATUSER',
                                  'GSMROOTUSER'  , 'GSMUSER'          , 'LBACSYS',
                                  'MDSYS'        , 'MGMT_VIEW'        , 'OJVMSYS',
                                  'OLAPSYS'      , 'ORDDATA'          , 'ORDPLUGINS',
                                  'ORDSYS'       , 'OUTLN'            , 'OWBSYS',
                                  'REMOTE_SCHEDULER_AGENT'            , 'SI_INFORMTN_SCHEMA',
                                  'SYS'          , 'SYSBACKUP'        , 'SYSDG',
                                  'SYSKM'        , 'SYSMAN'           , 'SYSRAC',
                                  'SYSTEM'       , 'WK_TEST'          , 'WKPROXY',
                                  'WKSYS'        , 'WMSYS'            , 'XDB' )
                              then
                                 'Y'
                              else
                                 'N'
                            end as oracle_maintained
                       from sys.all_users usr
                      where usr.username = :name]'
            end
            into l_oracle_maintained
            using in_schema_name;
      exception
         when no_data_found then
            null;
      end check_username;
      return case
                when l_oracle_maintained = 'Y' then
                   true
                else
                   false
             end;
   end is_oracle_maintained;

begin
   if sys_context('USERENV', 'ISDBA') = 'TRUE'
      or is_oracle_maintained(sys_context('USERENV', 'CURRENT_SCHEMA'))
   then
      -- Oracle-maintained schema; leave PLSCOPE_SETTINGS "as is"
      return;
   end if;

   <<plscope_settings_12_2>>
   begin
      execute immediate
         'alter session set plscope_settings = "IDENTIFIERS:ALL, STATEMENTS:ALL"';
      return;
   exception
      when e_invalid_option or e_invalid_param_value then
         null;
   end plscope_settings_12_2;

   <<plscope_settings_11_1>>
   begin
      execute immediate
         'alter session set plscope_settings = "IDENTIFIERS:ALL"';
      exception
         when e_invalid_option then
            null;
   end plscope_settings_11_1;
end;
/

set feedback on
