/*
 * SPDX-FileCopyrightText: 2025 R.Vassallo
 * SPDX-License-Identifier: BSD Zero Clause License
 */

-- Default directory object for the OS directory where trace files
-- are generated; specify "" to disable using a default
--
define def_default_trc_directory = "DIAG_TRACE_DIR"

-- Default destination folder for trace file copies; if running on SQLcl,
-- but not if using (legacy) SQL Developer, "" may be specified in order
-- to use the current working directory as the default destination folder
--
define def_default_dest_folder = "E:\Home\romain\Temp"
 
-- Directory separator in file specifications on the client OS
-- (Windows: "\", Unix: "/")
--
define def_dir_sep = "\"
