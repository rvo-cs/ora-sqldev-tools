@REM ==================================================
@REM env_sqlcl.cmd -- initializations for Oracle SQLcl 
@REM --------------------------------------------------

@ECHO OFF

REM =======================================================================
REM Required for OCI connections in SQLcl and SQL Developer: the native
REM library directory (containing the native OCI driver) must be present
REM in the PATH and precede any other client installations.
REM -----------------------------------------------------------------------

set ORACLE_HOME=F:\Produits\Oracle\instantclient\instantclient_21_11

set PATH=%ORACLE_HOME%;%PATH%

REM NOTE: ORA-01017 messages from SQLcl will be a bit strange in this
REM configuration (Instant Client in the PATH) due to fallback mechanisms
REM from jdbc:oci to jdbc:thin; basically 2 messages will appear instead
REM of just 1, even in cases where OCI is not supposed to be used.

REM =======================================================================
REM [Optional] Search path for .sql files invoked using @file and @@file
REM -----------------------------------------------------------------------

REM set SQLPATH=E:\_path_to_\git-src\ora-sqldev-tools\src\scripts\tools

REM =======================================================================
REM Command aliases
REM -----------------------------------------------------------------------

REM SQLcl with jdbc:thin
doskey sqlcl=F:\Produits\Oracle\SQLcl\sql.cmd $*
doskey sql-exe=F:\Produits\Oracle\SQLcl\sqlw.cmd $*
doskey sqlcl-prev=F:\Produits\Oracle\SQLcl\sql-prev.cmd $*

REM SQLcl with jdbc:oci
doskey sqlcl-oci=F:\Produits\Oracle\SQLcl\sql+oci.cmd -oci $*

REM SQL Developer
doskey sqldev=F:\Produits\Oracle\SQLDeveloper\sqldeveloper-23.1.1.345.2114-x64\sqldeveloper.exe $*
doskey sqldev-prev=F:\Produits\Oracle\SQLDeveloper\sqldeveloper-21.4.3.063.0100-x64\sqldeveloper.exe $*
