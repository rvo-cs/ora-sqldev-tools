@REM SPDX-FileCopyrightText: 2023-2024 R.Vassallo
@REM SPDX-License-Identifier: BSD Zero Clause License

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

SET JAVA_HOME=F:\Produits\Java\Oracle\jdk-11.0.23

REM =============================================================
REM SQL_HOME folder
REM
REM This is the root directory of the installed SQLcl product,
REM such that %SQL_HOME%\bin\sql.exe is the included binary
REM executable for Windows x64.
REM -------------------------------------------------------------

SET SQL_HOME=F:\Produits\Oracle\SQLcl\sqlcl\sqlcl-24.2.0.180.1721

REM =============================================================
REM Additions to SQLPATH
REM
REM The SQLPATH environment variable defines the default search
REM path for scripts started with START or @. If it is set, and
REM one folder in that list contains a login.sql, SQLcl will run
REM it after login into the database, and upon start if it is
REM started with /nolog.
REM
REM Use the SQLPATH_PREPEND variable to set folder(s) to be added
REM to the beginning of the SQLPATH environment variable.
REM
REM Use the SQLPATH_APPEND variable to set folder(s) to be added
REM to the end of the SQLPATH environment variable.
REM -------------------------------------------------------------

SET SQLPATH_PREPEND=E:\Home\romain\oracle\sqlcl

SET SQLPATH_APPEND=

REM =============================================================
REM Localization
REM
REM Set SQLCL_USER_LANGUAGE to set SQLcl into that language
REM -------------------------------------------------------------

SET SQLCL_USER_LANGUAGE=en

REM =============================================================
REM TNS_ADMIN folder
REM
REM If you want SQLcl to use a tnsnames.ora file, set the
REM TNS_ADMIN environment variable to that file's directory.
REM -------------------------------------------------------------

SET TNS_ADMIN=E:\Home\romain\SQL_Developer\tns_admin

REM =============================================================
REM JVM settings
REM
REM Set SQLCL_JAVA_HEAPSIZE_MIN_MAX if you want to use specific
REM min/max sizes for the Java heap, rather than the defaults.
REM
REM Set SQLCL_JAVA_IO_TMPDIR if you want to use a specific
REM directory for Java temporary files, rather than the default.
REM -------------------------------------------------------------

SET SQLCL_JAVA_HEAPSIZE_MIN_MAX=-Xms512m -Xmx1600m

SET SQLCL_JAVA_IO_TMPDIR=E:\Home\romain\.java-temp


REM @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
REM @@@@@ NO USER CONFIGURATION IS EXPECTED BELOW THIS LINE @@@@@
REM @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

REM ---------------------------------
REM Adjust the SQLPATH env. variable

IF DEFINED SQLPATH (
    SET SQLPATH_SEP=;
)
IF DEFINED SQLPATH_PREPEND (
    SET SQLPATH=%SQLPATH_PREPEND%%SQLPATH_SEP%%SQLPATH%
    SET SQLPATH_PREPEND=
    SET SQLPATH_SEP=;
)
IF DEFINED SQLPATH_APPEND (
    SET SQLPATH=%SQLPATH%%SQLPATH_SEP%%SQLPATH_APPEND%
    SET SQLPATH_APPEND=
)
SET SQLPATH_SEP=

REM -----------------------------
REM Switch the codepage to UTF-8

CHCP 65001 >NUL 2>&1

REM -------------------------------------------------------
REM JVM arguments, to be passed through JAVA_TOOL_OPTIONS,
REM or _JAVA_OPTIONS if necessary

IF DEFINED SQLCL_JAVA_HEAPSIZE_MIN_MAX (
    SET _JAVA_OPTIONS=%_JAVA_OPTIONS% %SQLCL_JAVA_HEAPSIZE_MIN_MAX%
    SET SQLCL_JAVA_HEAPSIZE_MIN_MAX=
)

SET JVM_OPTS=-Dfile.encoding=UTF-8

IF DEFINED SQLCL_USER_LANGUAGE (
    SET JVM_OPTS=%JVM_OPTS% -Duser.language=%SQLCL_USER_LANGUAGE%
    SET SQLCL_USER_LANGUAGE=
)
IF DEFINED SQLCL_JAVA_IO_TMPDIR (
    SET JVM_OPTS=%JVM_OPTS% -Djava.io.tmpdir=%SQLCL_JAVA_IO_TMPDIR%
    SET SQLCL_JAVA_IO_TMPDIR=
)

REM Set logging configuration
IF DEFINED LOGGING_CONFIG (
    SET JVM_OPTS=%JVM_OPTS% -Djava.util.logging.config.file=%LOGGING_CONFIG%
)
 
set JAVA_TOOL_OPTIONS=%JVM_OPTS%

REM -------------------------------------------------------------
REM Unset ORACLE_HOME, otherwise sql.exe picks it as the location
REM of the JDBC driver; comment this line if that is expected
REM (e.g. if using the jdbc:oci driver)

set ORACLE_HOME=

REM ---------------------
REM Finally, start SQLcl

"%SQL_HOME%\bin\sql.exe" %*

ENDLOCAL
