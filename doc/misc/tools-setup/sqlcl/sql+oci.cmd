@ECHO OFF

REM =============================================================
REM sql.cmd -- wrapper script for starting SQLcl under Windows 7
REM =============================================================

REM #########################################################################################
REM Origin: https://gist.github.com/PaulNeumann/d541b251e160038412b02d471a3f4704#file-sql-cmd
REM #########################################################################################

SETLOCAL

REM =============================================================
REM Set JAVA_HOME folder
REM
REM If the computer has SQL Developer _with the embedded JDK_,
REM SQLcl can use that JDK, if you want it to. Otherwise, point
REM JAVA_HOME to your preferred JDK.
REM -------------------------------------------------------------

SET JAVA_HOME=F:\Produits\Win_7\Oracle\SQLDeveloper\sqldeveloper-22.2.1.234.1810-x64\jdk\jre
REM -- java.version= 11.0.16.1

REM =============================================================
REM Set SQL_HOME folder
REM
REM This is the root directory of the installed SQLcl product;
REM e.g. %SQL_HOME%\bin\sql.exe is the included binary executable.
REM -------------------------------------------------------------

SET SQL_HOME=F:\Produits\Win_7\Oracle\SQLcl\sqlcl\sqlcl-22.2.1.201.1451

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
REM Set the classpath and JVM arguments
REM -------------------------------------------------------------

REM Required for jdbc:oci: the OCI native driver from the Oracle Client
REM must be found in the classpath before any other Oracle JDBC driver.
REM The ORACLE_HOME env. variable is set in the calling environment.

SET CPFILE=%ORACLE_HOME%\ojdbc8.jar

REM add all SQLcl libraries to classpath
SET CPFILE=%CPFILE%;%SQL_HOME%\lib\dbtools-sqlcl.jar;%SQL_HOME%\lib\*;%SQL_HOME%\lib\ext\*

REM Set JVM arguments
SET STD_ARGS=-Djava.awt.headless=true -Dfile.encoding=UTF-8 -Xss10M

REM Java heap size min/max
SET STD_ARGS=%STD_ARGS% -Xms512m -Xmx1600m

REM Set User language to English
SET STD_ARGS=%STD_ARGS% -Duser.language=en

REM Set java.io.tmpdir
SET STD_ARGS=%STD_ARGS% -Djava.io.tmpdir=E:\Home\romain\.java-temp

REM !!! ONLY IF USING THE JAVA 11 JDK !!!
REM Inhibit Nashorn deprecation warning
SET STD_ARGS=%STD_ARGS% -Dnashorn.args=--no-deprecation-warning

REM Set logging configuration
IF DEFINED LOGGING_CONFIG (
    SET STD_ARGS=%STD_ARGS% -Djava.util.logging.config.file=%LOGGING_CONFIG%
)


REM =============================================================
REM All set, let's start SQLcl
REM -------------------------------------------------------------

"%JAVA_HOME%\bin\java" %STD_ARGS% -cp "%CPFILE%" oracle.dbtools.raptor.scriptrunner.cmdline.SqlCli %*

ENDLOCAL
