## Contents

| File | Description |
|:-----|:------------|
| [`sqldev-login.sql`](sqldev-login.sql)  | SQL file for session inits in SQL Developer. This is the configured "startup script" in Preferences |
| [`_sqldev-login.sql`](_sqldev-login.sql)  | A file read from `sqldev_login.sql` (see below). This is the actual "main" startup script |
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
which calls the `_sqldev-login.sql` file _with its full path soecified_.

Reason: bug in SQL Developer (tested in 20.2): calling sub-files with the `@@file` syntax
would not work if done directly in `sqldev-login.sql`, but would in `_sqldev-login.sql`—as
if preferences did not pass the startup script path to the `@@` command, whereas the first
`@` defines a path for subsequent use. As a result, the directory where the startup 
script and its sub-files are placed must be specified twice: first in the Preferences 
dialog; second in the configured startup script itself.

## The `_sqldev-login.sql` file ("main" startup script)

The `_sqldev-login.sql` script calls sub-files, by analogy to the `login.sql` files of 
SQL\*Plus and SQLcl. This is more to keep things similar than by necessity: SQL Developer
does not have a `/nolog` mode, so the startup script is always executed after logon to
the database. And additionally, only after other initializations performed by SQL Developer
to honor Preferences.

(Remark: this makes it possible to override Preferences settings from the startup
script, which should be avoided, if possible.) 

The `_sqldev-login.sql` script reads as follows:
```
@@login-common-noconnect.sql

@@login-common-sessioninit.sql

@@login-&_USER..sql
```
The first sub-file, [`login-common-noconnect.sql`](login-common-noconnect.sql), contains
the usual SQL\*Plus `SET` commands, and also calls the 
[`login-common-aliases.sql`](login-common-aliases.sql) file, where definitions
of command aliases should go.

The second sub-file, [`login-common-sessioninit.sql`](login-common-sessioninit.sql), is
for `alter session` statements mostly, as needed. At of now this is useful for PL/SQL
compilation settings (which seem to be treated oddly in SQL Developer's preferences).

The last sub-file, `login-&_USER..sql`, is the user-specific part: the `_USER` substitution
variable is set automatically to the username (downside: 1 file per username—regardless
of target DB). An error message appears in the "Messages - Log" panel if that file is not
found, e.g.:
```
@@login-&_USER..sql
Error report -
SP2-0310: Unable to open file: "login-SYS.sql"
```
That message can be ignored.

