@REM SPDX-FileCopyrightText: 2023-2026 R.Vassallo
@REM SPDX-License-Identifier: BSD Zero Clause License

@ECHO OFF

REM ===================================================================
REM sqlw.cmd -- wrapper script for starting SQLcl under Windows 7/10/11
REM
REM This version of the wrapper script calls the official sql.exe 
REM binary included in the SQLcl bundle for Windows. Settings are
REM passed to the JVM through the JDK_JAVA_OPTIONS and the
REM JAVA_TOOL_OPTIONS environment variables.
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
REM        release using Java 8); SQLcl 25.2 and higher require
REM        the JDK 17 or 21; SQLcl 26.2 and higher also support
REM        the JDK 25.
REM
REM     b) JavaScript support requires GraalVM for Java 17,
REM        with the JavaScript runtime plugin (GraalVM has
REM        been supported since SQLcl 23.3), or the GraalJS
REM        JavaScript engine module.
REM
REM     c) in general, the JDK shipped with SQL Developer in the
REM        "with JDK included" bundle can be used, provided it's
REM        recent enough, and JavaScript support is not needed.
REM        (Please see above if JavaScript is required.)
REM -------------------------------------------------------------

SET JAVA_HOME=F:\Produits\Java\OpenJDK\jdk-25.0.4.1+1

REM =============================================================
REM SQL_HOME folder
REM
REM This is the root directory of the installed SQLcl product,
REM such that %SQL_HOME%\bin\sql.exe is the included binary
REM executable for Windows x64.
REM -------------------------------------------------------------

SET SQL_HOME=F:\Produits\Oracle\SQLcl\sqlcl\sqlcl-26.2.1.209.2118

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
REM JVM arguments, to be passed through JDK_JAVA_OPTIONS
REM and JAVA_TOOL_OPTIONS as necessary

IF DEFINED SQLCL_JAVA_HEAPSIZE_MIN_MAX (
    SET JVM_OPTS=%JVM_OPTS% %SQLCL_JAVA_HEAPSIZE_MIN_MAX%
    SET SQLCL_JAVA_HEAPSIZE_MIN_MAX=
)

SET JVM_OPTS=%JVM_OPTS% -Dfile.encoding=UTF-8

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
    SET LOGGING_CONFIG=
)

REM ---vvvv--- GraalJS JavaScript engine [begin] ---vvvv---
REM Add the GraalJS engine
SET JVM_OPTS=%JVM_OPTS% --module-path F:\Produits\Java\GraalJS\lib
SET JVM_OPTS=%JVM_OPTS% --add-modules org.graalvm.polyglot
SET JVM_OPTS=%JVM_OPTS% --add-modules org.graalvm.js

REM Silence GraalJS warnings
SET JVM_OPTS=%JVM_OPTS% --enable-native-access=org.graalvm.truffle

REM Required if using JDK 25
SET JVM_OPTS=%JVM_OPTS% --sun-misc-unsafe-memory-access=allow

REM Silence restricted access warning
SET JVM_OPTS=%JVM_OPTS% --enable-native-access=ALL-UNNAMED

REM Enable Graal scripts
SET TOOL_OPTS=%TOOL_OPTS% -Dpolyglot.js.nashorn-compat=true

REM Silence Polyglot complaints about lack of native compilation for JavaScript
SET TOOL_OPTS=%TOOL_OPTS% -Dpolyglot.engine.WarnInterpreterOnly=false
REM ---^^^^--- GraalJS JavaScript engine [end] ---^^^^---

REM Force using the supplied JDBC thin driver (SQLcl >= 24.2)
SET TOOL_OPTS=%TOOL_OPTS% -Doracle.sqlcl.skipOracleHome=true

REM Disable the error URL mention in JDBC error messages
SET TOOL_OPTS=%TOOL_OPTS% -Doracle.jdbc.enableErrorUrl=false

REM SQLcl >= 25.2
SET TOOL_OPTS=%TOOL_OPTS% -Dsqlcl.home=%SQL_HOME%

SET JDK_JAVA_OPTIONS=%JVM_OPTS%
SET JVM_OPTS=
SET JAVA_TOOL_OPTIONS=%TOOL_OPTS%
SET TOOL_OPTS=

REM -------------------------------------------------------------
REM Unset ORACLE_HOME, otherwise sql.exe picks it as the location
REM of the JDBC driver; comment this line if that is expected
REM (e.g. if using the jdbc:oci driver)

set ORACLE_HOME=

REM ---------------------
REM Finally, start SQLcl

"%SQL_HOME%\bin\sql.exe" %*

ENDLOCAL
