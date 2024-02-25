@ECHO OFF

REM ==================================================================
REM sql.cmd -- wrapper script for starting SQLcl under Windows 7/10/11
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
REM Set the classpath and JVM arguments
REM -------------------------------------------------------------

REM Add all SQLcl libraries to classpath
SET CPFILE=%SQL_HOME%\lib\dbtools-sqlcl.jar;%SQL_HOME%\lib\*;%SQL_HOME%\lib\ext\*

REM Set JVM arguments
SET STD_ARGS=-Djava.awt.headless=true -Dfile.encoding=UTF-8
SET STD_ARGS=%STD_ARGS% -Dpolyglot.engine.WarnInterpreterOnly=false
SET STD_ARGS=%STD_ARGS% -Xss100m
SET STD_ARGS=%STD_ARGS% -XX:+IgnoreUnrecognizedVMOptions
REM SET STD_ARGS=%STD_ARGS% -XX:+PrintFlagsFinal

REM Java heap size min/max
SET STD_ARGS=%STD_ARGS% -Xms512m -Xmx1600m

REM Set User language to English
SET STD_ARGS=%STD_ARGS% -Duser.language=en

REM Set java.io.tmpdir
SET STD_ARGS=%STD_ARGS% -Djava.io.tmpdir=E:\Home\romain\.java-temp

REM cover up windows read registry warning
SET STD_ARGS=%STD_ARGS% --add-opens=java.prefs/java.util.prefs=ALL-UNNAMED
REM ... and reflective access by JLine to private static class of ProcessBuilder
SET STD_ARGS=%STD_ARGS% --add-opens=java.base/java.lang=ALL-UNNAMED

REM Inhibit Nashorn deprecation warning
SET STD_ARGS=%STD_ARGS% -Dnashorn.args=--no-deprecation-warning

REM enable graal scripts
SET STD_ARGS=%STD_ARGS% -Dpolyglot.js.nashorn-compat=true

REM Set logging configuration
IF DEFINED LOGGING_CONFIG (
    SET STD_ARGS=%STD_ARGS% -Djava.util.logging.config.file=%LOGGING_CONFIG%
)
 
REM =============================================================
REM All set, let's start SQLcl
REM -------------------------------------------------------------

"%JAVA_HOME%\bin\java" %STD_ARGS% -cp "%CPFILE%" oracle.dbtools.raptor.scriptrunner.cmdline.SqlCli %*

ENDLOCAL
