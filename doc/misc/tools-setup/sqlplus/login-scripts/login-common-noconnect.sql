set arraysize 200
set linesize 158
set pagesize 50

set trimspool on
set trimout on
set tab off

set long 10000000
set longchunksize 10000000

define _EDITOR="C:\Program Files (x86)\Vim\vim74\gvim.exe"

define rvocs_orasqldevtools_dir = "E:\Home\romain\projets\git-src\ora-sqldev-tools"

@&rvocs_orasqldevtools_dir\src\scripts\sqlplus_aliases
