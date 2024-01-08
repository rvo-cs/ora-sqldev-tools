set arraysize 200
set linesize 158
set pagesize 50

set trimspool on
set trimout on
set tab off

set long 5000000
set longchunksize 200000

define _EDITOR="C:\Program Files (x86)\Vim\vim74\gvim.exe"

-- Root dir. of the local clone of Tanel Poder's tpt-oracle Git repository
-- (git clone https://github.com/tanelpoder/tpt-oracle.git)
define tpt_dir = "F:\Products\Contrib\git-src\tpt-oracle"

-- Root dir. of my own local Git repository for SQL Developer-related tools
define rvocs_orasqldevtools_dir = "E:\Home\romain\projets\git-src\ora-sqldev-tools"

@&rvocs_orasqldevtools_dir\src\scripts\sqlplus_aliases
