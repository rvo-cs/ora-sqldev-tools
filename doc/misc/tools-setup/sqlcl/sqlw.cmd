@ECHO OFF

REM ===================================================================
REM sqlw.cmd -- wrapper script for starting SQLcl under Windows 7/10/11
REM ===================================================================

REM This version of the wrapper script calls the official sql.exe 
REM binary shipped for Windows as part of the SQLcl bundle. Settings
REM are passed to the JVM through the JAVA_TOOL_OPTIONS variable.

REM Note: freely derived from:
REM https://gist.github.com/PaulNeumann/d541b251e160038412b02d471a3f4704#file-sql-cmd
REM -------------------------------------------------------------------

SETLOCAL

REM =============================================================
REM Set JAVA_HOME folder
REM -------------------------------------------------------------

SET JAVA_HOME=F:\Produits\Java\Oracle\jdk-11.0.19

REM =============================================================
REM Set SQL_HOME folder
REM
REM This is the root directory of the installed SQLcl product;
REM e.g. %SQL_HOME%\bin\sql.exe is the included binary executable.
REM -------------------------------------------------------------

SET SQL_HOME=F:\Produits\Oracle\SQLcl\sqlcl\sqlcl-23.3.0.270.1251

REM =============================================================
REM Set SQLPATH folder
REM
REM This sets the search path for scripts started with @ or @@.
REM If the SQLPATH environment variable is set, and the SQLPATH
REM folder contains a login.sql, SQLcl will run it.
REM -------------------------------------------------------------

IF DEFINED SQLPATH (
    SET SQLPATH=;%SQLPATH%
)
SET SQLPATH=E:\Home\romain\oracle\sqlcl%SQLPATH%

REM =============================================================
REM Set TNS_ADMIN folder
REM
REM If you want SQLcl to use a tnsnames.ora file, point the
REM TNS_ADMIN environment variable to the file's folder.
REM -------------------------------------------------------------

SET TNS_ADMIN=E:\Home\romain\SQL_Developer\tns_admin

REM =============================================================
REM Switch codepage to UTF-8
REM -------------------------------------------------------------

CHCP 65001 >NUL 2>&1

REM =============================================================
REM JVM arguments, to be passed through JAVA_TOOL_OPTIONS
REM (or _JAVA_OPTIONS if necessary)
REM -------------------------------------------------------------

SET STD_ARGS=-Dfile.encoding=UTF-8

REM Java heap size min/max
SET _JAVA_OPTIONS=%_JAVA_OPTIONS% -Xms512m -Xmx1600m

REM Set User language to English
SET STD_ARGS=%STD_ARGS% -Duser.language=en

REM Set java.io.tmpdir
SET STD_ARGS=%STD_ARGS% -Djava.io.tmpdir=E:\Home\romain\.java-temp

REM Set logging configuration
IF DEFINED LOGGING_CONFIG (
    SET STD_ARGS=%STD_ARGS% -Djava.util.logging.config.file=%LOGGING_CONFIG%
)
 
set JAVA_TOOL_OPTIONS=%STD_ARGS%

REM =============================================================
REM Unset ORACLE_HOME, otherwise sql.exe picks it as the location
REM of the JDBC driver; comment this line if that is expected.
REM -------------------------------------------------------------

set ORACLE_HOME=

REM =============================================================
REM All set, let's start SQLcl
REM -------------------------------------------------------------

"%SQL_HOME%\bin\sql.exe" %*

ENDLOCAL
