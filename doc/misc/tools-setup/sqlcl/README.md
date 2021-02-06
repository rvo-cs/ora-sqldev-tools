## Contents

* **[sql.cmd](sql.cmd)**: command file for starting SQLcl under Windows
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
variables are used by SQLcl in exactly the same way as they would in SQL\*Plus.

| Variable | Value | Description |
|:---------|:------|:------------|
| SQLPATH  | `E:\Home\...\oracle\sqlcl` | Search path for scripts started using the `@file` syntax—also the directory where the [`login.sql`](login-scripts/login.sql) file will be put |
| TNS_ADMIN | `E:\Home\...\SQL_Developer\tns_admin` | Location of the `tnsnames.ora`, `sqlnet.ora` files |

For convenience, I use the same TNS_ADMIN directory for SQLcl and SQL Developer.


