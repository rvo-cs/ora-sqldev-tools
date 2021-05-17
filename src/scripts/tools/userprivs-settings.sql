define def_spool_directory = "E:\Home\romain\Temp"

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

-- Include grants on Oracle-owned objects in the "All object privileges"
-- section? Use "--" to include Oracle-owned objects, "" to omit them.
--
define def_hide_ora_obj = "--"
--define def_hide_ora_obj = ""

-- Execute with TERMOUT ON or OFF?
--
define def_set_termout = "off"
--define def_set_termout = "on"
