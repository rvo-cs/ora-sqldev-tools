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

The SQL startup script is configured in the Preferences dialog (\*); that script is always
executed after logon to the database. There's no equivalent for SQL\*Plus `/nolog` mode. 

(\*) Path: Preferences dialog, "Database" root node, "Filename for connection startup script"
input field.

This is distinct from (and not to be confused with) the "Select default path to look for
scripts" field on the "Database" -> "Worksheet" node.

My startup script is named [sqldev-login.sql](login-scripts/sqldev-login.sql); more details
in the [login-scripts](login-scripts) directory.

### Features

Disabling unused features saves some RAM, and makes starting SQL Developer a little bit faster.
SQL Developer will warn if an attempt is made to disable a feature which is depended upon by
an as-yet enabled feature, and offer to either keep or disable both features together.

### Preferences

SQL Developer has plenty of Preferences settings! Which makes it hard to write a comprehensive
checklist in the first place. Following is an attempt to list the most important settings 
(in my opinion).

#### Environment

| Parameter | Value | Remarks |
|:-------|:-------|:------|
| Look and Feel | Windows | |
| Line Terminator | Line Feed (Unix/Mac) | Unsure about how new files are created |
| Encoding | ISO-8859-1 | |

#### Code Editor

| Parameter | Value | Remarks |
|:-------|:-------|:------|
|**Start in Read Only mode** | **Checked** | Prevents from unintentionally changing code directly in the database! |
|Link Stored Procedures to Files | Unchecked | |

#### Code Editor: Display

| Parameter | Value | Remarks |
|:-------|:-------|:------|
| Enable Text Anti-Aliasing | Checked | |
| Show Breadcrumbs | Checked | |
| Show Code Folding Margin | Checked | |
| Show Visible Right Margin | Checked, after col. 90 | | 

#### Code Editor: Font

| Parameter | Value | Remarks |
|:-------|:-------|:------|
| Font Name | Consolas | |
| Font Size | 13 | |

#### Code Editor: Format

| Parameter | Value | Remarks |
|:-------|:-------|:------|
| Autoformat Dictionary Objects SQL | Unchecked | |
| Indent spaces | 4 | |
| Identifiers case | Lower | |
| Keywords case | lower | |
| Convert Case Only | Unchecked | |

#### Code Editor: Advanced Format

| Parameter | Value | Remarks |
|:-------|:-------|:------|
|**General** | | |
|Keywords case | lower | |
|Identifiers case | lower | |
|**Alignment** | | |
|Columns and Table aliases | Checked | |
|Type Declarations | Checked | |
|Named Argument Separator `=>` | Checked | Seems broken in 20.4 |
|Right-Align Query Keywords | Unchecked | Goes along with line breaks after SELECT/FROM/WHERE |
|**Indentation** | | |
|Indent spaces | 4 | |
|Indent with | Spaces | |
|**Line Breaks** | | |
|On comma | After | Before looks good, too |
|Commas per line in procedure | 1 | |
|On concatenation | No breaks | |
|On Boolean connectors | Before | |
|On ANSI joins | Checked | |
|For compound_condition parenthesis | Unchecked | |
|On subqueries | Checked | |
|Max char line width | 110 | |
|Before line comments | Unchecked | |
|After statements | Double break | |
|SELECT/FROM/WHERE | Checked | Goes along with disabling right alignment of query keywords |
|IF/CASE/WHILE | Indented Actions, Inlined Conditions | |
|**White Space** | | |
|Around operators | Checked | |
|After commas | Checked | |
|Around parenthesis | Outside | |

#### Code Editor: Advanced Format: Custom Format

For experts only—I wouldn't touch that! :slightly_smiling_face:

#### Code Editor: Line Gutter

| Parameter | Value | Remarks |
|:-------|:-------|:------|
|Show Line Numbers | Checked | |

#### Code Editor: PL/SQL Syntax Colors

| Parameter | Value | Remarks |
|:-------|:-------|:------|
| PL/SQL Comment | Foreground: Red: 0, Green: 99, Blue:0 | + Default background |

#### Database

| Parameter | Value | Remarks |
|:-------|:-------|:------|
| Filename for connection startup script | `E:\home\...\SQL_Developer\startup\sqldev-login.sql` | Details [here](login-scripts#the-sqldev-loginsql-file) |



