set arraysize 200
set linesize 200
set pagesize 50

set trimspool on
set trimout on
set tab off

set long 10000000
set longchunksize 10000000

set history nofails
set history filter none

define _EDITOR="C:\Program Files (x86)\Vim\vim74\gvim.exe"

set sqlprompt "@|bg_black,fg_green,bold SQL>|@ "

define rvocs_orasqldevtools_dir = "E:\Home\romain\projets\git-src\ora-sqldev-tools"

@@login-common-aliases
