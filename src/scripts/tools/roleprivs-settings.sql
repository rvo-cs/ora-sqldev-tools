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

-- Include grants on Oracle-owned objects in the "All object privileges"
-- section? Use "--" to include Oracle-owned objects, "" to omit them.
--
define def_hide_ora_obj = "--"
--define def_hide_ora_obj = ""

-- Execute with TERMOUT ON or OFF?
--
define def_set_termout = "off"
--define def_set_termout = "on"
