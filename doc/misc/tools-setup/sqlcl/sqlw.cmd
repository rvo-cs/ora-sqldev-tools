@ECHO OFF

REM ===================================================================
REM sqlw.cmd -- wrapper script for starting SQLcl under Windows 7/10/11
REM
REM This version of the wrapper script calls the official sql.exe 
REM binary included in the SQLcl bundle for Windows. Settings are
REM passed to the JVM through the JAVA_TOOL_OPTIONS variable.
REM -------------------------------------------------------------------

SETLOCAL

REM =============================================================
REM JAVA_HOME folder
REM
REM This is the root directory of the JDK to be used for running
REM SQLcl, such that the java command is %JAVA_HOME%\bin\java.exe
REM
REM Remarks:
REM     a) Releases of SQLcl "stand-alone" 22.x and higher
REM        require the JDK 11 or 17 (SQLcl 21.4 was the last
REM        release using Java 8), with GraalVM being officially
REM        supported since SQLcl 23.3.
REM
REM     b) in general, the JDK shipped with SQL Developer in the
REM        "with JDK included" bundle can be used, provided it's
REM        recent enough.
REM -------------------------------------------------------------

SET JAVA_HOME=F:\Produits\Java\Oracle\jdk-11.0.19

REM =============================================================
REM SQL_HOME folder
REM
REM This is the root directory of the installed SQLcl product,
REM such that %SQL_HOME%\bin\sql.exe is the included binary
REM executable for Windows x64.
REM -------------------------------------------------------------

SET SQL_HOME=F:\Produits\Oracle\SQLcl\sqlcl\sqlcl-23.4.0.023.2321

REM =============================================================
REM SQLPATH folder
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
REM TNS_ADMIN folder
REM
REM If you want SQLcl to use a tnsnames.ora file, set the
REM TNS_ADMIN environment variable to that file's folder.
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
REM of the JDBC driver; comment this line if that is expected
REM (e.g. if using the jdbc:oci driver)
REM -------------------------------------------------------------

set ORACLE_HOME=

REM =============================================================
REM All set, let's start SQLcl
REM -------------------------------------------------------------

"%SQL_HOME%\bin\sql.exe" %*

ENDLOCAL
