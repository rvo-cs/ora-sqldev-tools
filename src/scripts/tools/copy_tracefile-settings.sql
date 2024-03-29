/*
 * SPDX-FileCopyrightText: 2024 R.Vassallo
 * SPDX-License-Identifier: Apache License 2.0
 */

-- Default directory object for the OS directory where trace files
-- are generated; specify "" to disable using a default
--
define def_default_trc_directory = "DIAG_TRACE_DIR"

-- Default destination folder for trace file copies; speficy ""
-- to use the current working directory as the default destination
--
define def_default_dest_folder = "E:\Home\romain\Temp"
 
-- Directory separator in file specifications on the client OS
-- (Windows: "\", Unix: "/")
--
define def_dir_sep = "\"
