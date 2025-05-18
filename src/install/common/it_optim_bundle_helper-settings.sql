/*
 * SPDX-FileCopyrightText: 2025 R.Vassallo
 * SPDX-License-Identifier: BSD Zero Clause License
 */

-- Owner user
define def_fix_cntrl_hlpr_user = "CMN_IT_FIXCTL_HELPER$OWNER"
--define def_fix_cntrl_hlpr_user = "C##CMN_IT_FIXCTL_HELPER$OWNER"

-- Default tablespace of the owner user
define def_fix_cntrl_hlpr_tabspc = "USERS"

-- Temporary tablespace of the owner user
define def_fix_cntrl_hlpr_temp_tabspc = "TEMP"

-- Name of the role which will be granted to the helper package
define def_fix_cntrl_hlpr_pkg_role = "IT_OPTIM_BUNDLE_HELPER_PKG";
--define def_fix_cntrl_hlpr_pkg_role = "C##IT_OPTIM_BUNDLE_HELPER_PKG";

-- Create public synonyms?
-- Use "" to create public synonyms, "--" to skip that step
--
define def_fix_cntrl_hlpr_with_pubsyn = ""

-- Prefix to use for public synonym names
define def_fix_cntrl_hlpr_pubsyn_prfx = "C##"


------------------------------------------------------------------------------------------
-- For uninstallation only

-- Drop the owner user?
-- Use "" to drop, "--" to keep the user
--
--define def_drop_fix_cntrl_hlpr_user = "--"
define def_drop_fix_cntrl_hlpr_user = ""
