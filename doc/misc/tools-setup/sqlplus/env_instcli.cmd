@REM SPDX-FileCopyrightText: 2021 R.Vassallo
@REM SPDX-License-Identifier: BSD Zero Clause License

@REM ============================================================
@REM env_instcli.cmd -- initializations for Oracle Instant Client
@REM ------------------------------------------------------------

@ECHO OFF

set ORACLE_HOME=F:\Produits\Oracle\instantclient\instantclient_19_23

set PATH=%ORACLE_HOME%;%PATH%

set TNS_ADMIN=E:\Home\romain\SQL_Developer\tns_admin

set SQLPATH=E:\home\romain\oracle\sqlplus

set NLS_LANG=AMERICAN_AMERICA.WE8MSWIN1252
