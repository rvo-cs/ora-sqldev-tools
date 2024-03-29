## Contents

* **[env\_instcli.cmd](env_instcli.cmd)**: command file for setting up env. variables, in order to
  run SQL\*Plus in a CMD.exe terminal\
  (Remark: using Oracle Instant Client)
  
* **[login-scripts](login-scripts)/**  contains the `login.sql` file and related files.

## Setup

### Shortcut to cmd.exe with env. variables for SQL\*Plus

I've added a shortcut to the Windows Start menu, with the following target:

`C:\Windows\System32\cmd.exe /k "E:\...\sqlplus\env_instcli.cmd"`

(where `E:\...\sqlplus` is the directory where I place SQL\*Plus-related startup files.)

When that shortcut is used, a new cmd.exe process is started with the `env_instcli.cmd` file
run as an initialization script. 

### The `env_instcli.cmd` file

The `env_instcli.cmd` file sets the following environment variables:

| Variable      | Description                                                                                |
|:--------------|:-------------------------------------------------------------------------------------------|
| ORACLE\_HOME  | Directory where Oracle Instant Client is installed (not actually required but convenient). |
| PATH          | Added `%ORACLE_HOME%` in front of the PATH                                                 |
| TNS\_ADMIN    | Directory which contains `tnsnames.ora`, `sqlnet.ora`                                      |
| SQLPATH       | Default directory for searching for SQL files; the `login.sql` is expected to be there.    |
| NLS\_LANG     | E.g. `AMERICAN_AMERICA.WE8MSWIN1252`                                                       |

I set `SQLPATH` to `E:\...\sqlplus`, so `env_instcli.cmd` and `login.sql` (+ related files) are in the same location.



