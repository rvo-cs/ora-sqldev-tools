Login SQL scripts in SQLcl work almost exactly as they do in SQL\*Plus, so they'll be
vastly similar. Possibly with additional _command aliases_, an enhancement over
SQL\*Plus substitution variables. 

## Contents

| File | Description |
|:-----|:------------|
| [`login.sql`](login.sql)  | SQL file for session initialization in SQLcl. This is the "main file", which calls sub-files for technical reasons |
| [`login-common-noconnect.sql`](login-common-noconnect.sql) | Common init. commands: settings which do not require being logged on to the database |
| [`login-common-aliases.sql`](login-common-aliases.sql) | Common init. commands: local definitions of command aliases |
| [`login-common-sessioninit.sql`](login-common-sessioninit.sql) | Common commands and SQL statements for initializing database sessions after logon, e.g. `alter session` statements, etc. |
| [`login-PUBLIC.sql`](login-PUBLIC.sql) | Template file for the user-specific part of the login SQL file |
| [`login-.sql`](login-.sql) | A file deliberately left empty |
| [`login-sys.sql`](login-sys.sql) | Sample user-specific part of the login SQL file, for the SYS user |
| [`login-pdb_admin.sql`](login-pdb_admin.sql) | Sample user-specific part of the login SQL file, for a user named PDB_ADMIN |

## The `login.sql`file

The `login.sql`file reads as follows:
```
@@login-common-noconnect

@@login-&_USER
```
That file is called:
* When SQLcl is started in `/nolog` mode; in that case, the `_USER` substitution variable is void (`""`)
* For each database logon; the `_USER` substitution variable is set to the database username.

So the trick is to:
1. Put all common initialization commands (e.g. `SET ARRAYSIZE 200`) which do not actually require being 
   logged on to the DB in the [`login-common-noconnect.sql`](login-common-noconnect.sql) file
2. Put user-specific init. commands, _and_ SQL commands which can only be run after having logged on,
   into the `login-&_USER.sql` file (downside: 1 file per username). Common session-initializing statements
   (e.g. `alter session set NLS_DATE_FORMAT...` go into the
   [`login-common-sessioninit.sql`](login-common-sessioninit.sql) file, which is meant to be called
   from each `login-&_USER.sql` file.
