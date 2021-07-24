define def_spool_directory = "E:\Home\romain\Temp"

-- Page size: range: 1-50000
-- Use 18 for pretty reports, 50000 for making diffs easier to read.
--
set pagesize 50000
--set pagesize 18

-- Include or hide DBA_TAB_PRIVS.COMMON in the readout?
-- Use "--" to hide that column, "" to keep it.
--
define def_hide_column_common = "--"

-- Include or hide DBA_TAB_PRIVS.INHERITED in the readout?
-- Use "--" to hide that column, "" to keep it.
--
define def_hide_column_inherited = "--"

-- Include or hide grants to PUBLIC in the readout?
-- Use "--" to hide grants to PUBLIC, "" to keep them.
--
define def_hide_grants_to_public = ""
--define def_hide_grants_to_public = "--"

-- Include database links in the readout?
-- Use "on" to list database links, "off" to skip them.
--
define def_show_db_links = "on"
--define def_show_db_links = "off"

-- Include grants on Oracle-owned objects in the "All object privileges"
-- section? Use "--" to include Oracle-owned objects, "" to omit them.
--
define def_hide_ora_obj = "--"
--define def_hide_ora_obj = ""

-- Execute with TERMOUT ON or OFF?
--
define def_set_termout = "off"
--define def_set_termout = "on"

-- Use 10.2-compatible implementation? Use "" for the default implementation,
-- or "-10g" to enable an alternative implementation without the following
-- SQL features:
--    * The LISTAGG aggregate function
--    * Recursive subquery factoring, aka recursive WITH
--    * Lists of column aliases after the WITH query_name construct
--
--define def_10g_compat_impl = "-10g"
define def_10g_compat_impl = ""
