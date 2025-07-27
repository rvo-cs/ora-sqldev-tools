@ECHO OFF
REM SPDX-FileCopyrightText: 2024 R.Vassallo
REM SPDX-License-Identifier: BSD Zero Clause License

REM ==================================================================
REM sql.cmd -- wrapper script for starting SQLcl under Windows 7/10/11
REM
REM Note: using the bundled JDBC thin driver
REM
REM IMPORTANT: For use with SQLcl 22.x or higher
REM
REM Note: this script was derived from Paul Neumann's sql.cmd
REM (https://gist.github.com/PaulNeumann/d541b251e160038412b02d471a3f4704#file-sql-cmd)
REM with changes and additions in order to: (i) tailor it to my own
REM requirements, and: (ii) keep it in sync with the reference `sql`
REM bash starter script bundled with SQLcl, so it can be used along
REM with the latest versions of the product.
REM ==================================================================

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
REM        the JDK 17 or 21.
REM
REM     b) JavaScript support requires GraalVM for Java 17,
REM        with the JavaScript runtime plugin (GraalVM has
REM        been supported since SQLcl 23.3).
REM
REM     c) in general, the JDK shipped with SQL Developer in the
REM        "with JDK included" bundle can be used, provided it's
REM        recent enough, and JavaScript support is not needed.
REM        (If JavaScript is required, then GraalVM is currently
REM        the only option.)
REM -------------------------------------------------------------

SET JAVA_HOME=F:\Produits\Java\Oracle\graalvm-jdk-17.0.13+10.1

REM =============================================================
REM SQL_HOME folder
REM
REM This is the root directory of the installed SQLcl product,
REM such that %SQL_HOME%\bin\sql.exe is the included binary
REM executable for Windows x64.
REM -------------------------------------------------------------

SET SQL_HOME=F:\Produits\Oracle\SQLcl\sqlcl\sqlcl-25.2.2.199.0918

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

REM ------------------
REM Set JVM arguments

SET JVM_OPTS=-Djava.awt.headless=true -Dfile.encoding=UTF-8
SET JVM_OPTS=%JVM_OPTS% -Dpolyglot.engine.WarnInterpreterOnly=false
SET JVM_OPTS=%JVM_OPTS% -Xss100m
SET JVM_OPTS=%JVM_OPTS% -XX:+IgnoreUnrecognizedVMOptions
REM SET JVM_OPTS=%JVM_OPTS% -XX:+PrintFlagsFinal

IF DEFINED SQLCL_JAVA_HEAPSIZE_MIN_MAX (
    SET JVM_OPTS=%JVM_OPTS% %SQLCL_JAVA_HEAPSIZE_MIN_MAX%
    SET SQLCL_JAVA_HEAPSIZE_MIN_MAX=
)
IF DEFINED SQLCL_USER_LANGUAGE (
    SET JVM_OPTS=%JVM_OPTS% -Duser.language=%SQLCL_USER_LANGUAGE%
    SET SQLCL_USER_LANGUAGE=
)
IF DEFINED SQLCL_JAVA_IO_TMPDIR (
    SET JVM_OPTS=%JVM_OPTS% -Djava.io.tmpdir=%SQLCL_JAVA_IO_TMPDIR%
    SET SQLCL_JAVA_IO_TMPDIR=
)

REM Inhibit warnings about illegal reflective access when reading the Windows registry
SET JVM_OPTS=%JVM_OPTS% --add-opens=java.prefs/java.util.prefs=ALL-UNNAMED
REM ... and about reflective access by JLine to private static class of ProcessBuilder
SET JVM_OPTS=%JVM_OPTS% --add-opens=java.base/java.lang=ALL-UNNAMED

REM Inhibit Nashorn deprecation warning
SET JVM_OPTS=%JVM_OPTS% -Dnashorn.args=--no-deprecation-warning

REM Enable graal scripts
SET JVM_OPTS=%JVM_OPTS% -Dpolyglot.js.nashorn-compat=true

REM Force using the supplied JDBC thin driver (SQLcl >= 24.2)
SET JVM_OPTS=%JVM_OPTS% -Doracle.sqlcl.skipOracleHome=true

REM Disable the error URL mention in JDBC error messages
SET JVM_OPTS=%JVM_OPTS% -Doracle.jdbc.enableErrorUrl=false

REM SQLcl >= 25.2
SET JVM_OPTS=%JVM_OPTS% -Dsqlcl.home=%SQL_HOME%

REM Set logging configuration
IF DEFINED LOGGING_CONFIG (
    SET JVM_OPTS=%JVM_OPTS% -Djava.util.logging.config.file=%LOGGING_CONFIG%
)

REM -----------------------
REM Set the Java classpath
REM
REM Remark: simple approach here so far: all the JARs shipped with SQLcl
REM are put in the classpath (as opposed to enumerating them one by one),
REM with dbtools-sqlcl.jar in 1st position.

SET CPLIST=%SQL_HOME%\lib\dbtools-sqlcl.jar;%SQL_HOME%\lib\*;%SQL_HOME%\lib\ext\*

REM ---------------------
REM Finally, start SQLcl

"%JAVA_HOME%\bin\java" %JVM_OPTS% -cp "%CPLIST%" oracle.dbtools.raptor.scriptrunner.cmdline.SqlCli %*

ENDLOCAL
