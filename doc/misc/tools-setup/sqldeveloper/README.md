## Configuring SQL Developer

### Additions to the `sqldeveloper.conf` file

Path: `sqldeveloper\bin\sqldeveloper.conf` (from the top product directory) 

Add the following if necessary:

```
# Force English language in UI
AddVMOption -Duser.language=en

# Work-around for spurious connection resets? 
#AddVMOption -Doracle.net.disableOob=true

# Store the profile under AppData\Local instead of AppData\Roaming
#AddVMOption -Dide.user.dir=C:\Users\xxxx\AppData\Local\SQL_Developer
```

As of now (using SQL Developer 20.4) I only use the 1st of the above 3 properties.

Disabling out-of-band breaks in JDBC Thin could help in 20.2; not sure if
that's still necessary in 20.4.

Similarly, switching from AppData\Roaming to AppData\Local was useful on sites using roaming
profiles and small quotas. This seems out of fashion these days.

### Heap space settings

Should that be necessary, the properties for sizing the JVM heap space are in the following file:

`%APPDATA%\sqldeveloper\20.4.0\product.conf`

(with `APPDATA` = `C:\Users\xxxx\AppData\Roaming` usually.)


### Startup script

The SQL startup script is configured in the Preferences dialog (\*); that script is always
executed after logon to the database. There's no equivalent for SQL\*Plus `/nolog` mode. 

