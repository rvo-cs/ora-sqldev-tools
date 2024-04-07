## Contents

* **[env_sqlcl.cmd](env_sqlcl.cmd)**:  command file for setting up the environment in a Windows console (cmd.exe)
* **[sql.cmd](sql.cmd)**:              command file for starting SQLcl in a Windows console (cmd.exe)
* **[sql+oci.cmd](sql+oci.cmd)**:      similar to [sql.cmd](sql.cmd), but using JDBC OCI instead of JDBC Thin
* **[sqlw.cmd](sqlw.cmd)**:            wrapper script (as an alternative to [sql.cmd](sql.cmd)) for the bundled `sql.exe` binary for Windows
* **[sql.ksh](sql.ksh)**:              Korn shell wrapper script for the bundled `sql` Bash script
* **[login-scripts](login-scripts)/**  contains the `login.sql` file, plus related files.

## Setup

### Environment setup for the Windows console (cmd.exe)

I usually run SQLcl in a standard Windows console (cmd.exe), using the 65001 codepage
(aka utf-8) and a unicode-ready font.

For convenience, I have set a shortcut in the Windows Start Menu, with the following target:

`C:\Windows\System32\cmd.exe /k "E:\path_to\sqlcl\env_sqlcl.cmd"`

Where `E:\path_to\sqlcl` stands for a directory where I put my personal files related to SQLcl. This directory does
not have to (and probably should not) be the same as SQLcl's installation directory.

The [`env_sqlcl.cmd`](env_sqlcl.cmd) file initializes the console environment, 
and creates the following aliases (using doskey):
* `sqlcl`: starts SQLcl, by calling the [`sql.cmd`](sql.cmd) script
* `sqlcl-oci`: starts SQLcl with the native JDBC OCI driver, by calling the [`sql+oci.cmd`](sql+oci.cmd) script
* `sql-exe`: starts SQLcl, by calling the [`sqlw.cmd`](sqlw.cmd) wrapper script
* `sqldev`: starts SQL Developer

Additionally, this scripts sets ORACLE_HOME for Oracle Instant Client, and puts %ORACLE_HOME%
at the beginning of the PATH. This is required for using the native JDBC OCI driver in SQLcl /
SQL Developer.

### The `sql.cmd` command file

The [`sql.cmd`](sql.cmd) file is the preferred way to start SQLcl.

This script:
1. switches the codepage to UTF-8
2. sets required/useful environment variables for SQLcl
3. sets the JVM arguments, and other SQLcl command-line flags
4. and finally, starts the JVM with the right arguments, main class, and classpath to get 
   SQLcl to run.

#### Environment variables

The following environment variables are configured in the `sql.cmd` script. In principle, these variables
work in SQLcl just as they do in SQL\*Plus. Make sure you edit the script in order to _set your own values_ 
for these parameters.

| Variable   | Value                                 | Description                                         |
|:-----------|:--------------------------------------|:----------------------------------------------------|
| SQLPATH    | `E:\path_to\sqlcl`                    | Search path for scripts started using the `@file` syntax—also the directory where the [`login.sql`](login-scripts/login.sql) file will be put |
| TNS\_ADMIN | `E:\path_to\tns_admin`                | Location of the `tnsnames.ora`, `sqlnet.ora` files  |

For convenience, I use the same TNS\_ADMIN directory for SQLcl and SQL Developer.

### ConEmu configuration

I used to run SQLcl in a 
[ConEmu](https://conemu.github.io/en/TableOfContents.html) (v201101)
console terminal. I don't do it anymore, but I suppose it could still work.

ConEmu is configured to start a `Shells::cmd` task with following additions to the Environment:
```
chcp utf-8

alias sqlcl="F:\Produits\Oracle\SQLcl\sql.cmd" $*
```

The `alias` command is a ConEmu feature (actually a wrapper around `doskey.exe`)
for defining command aliases. This enables to start SQLcl with the following
simple command:

```
sqlcl /nolog
```
just as I do in the Windows console (cmd.exe) using a similar doskey alias.
