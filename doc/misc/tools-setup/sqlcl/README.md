## Contents

* **[sql.cmd](sql.cmd)**:              command file for starting SQLcl under Windows
* **[login-scripts](login-scripts)/**  contains the `login.sql` file and related files.

## Setup

### ConEmu configuration

For convenience, I run SQLcl in a 
[ConEmu](https://conemu.github.io/en/TableOfContents.html) (v201101)
console terminal.

ConEmu is configured to start a `Shells::cmd` task with following additions to the Environment:
```
chcp utf-8

alias sqlcl="F:\Produits\Oracle\SQLcl\sql.cmd" $*
```

The `alias` command is a ConEmu feature (actually a wrapper around `doskey.exe`)
for defining command aliases. Here this enables to start SQLcl with the following
simple command:

```
sqlcl /nolog
```

### The `sql.cmd` command file

The [`sql.cmd`](sql.cmd) file is the preferred way to start SQLcl.

This script:
1. switches the codepage to UTF-8
2. sets required/useful environment variables for SQLcl
3. sets the JVM arguments, and other SQLcl command-line flags
4. and finally, starts the JVM with the right arguments, main class, and classpath to get 
   SQLcl to run.

#### Environment variables

The following environment variables are set by the `sql.cmd` script. In principle, these
variables work in SQLcl just as they do in SQL\*Plus.

| Variable   | Value                                 | Description                                         |
|:-----------|:--------------------------------------|:----------------------------------------------------|
| SQLPATH    | `E:\Home\...\oracle\sqlcl`            | Search path for scripts started using the `@file` syntax—also the directory where the [`login.sql`](login-scripts/login.sql) file will be put |
| TNS\_ADMIN | `E:\Home\...\SQL_Developer\tns_admin` | Location of the `tnsnames.ora`, `sqlnet.ora` files  |

For convenience, I use the same TNS\_ADMIN directory for SQLcl and SQL Developer.

### Windows console, with native JDBC OCI driver

As an alternative to ConEmu, the standard Windows console may be used, along with the 65001 codepage
(aka utf-8) and a unicode-ready font. A shortcut in the Windows Start Menu with the following target:

`C:\Windows\System32\cmd.exe /k "E:\...\sqlplus\env_sqlcl.cmd"`

can be used. The [`env_sqlcl.cmd`](env_sqlcl.cmd) file initializes the console environment, 
and creates the following aliases (using doskey):
* `sqlcl`: starts SQLcl (same as if using ConEmu)
* `sqlcl-oci`: starts SQLcl in OCI mode, using the native JDBC OCI driver
   (see [`sql+oci.cmd`](sql+oci.cmd))
* `sqldev`: starts SQL Developer

Additionally, this scripts sets ORACLE_HOME for Oracle Instant Client and puts %ORACLE_HOME%
at the beginning of the PATH. This is a requirement for using the native JDBC OCI driver
in SQL Developer.
