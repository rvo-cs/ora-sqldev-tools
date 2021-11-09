prompt
prompt Spool file: &&def_spool_directory/&&def_spool_filename

set termout off
set trimspool on

spool &&def_spool_directory/&&def_spool_filename replace

@@genddl-impl "&&def_object_type_xc" "&&def_schema_name_xc_int" "&&def_object_name_xc_int"

spool off

set termout on

prompt ... Completed.
prompt
