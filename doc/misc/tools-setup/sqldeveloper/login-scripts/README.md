## Contents

| File | Description |
|:-----|:------------|
| [`sqldev-login.sql`](sqldev-login.sql)  | SQL file for session inits in SQL Developer. This is the configured "startup script" in Preferences |
| [`_sqldev-login.sql`](_sqldev-login.sql)  | A file read from `sqldev_login.sql` (see below). This is the actual "main startup script" |
| [`login-common-noconnect.sql`](login-common-noconnect.sql) | Common init. commands: settings which do not require being logged on to the database |
| [`login-common-aliases.sql`](login-common-aliases.sql) | Common init. commands: local definitions of command aliases |
| [`login-common-sessioninit.sql`](login-common-sessioninit.sql) | Common commands and SQL statements for initializing database sessions after logon, e.g. `alter session` statements, etc. |
| [`login-SCOTT.sql`](login-SCOTT.sql) | Sample user-specific part of the SQL startup file, for the SCOTT user (empty file, so far) |

## The `sqldev-login.sql` file

`sqldev-login.sql` is the configured "startup script" in SQL Developer's preferences.
This file contains a single line:
```
@E:\Home\...\SQL_Developer\startup\_sqldev-login.sql
```
which calls the `_sqldev-login.sql` file by specifying its _full path_.

Reason: bug in SQL Developer (tested in 20.2): calling sub-files with the `@@file` syntax
would not work if done directly in `sqldev-login.sql`, but would in `_sqldev-login.sql`—as
if preferences did not pass the startup script path to the `@@` command, whereas the first
`@` does define a path for subsequent use. As a result, the directory where the startup 
script and its sub-files are placed must be specified twice: first in the Preferences 
dialog, and second in the configured startup script itself.

## The `_sqldev-login.sql` file ("main" startup script)

The `_sqldev-login.sql` script calls sub-files, just as the `login.sql` files for 
[SQL\*Plus](../../sqlplus/login-scripts#the-loginsqlfile)
and [SQLcl](../../sqlplus/login-scripts#the-loginsqlfile).
This is more to keeps things analoguous than by necessity: SQL Developer does not have
a `/nolog` mode, so the startup script is always executed after logon to the database,
and furthermore, only after other initializations performed by SQL Developer
according to Preferences have taken place.

(Remark: this makes it possible to override some Preferences' settings, which should
be avoided, if possible.) 

