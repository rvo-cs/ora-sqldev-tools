#!/bin/ksh
#
# FILE
#   sql.ksh
#
# PURPOSE
#   Simple wrapper script for SQLcl
#
#   This script sets the proper environment configuration,
#   then calls the reference `sql` bash starter script from
#   the SQLcl bundle; settings are passed to the JVM through
#   the JAVA_TOOL_OPTIONS environment variable.
#

set -o nounset

#==============================================================
# JAVA_HOME folder
#
# This is the root directory of the JDK to be used for running
# SQLcl, such that the java command is ${JAVA_HOME}/bin/java
#
# Remark: releases of SQLcl "stand-alone" 22.x and higher
# require the JDK 11 or 17, with GraalVM being officially
# supported since SQLcl 23.3; SQLcl 21.4 was the last release
# using Java 8.
#--------------------------------------------------------------

JAVA_HOME=/usr/local/share/java/oracle/jdk-11.0.21

export JAVA_HOME

#==============================================================
# SQL_HOME folder
#
# This is the root directory of the installed SQLcl product,
# such that ${SQL_HOME}/bin/sql is the included launching
# bash shell script.
#--------------------------------------------------------------

SQL_HOME=/usr/local/share/oracle/sqlcl/sqlcl-23.4.0.023.2321

#==============================================================
# SQLPATH folder
#
# This sets the search path for scripts started with @ or @@.
# If the SQLPATH environment variable is set, and the SQLPATH
# folder contains a login.sql, SQLcl will run it.
# -------------------------------------------------------------

SQLPATH=${HOME}/work/sqlcl${SQLPATH:+:}${SQLPATH:-}

export SQLPATH

#==============================================================
# TNS_ADMIN folder
#
# If you want SQLcl to use a tnsnames.ora file, set the
# TNS_ADMIN environment variable to that file's folder.
#--------------------------------------------------------------

#TNS_ADMIN=/path/to/tns_admin

export TNS_ADMIN

#==============================================================
# Use an UTF-8 locale
#--------------------------------------------------------------

export LC_ALL=en_US.UTF-8

#==============================================================
# JVM arguments, to be passed through JAVA_TOOL_OPTIONS
# (or _JAVA_OPTIONS if necessary) 
#--------------------------------------------------------------

STD_ARGS=-Dfile.encoding=UTF-8

# Java heap size min/max
_JAVA_OPTIONS="${_JAVA_OPTIONS:-} -Xms512m -Xmx1600m"

# Set User language to English
STD_ARGS="${STD_ARGS} -Duser.language=en"

# Set java.io.tmpdir
STD_ARGS="${STD_ARGS} -Djava.io.tmpdir=${HOME}/temp/sqlcl/.java-temp"

# Set logging configuration
if [[ -n "${LOGGING_CONFIG:+X}" ]]; then
    STD_ARGS="${STD_ARGS} -Djava.util.logging.config.file=${LOGGING_CONFIG}"
fi
 
JAVA_TOOL_OPTIONS="${STD_ARGS}${JAVA_TOOL_OPTIONS:+ }${JAVA_TOOL_OPTIONS:-}"

export JAVA_TOOL_OPTIONS
export _JAVA_OPTIONS

#==============================================================
# Unset ORACLE_HOME, otherwise sql.exe picks it as the location
# of the JDBC driver; comment this line if that is expected.
#--------------------------------------------------------------

unset ORACLE_HOME

#==============================================================
# SQLcl 23.4 and earlier: the supplied sql launching script
# picks the JDK from the PATH, rather that using the one
# specified by the JAVA_HOME environment variable. Therefore
# we must put ${JAVA_HOME}/bin first in the PATH, in order
# to guarantee that it will be used as expected.
#--------------------------------------------------------------

PATH=${JAVA_HOME}/bin${PATH:+:}${PATH:-}

export PATH

#==============================================================
# All set, let's start SQLcl
#--------------------------------------------------------------

if (($# == 0)); then
    exec ${SQL_HOME}/bin/sql
else
    exec ${SQL_HOME}/bin/sql "$@"
fi

