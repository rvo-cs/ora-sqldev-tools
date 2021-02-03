## Configuring SQL Developer

### Additions to the `sqldeveloper.conf` file

Path: `sqldeveloper\bin\sqldeveloper.conf` (from the top product directory) 

There's little to add to that file, except maybe the following:

```
# Force English language in UI
AddVMOption -Duser.language=en

# Work-around for spurious connection resets? 
#AddVMOption -Doracle.net.disableOob=true

# Store the profile under AppData\Local instead of AppData\Roaming
#AddVMOption -Dide.user.dir=C:\Users\romain\AppData\Local\SQL_Developer
```

As of now (using SQL Developer 20.4) I only use the first of the above properties.

Disabling out-of-band breaks in JDBC Thin could turn out to be useful in 20.3; not sure if
that's still needed in 20.4.

Similarly, switching from AppData\Roaming to AppData\Local was useful on sites using roaming
profiles together with limited quotas. This seems out of fashion these days.

### Heap space settings

Should that be necessary, the properties for sizing the JVM heap space are in the following file:

`%APPDATA%\sqldeveloper\20.4.0\product.conf`

(with `APPDATA` = `C:\Users\xxxx\AppData\Roaming` usually.)


### Startup script

The SQL startup script is configured in the Preferences dialog (\*); that script is always executed after 
logon to the database. There's no equivalent for SQL\*Plus `/nolog` mode. 

(\*) Path: Preferences dialog, "Database" root node, "Filename for connection startup script" input field.

This is distinct from (and not to be confused with) the "Select default path to look for scripts" field on the "Database" -> "Worksheet" node.

My startup script is named [sqldev-login.sql](login-scripts/sqldev-login.sql); more details in the [login-scripts](login-scripts) directory.

### Preferences

\[To be continued...\]
