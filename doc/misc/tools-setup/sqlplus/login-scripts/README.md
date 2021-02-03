## Contents

| File | Description |
|:-----|:------------|
| [`login.sql`](login.sql)  | SQL file for session initialization in SQL\*Plus. This is the main file, which calls sub-files for technical reasons |
| [`login-common-noconnect.sql`](login-common-noconnect.sql) | Common initializations which do not require being actually logged on to the database |
| [`login-.sql`](login-.sql) | A file left deliberately empty |
| [`login-common-sessioninit.sql`](login-common-sessioninit.sql) | Common initializations for database sessions after logon, e.g. `alter session` statements |
| [`login-PUBLIC.sql`](login-PUBLIC.sql) | Template file for the user-specific part of the login SQL file |
| [`login-sys.sql`](login-sys.sql) | Sample user-specific part of the login SQL file, for the SYS user |
| [`login-pdb_admin.sql`](login-pdb_admin.sql) | Sample user-specific part of the login SQL file, for a user named PDB_ADMIN |

## The `login.sql`file

```
@@login-common-noconnect

@@login-&_USER
```

 This is run after starting SQL\*Plus in `/nolog` mode. 
