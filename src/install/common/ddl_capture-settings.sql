-- Owner user
define def_ddl_capture_user = "CMN_DDL_CAPTURE$OWNER"
--define def_ddl_capture_user = "C##DDL_CAPTURE$OWNER"

-- Name of the role granting permission to read from captured DDL views
define def_read_captured_ddl_role = "IT_READ_CAPTURED_DDL"

-- Default tablespace of the owner user
define def_ddl_capture_tabspc = "USERS"

-- Temporary tablespace of the owner user
define def_ddl_capture_temp_tabspc = "TEMP"

-- Shall we capture grants? 
-- Use "" to enable, "--" to disable
define def_ddl_capture_grants = ""

-- Shall we capture grants details into a separate table?
-- Use "" to enable, "--" to disable
define def_ddl_capture_grant_details = ""

-- Multitenant: create the owner user as a common user?
-- Use "" to enable, "--" to disable
--
-- NOTE: This may not be such a good idea:
-- NOTE:    1) It makes more sense to install the DDL capture at the PDB level
-- NOTE:    And:
-- NOTE:    2) Don't know why, although the triggers are supposedly declared
-- NOTE:       on the entire database, they don't seem to fire for DDL events
-- NOTE:       outside the CDB$ROOT container.
--
--define def_common_ddl_capture_user = ""
define def_common_ddl_capture_user = "--"

-- Multitenant aware? This adds the CON_NAME column in captured DDL tables / views.
-- Use "" to enable, "--" to disable
--
--define def_pdb_aware = ""
define def_pdb_aware = "--"

define def_pre_ddl_table  = "TORAPREDDL"
define def_post_ddl_table = "TORAPOSTDDL"

define def_pre_grant_table = "TORAPREGRANT"
define def_post_grant_table = "TORAPOSTGRANT"

define def_pre_ddl_view   = "VORAPREDDL"
define def_post_ddl_view  = "VORAPOSTDDL"

define def_pre_grant_view = "VORAPREGRANT"
define def_post_grant_view = "VORAPOSTGRANT"


------------------------------------------------------------------------------------------
-- Purge settings

-- Name of the weekly purge job
define def_purge_job_name = "PURGE_CAPTURED_DDL"

-- Count of top-most weekly partitions which are always retained
define def_purge_retention_weeks = 6

-- Default number of days to keep
define def_purge_retention_days = 90

-- Schedule of the purge job
define def_purge_repeat_interval = "FREQ=WEEKLY;BYDAY=SUN;BYHOUR=4;BYMINUTE=5"


------------------------------------------------------------------------------------------
-- For uninstallation only

-- Drop the owner user? 
-- Use "" to drop, "--" to keep the user
--
--define def_drop_ddl_capture_user = "--"
define def_drop_ddl_capture_user = ""
