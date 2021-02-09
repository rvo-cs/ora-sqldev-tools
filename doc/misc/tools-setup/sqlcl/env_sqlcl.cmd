@REM ==================================================
@REM env_sqlcl.cmd -- initializations for Oracle SQLcl 
@REM --------------------------------------------------

@ECHO OFF

REM =======================================================================
REM Required for OCI connections in SQLcl and SQL Developer: the native
REM library directory (containing the native OCI driver) must be present
REM in the PATH and precede any other client installations.
REM -----------------------------------------------------------------------

set ORACLE_HOME=F:\Produits\Win_7\Oracle\instantclient\instantclient_18_5

set PATH=%ORACLE_HOME%;%PATH%

REM NOTE: ORA-01017 messages from SQLcl will be a bit strange in this
REM configuration (Instant Client in the PATH) due to fallback mechanisms
REM from jdbc:oci to jdbc:thin; basically 2 messages will appear instead
REM of just 1, even in cases where OCI is not supposed to be used.

REM =======================================================================
REM Command aliases
REM -----------------------------------------------------------------------

REM SQLcl with jdbc:thin
doskey sqlcl=F:\Produits\Win_7\Oracle\SQLcl\sql.cmd $*

REM SQLcl with jdbc:oci
doskey sqlcl-oci=F:\Produits\Win_7\Oracle\SQLcl\sql+oci.cmd -oci $*

REM SQL Developer
doskey sqldev=F:\Produits\Win_7\Oracle\SQLDeveloper\sqldeveloper-20.4.0.379.2205-x64\sqldeveloper.exe
