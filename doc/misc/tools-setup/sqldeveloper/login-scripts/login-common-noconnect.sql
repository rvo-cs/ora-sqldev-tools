set trimspool on
set trimout on
set tab off

--set long 10000000
--set longchunksize 10000000

-- Root dir. of the local clone of Tanel Poder's tpt-oracle Git repository
-- (git clone https://github.com/tanelpoder/tpt-oracle.git)
define tpt_dir = "E:\Home\romain\oracle\tpt-oracle"

-- Root dir. of my own local Git repository for SQL Developer-related tools
define rvocs_orasqldevtools_dir = "E:\Home\romain\projets\git-src\ora-sqldev-tools"

@@login-common-aliases

-- Must CD somewhere, otherwise the SPOOL temp.sql, CALL temp.sql pattern won't work
cd E:\Home\romain\.sqldev-temp
