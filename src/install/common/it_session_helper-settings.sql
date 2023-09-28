-- Owner user
define def_it_sess_helper_user = "CMN_IT_SESSION_HELPER$OWNER"

-- Default tablespace of the owner user
define def_it_sess_helper_tabspc = "USERS"

-- Temporary tablespace of the owner user
define def_it_sess_helper_temp_tabspc = "TEMP"

-- Name of the role enabling to view details about one's own sessions
define def_it_role_view_session_self = "IT_VIEW_SESS_SELF"

-- Prefix of the role enabling to view details about sessions of a given
-- user; the complete role name is formed by appending the username to that
-- prefix, separated by a colon.
--
define def_it_role_view_session_prfx = "IT_VIEW_SESS"

-- Name of the role enabling to terminate one's own sessions
define def_it_role_end_session_self = "IT_END_SESS_SELF"

-- Prefix of the role enabling to terminate sessions of a given user;
-- the complete role name is formed by appending the username to that
-- prefix, separated by a colon.
--
define def_it_role_end_session_prefix = "IT_END_SESS"

-- Name of the log table
define def_it_sess_helper_log_table  = "ITSESSHLPLOG"

-- Create public synonyms?
-- Use "" to create public synonyms, "--" to skip that step
--
define def_it_sess_helper_with_pubsyn = ""

-- Prefix to use for public synonym names
define def_it_sess_helper_pubsyn_prfx = "C##"


------------------------------------------------------------------------------------------
-- Purge settings

-- Name of the weekly purge job
define def_purge_job_name = "PURGE_ITSESSHLPLOG"

-- Count of top-most weekly partitions which are always retained
define def_purge_retention_weeks = 15

-- Default number of days to keep
define def_purge_retention_days = 100

-- Schedule of the purge job
define def_purge_repeat_interval = "FREQ=WEEKLY;BYDAY=SUN;BYHOUR=4;BYMINUTE=10"


------------------------------------------------------------------------------------------
-- For uninstallation only

-- Drop the owner user?
-- Use "" to drop, "--" to keep the user
--
--define def_drop_it_sess_helper_user = "--"
define def_drop_it_sess_helper_user = ""