(\*) Path: Preferences dialog, ["Database" node](#database), "Filename for connection startup script"
input field.

This is distinct from (and not to be confused with) the "Select default path to look for
scripts" field on the "Database" -> ["Worksheet" node](#database-worksheet).

My startup script is named [sqldev-login.sql](login-scripts#the-sqldev-loginsql-file); more details
in the [login-scripts](login-scripts#contents) directory.

### Features

Disabling unused features saves some RAM, and makes startup a little faster.
SQL Developer will warn if an attempt is made to disable a feature depended upon by
another one, and offer to either keep or disable both features together.

### Preferences

SQL Developer has plenty of Preferences settings—too many to make a comprehensive
checklist! Following is an attempt to list the most important settings (in my opinion).

* [Environment](#environment)
* [Code Editor](#code-editor)
* [Code Editor: Format](#code-editor-format)
* [Code Editor: Advanced Format](#code-editor-advanced-format)
* [Database](#database)
* [Database: Advanced](#database-advanced)
* [Database: NLS](#database-nls)
* [Database: Worksheet](#database-worksheet)
* [Shortcut keys](#shortcut-keys)

#### Environment

| Parameter        | Value                | Remarks                         |
|:-----------------|:---------------------|:--------------------------------|
| Look and Feel    | Windows              |                                 |
| Line Terminator  | Line Feed (Unix/Mac) | This seems to work for existing files; unsure about newly created files |
| Encoding         | ISO-8859-1           |                                 |

#### Code Editor

| Parameter                        | Value        | Remarks                 |
|:---------------------------------|:-------------|:------------------------|
| **Start in Read Only mode**      | **Checked**  | Prevents from unintentionally changing code directly in the database! |
| Link Stored Procedures to Files  | Unchecked    |                         |

#### Code Editor: Display

| Parameter                  | Value                   | Remarks  |
|:---------------------------|:------------------------|:---------|
| Enable Text Anti-Aliasing  | Checked                 |          |
| Show Breadcrumbs           | Checked                 |          |
| Show Code Folding Margin   | Checked                 |          |
| Show Visible Right Margin  | Checked, after col. 90  |          | 

#### Code Editor: Font

| Parameter  | Value     | Remarks  |
|:-----------|:----------|:---------|
| Font Name  | Consolas  |          |
| Font Size  | 13        |          |

#### Code Editor: Format

| Parameter                          | Value      | Remarks  |
|:-----------------------------------|:-----------|:---------|
| Autoformat Dictionary Objects SQL  | Unchecked  |          |
| Indent spaces                      | 4          |          |
| Identifiers case                   | lower      |          |
| Keywords case                      | lower      |          |
| Convert Case Only                  | Unchecked  |          |

#### Code Editor: Advanced Format

| Parameter                            | Value         | Remarks                   |
|:-------------------------------------|:--------------|:--------------------------|
|**General**                           |               |                           |
| Keywords case                        | lower         |                           |
| Identifiers case                     | lower         |                           |
|**Alignment**                         |               |                           |
| Columns and Table aliases            | Checked       |                           |
| Type Declarations                    | Checked       |                           |
| Named Argument Separator `=>`        | Checked       | Seems broken in 20.4      |
| Right-Align Query Keywords           | Unchecked     | Goes along with line breaks after SELECT/FROM/WHERE |
|**Indentation**                       |               |                           |
| Indent spaces                        | 4             |                           |
| Indent with                          | Spaces        |                           |
|**Line Breaks**                       |               |                           |
| On comma                             | After         | Before looks good, too    |
| Commas per line in procedure         | 1             |                           |
| On concatenation                     | No breaks     |                           |
| On Boolean connectors                | Before        |                           |
| On ANSI joins                        | Checked       |                           |
| For compound\_condition parenthesis  | Unchecked     |                           |
| On subqueries                        | Checked       |                           |
| Max char line width                  | 110           |                           |
| Before line comments                 | Unchecked     |                           |
| After statements                     | Double break  |                           |
| SELECT/FROM/WHERE                    | Checked       | Goes along with disabling right alignment of query keywords |
| IF/CASE/WHILE                        | Indented Actions, Inlined Conditions  |      |
|**White Space**                       |               |                           |
| Around operators                     | Checked       |                           |
| After commas                         | Checked       |                           |
| Around parenthesis                   | Outside       |                           |

#### Code Editor: Advanced Format: Custom Format

For experts only—I wouldn't touch that! :slightly_smiling_face:

#### Code Editor: Line Gutter

| Parameter          | Value    | Remarks  |
|:-------------------|:---------|:---------|
| Show Line Numbers  | Checked  |          |

#### Code Editor: PL/SQL Syntax Colors

| Parameter       | Value                                  | Remarks                  |
|:----------------|:---------------------------------------|:-------------------------|
| PL/SQL Comment  | Foreground: Red: 0, Green: 99, Blue:0  | With default background  |

#### Database

| Parameter                               | Value                                                 | Remarks             |
|:----------------------------------------|:------------------------------------------------------|:--------------------|
| Filename for connection startup script  | `E:\home\...\SQL_Developer\startup\sqldev-login.sql`  | Details [here](login-scripts#the-sqldev-loginsql-file) |

#### Database: Advanced

| Parameter                                  | Value                                  | Remarks                             |
|:-------------------------------------------|:---------------------------------------|:------------------------------------|
| Sql Array Fetch Size (between 50 and 200)  | 200                                    |                                     |
| Display Null Value As                      | `(null)`                               |                                     |
| Display Null Using Background Color        | LIGHT\_GRAY                            |                                     |
| Display Struct Value In Grid               | Checked                                |                                     |
| Display XML Value In Grid                  | Checked                                |                                     |
| **Autocommit**                             | **Unchecked**                          |                                     |
| Use Oracle Client                          | Unchecked                              | Specifying an Oracle Client makes it possible to check the "Use OCI" option in Connection properties (see [below](#using-the-jdbc-ocithick-driver))  |
| Use OCI/Thick driver                       | Unchecked                              | If Checked, enables the native JDBC OCI driver in _all_ connections (prerequisite: Use Oracle Client; see [below](#using-the-jdbc-ocithick-driver)) |
| Tnsnames Directory                         | `E:\Home\...\SQL_Developer\tns_admin`  | Location of my `tnsnames.ora` file  |

#### Database: NLS

| Parameter            | Value                         | Remarks                           |
|:---------------------|:------------------------------|:----------------------------------|
| Language             | AMERICAN                      |                                   |
| Territory            | AMERICA                       |                                   |
| Sort                 | BINARY                        | Let's keeps things simple here!   | 
| Comparison           | BINARY                        | Let's keeps things simple here!   |
| Date Language        | AMERICAN                      |                                   |
| Date Format          | YYYY-MM-DD HH24:MI:SS         |                                   |
| Timestamp Format     | YYYY-MM-DD HH24:MI:SSXFF      |                                   |
| Timestamp TZ Format  | YYYY-MM-DD HH24:MI:SSXFF TZR  | or TZH:TZM                        |
| Decimal Separator    | ,                             |                                   |
| Group Separator      | ''                            | Void (no group separator)         |
| Currency             | €                             |                                   |
| ISO Currency         | FRANCE                        |                                   |
| Length               | BYTE                          | This sets NLS\_LENGTH\_SEMANTICS  |
| Skip NLS Settings    | Unchecked                     |                                   |

#### Database: Reports

| Parameter                        | Value      | Remarks  |
|:---------------------------------|:-----------|:---------|
| Close all reports on disconnect  | Unchecked  |          | 
| Charts Row Limit                 | 50000      |          |

#### Database: Worksheet

| Parameter                                        | Value                                | Remarks   |
|:-------------------------------------------------|:-------------------------------------|:----------|
| Open a worksheet on connect                      | Unchecked                            |           |
| New worksheet to use unshared connection         | Unchecked                            |           |
| Close all worksheets on disconnect               | Unchecked                            |           |
| Prompt for Save file on close                    | Checked                              |           |
| Grid in checker board or Zebra pattern           | Unchecked                            |           |
| Max Rows to print in a script                    | 100000                               | 100 k     | 
| Max lines in Script output                       | 10000000                             | 10 M      |
| SQL History Limit                                | 500                                  |           |
| Select default path to look for scripts          | `E:\Home\...\SQL_Developer\scripts`  | Search path for scripts called using the `@file` syntax |
| Save Bind variables to disk on exit              | Checked                              |           |
| Show query results in new tab                    | Unchecked                            |           |
| Re-initialize on script exit command             | Checked                              |           |
| Skip loading meta data detail for Query Builder  | Checked                              |           |

#### Shortcut Keys

| Parameter               | Value         | Remarks                                                    |
|:------------------------|:--------------|:-----------------------------------------------------------|
| To Upper/Lower/InitCap  | Ctrl+Shift+U  | The default (Alt+Quote) does not work on a French keyboard |

#### Usage Reporting

| Parameter                                  | Value      | Remarks  |
|:-------------------------------------------|:-----------|:---------|
| Allow automated usage reporting to Oracle  | Unchecked  |          |

### Using the JDBC OCI/Thick driver

In order to use the native JDBC OCI driver–aka OCI/Thick driver—the following must be done:

1. The directory containing the native OCI libraries must be in the PATH, before other Oracle Client
   installations.
2. The following preference must be set:
     * **Database: Advanced**: **Use Oracle Client** must be checked
     * The **Location** and **Type** of the Oracle Client must be configured—and preferably, tested with success.
3. SQL Developer must be restarted.

From there on:
* The JDBC driver from the Oracle Client installation will be used (either in JDBC Thin
  or in OCI mode) in replacement of the driver supplied with SQL Developer.
* In order to use the native OCI mode, there are 2 possibilities:
     * Use it in _all connections_: the preference **Database: Advanced**: **Use OCI/Thick driver**
       must be checked
     * Or: enable it on a _per-connection_ basis. In the **Database Connection** properties dialog,
       check the **Use OCI** checkbox.
