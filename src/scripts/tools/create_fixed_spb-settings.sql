/*
 * SPDX-FileCopyrightText: 2024 R.Vassallo
 * SPDX-License-Identifier: BSD Zero Clause License
 */

-- Directory where temporary spool files will be created
define def_temp_spool_dir = "E:\Home\romain\temp"

-- Path separator in file specifications; set to "/" on Unix, or "\" if using Windows
define def_dir_sep_char = "\"

-- Host command for deleting files, to be used when removing temporary spool files
-- Use "rm -f" on Unix, or "del" if using Windows
define def_host_cmd_rm = "del"
--define def_host_cmd_rm = "rm -f"
