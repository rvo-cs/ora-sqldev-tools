## Contents

| File | Description |
|:-----|:------------|
| [`sqldev_login.sql`](sqldev_login.sql)  | SQL file for session inits in SQL Developer. This is the configured "startup script" in Preferences |
| [`_sqldev_login.sql`](_sqldev_login.sql)  | A file read from `sqldev_login.sql` (see below). This is the actual "main file" |
| [`login-common-noconnect.sql`](login-common-noconnect.sql) | Common init. commands: settings which do not require being logged on to the database |
| [`login-common-aliases.sql`](login-common-aliases.sql) | Common init. commands: local definitions of command aliases |
| [`login-common-sessioninit.sql`](login-common-sessioninit.sql) | Common commands and SQL statements for initializing database sessions after logon, e.g. `alter session` statements, etc. |
| [`login-SCOTT.sql`](login-SCOTT.sql) | Sample user-specific part of the SQL startup file, for the SCOTT user (empty file, so far) |
