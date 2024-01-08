set arraysize 200
set linesize 200
set pagesize 50

set trimspool on
set trimout on
set tab off

set termout off
-- This could trigger the HIGH_LONG_MEM_WARNING message if TERMOUT was ON
set long 2000000
set termout on
set longchunksize 200000

set history nofails
set history filter none

define _EDITOR="C:\Program Files (x86)\Vim\vim74\gvim.exe"

set sqlprompt "@|bg_black,fg_green,bold SQL>|@ "

-- Root dir. of the local clone of Tanel Poder's tpt-oracle Git repository
-- (git clone https://github.com/tanelpoder/tpt-oracle.git)
define tpt_dir = "F:\Products\Contrib\git-src\tpt-oracle"

-- Root dir. of my own local Git repository for SQL Developer-related tools
define rvocs_orasqldevtools_dir = "E:\Home\romain\projets\git-src\ora-sqldev-tools"

@@login-common-aliases
