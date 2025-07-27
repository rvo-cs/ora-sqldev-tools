#!/bin/ksh
#
# SPDX-FileCopyrightText: 2023-2024 R.Vassallo
# SPDX-License-Identifier: BSD Zero Clause License
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
# Remarks:
#  a) Releases of SQLcl "stand-alone" 22.x and higher
#     require the JDK 11 or 17 (SQLcl 21.4 was the last
#     release using Java 8); SQLcl 25.2 and higher require
#     the JDK 17 or 21.
#
#  b) JavaScript support requires GraalVM for Java 17,
#     with the JavaScript runtime plugin (GraalVM has
#     been supported since SQLcl 23.3).
#--------------------------------------------------------------

JAVA_HOME=/usr/local/share/java/oracle/graalvm-jdk-17.0.13+10.1

#==============================================================
# SQL_HOME folder
#
# This is the root directory of the installed SQLcl product,
# such that ${SQL_HOME}/bin/sql is the included launching
# bash shell script.
#--------------------------------------------------------------

SQL_HOME=/usr/local/share/oracle/sqlcl/sqlcl-25.2.2.199.0918

#==============================================================
# Additions to SQLPATH
#
# The SQLPATH environment variable defines the default search
# path for scripts started with START or @. If it is set, and
# one folder in that list contains a login.sql, SQLcl will run
# it after login into the database, and upon start if it is
# started with /nolog.
#
# Use the SQLPATH_PREPEND parameter to set folder(s) to be
# added to the beginning of the SQLPATH environment variable.
#
# Use the SQLPATH_APPEND parameter to set folder(s) to be
# added to the end of the SQLPATH environment variable.
#--------------------------------------------------------------

SQLPATH_PREPEND=${HOME}/work/sqlcl

SQLPATH_APPEND=

#==============================================================
# Localization
#
# Set SQLCL_USER_LANGUAGE to set SQLcl into that language
#--------------------------------------------------------------

SQLCL_USER_LANGUAGE=en

#==============================================================
# TNS_ADMIN folder
#
# If you want SQLcl to use a tnsnames.ora file, set the
# TNS_ADMIN environment variable to that file's folder.
#--------------------------------------------------------------

#TNS_ADMIN=/path/to/tns_admin

#==============================================================
# Unset or keep ORACLE_HOME?
#
# If the ORACLE_HOME environment variable is set, the `sql`
# starting script will pick it as the location of the JDBC
# driver; this is needed for using the JDBC OCI driver.
# Therefore, in order to use the JDBC thin driver bundled with
# SQLcl, the ORACLE_HOME environment variable must be unset.
#
# Set the SQLCL_KEEP_ORACLE_HOME parameter for preserving the
# ORACLE_HOME environment variable, otherwise we'll unset it
# before calling the `sql` starting script.
#--------------------------------------------------------------

#SQLCL_KEEP_ORACLE_HOME=true

#==============================================================
# JVM settings
#
# Set SQLCL_JAVA_HEAPSIZE_MIN_MAX if you want to use specific
# min/max sizes for the Java heap, rather than the defaults.
#
# Set SQLCL_JAVA_IO_TMPDIR if you want to use a specific
# directory for Java temporary files, rather than the default.
#--------------------------------------------------------------

SQLCL_JAVA_HEAPSIZE_MIN_MAX="-Xms512m -Xmx1600m"

SQLCL_JAVA_IO_TMPDIR=${HOME}/temp/sqlcl/.java-temp


# @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
# @@@@@ NO USER CONFIGURATION IS EXPECTED BELOW THIS LINE @@@@@
# @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

if [[ -n "${SQLPATH_PREPEND:+X}" ]]; then
    SQLPATH="${SQLPATH_PREPEND}${SQLPATH:+:}${SQLPATH:-}"
fi

if [[ -n "${SQLPATH_APPEND:+X}" ]]; then
    SQLPATH="${SQLPATH:-}${SQLPATH:+:}${SQLPATH_APPEND}"
fi

[[ -n "${JAVA_HOME:+X}" ]] && export JAVA_HOME
[[ -n "${SQLPATH:+X}"   ]] && export SQLPATH
[[ -n "${TNS_ADMIN:+X}" ]] && export TNS_ADMIN

#---------------------
# Use an UTF-8 locale

export LC_ALL=en_US.UTF-8

#-------------------------------------------------------
# JVM arguments, to be passed through JAVA_TOOL_OPTIONS
# (or _JAVA_OPTIONS if necessary) 

if [[ -n "${SQLCL_JAVA_HEAPSIZE_MIN_MAX:+X}" ]]; then
    _JAVA_OPTIONS="${_JAVA_OPTIONS:-} ${SQLCL_JAVA_HEAPSIZE_MIN_MAX}"
fi

JVM_OPTS="-Dfile.encoding=UTF-8"

if [[ -n "${SQLCL_USER_LANGUAGE:+X}" ]]; then
    JVM_OPTS="${JVM_OPTS} -Duser.language=${SQLCL_USER_LANGUAGE}"
fi

if [[ -n "${SQLCL_JAVA_IO_TMPDIR:+X}" ]]; then
    JVM_OPTS="${JVM_OPTS} -Djava.io.tmpdir=${SQLCL_JAVA_IO_TMPDIR}"
fi

# Disable the error URL mention in JDBC error messages
JVM_OPTS="${JVM_OPTS} -Doracle.jdbc.enableErrorUrl=false"

# Set logging configuration
if [[ -n "${LOGGING_CONFIG:+X}" ]]; then
    JVM_OPTS="${JVM_OPTS} -Djava.util.logging.config.file=${LOGGING_CONFIG}"
fi
 
JAVA_TOOL_OPTIONS="${JVM_OPTS}${JAVA_TOOL_OPTIONS:+ }${JAVA_TOOL_OPTIONS:-}"

[[ -n "${_JAVA_OPTIONS:+X}" ]] && export _JAVA_OPTIONS

export JAVA_TOOL_OPTIONS

#------------------------------------------------------------
# Unset ORACLE_HOME, unless we're explicitly required not to

typeset -u KEEP_ORACLE_HOME="${SQLCL_KEEP_ORACLE_HOME:-}"

case "${KEEP_ORACLE_HOME}" in
    FALSE|NO|N|"") unset ORACLE_HOME ;;
esac

#------------------------------------------------------------
# SQLcl 23.4 and earlier: the supplied sql launching script
# picks the JDK from the PATH, rather that using the one
# specified by the JAVA_HOME environment variable. Therefore
# we must put ${JAVA_HOME}/bin first in the PATH, in order
# to guarantee that it will be used as expected.

PATH=${JAVA_HOME}/bin${PATH:+:}${PATH:-}

export PATH

#----------------------
# Finally, start SQLcl

if (($# == 0)); then
    exec ${SQL_HOME}/bin/sql
else
    exec ${SQL_HOME}/bin/sql "$@"
fi

