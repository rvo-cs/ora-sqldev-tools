## Configuring SQL Developer

### Additions to the `sqldeveloper.conf` file

Path: `sqldeveloper\bin\sqldeveloper.conf` (from the top product directory) 

Add the following if necessary:

```
# Force English language in UI
AddVMOption -Duser.language=en

#Directory for Java temporary files
AddVMOption -Djava.io.tmpdir=E:\Home\xxxx\.java-temp

# Work-around for spurious connection resets? 
#AddVMOption -Doracle.net.disableOob=true

# Store the profile under AppData\Local instead of AppData\Roaming
#AddVMOption -Dide.user.dir=C:\Users\xxxx\AppData\Local\SQL_Developer
```

As of now (using SQL Developer 21.4) I only use the 1st and the 2nd of the above
4 properties.

Disabling out-of-band breaks in JDBC Thin could help in 20.2; not sure if that's
useful anymore in recent releases.

Similarly, switching from AppData\Roaming to AppData\Local was very useful on sites
using roaming profiles and small quotas (fortunately, that seems out of fashion 
these days).

Using a non-standard directory for Java temporary files (the default is simply `%TEMP%`)
is not required, but makes it easier to understand how SQL Developer uses that directory.

### Heap space settings

Should that be necessary, the properties for sizing the JVM heap space are in the following file:

`%APPDATA%\sqldeveloper\21.4.3\product.conf`

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
* [Database: Utilities: Export](#database-utilities-export)
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
| Around parenthesis                   | Default       |                           |

#### Code Editor: Advanced Format: Custom Format

For experts only—I wouldn't touch that! :slightly_smiling_face:

#### Code Editor: Line Gutter

| Parameter          | Value    | Remarks  |
|:-------------------|:---------|:---------|
| Show Line Numbers  | Checked  |          |

#### Code Editor: PL/SQL Syntax Colors

| Parameter       | Value                                        | Remarks                  |
|:----------------|:---------------------------------------------|:-------------------------|
| PL/SQL Comment  | Foreground: Red: 0,   Green: 82,  Blue: 0    | With default background  |
| PlSqlLogger     | Foreground: Red: 115, Green: 0,   Blue: 115  | With default background  |

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

| Parameter            | Value                          | Remarks                           |
|:---------------------|:-------------------------------|:----------------------------------|
| Language             | AMERICAN                       |                                   |
| Territory            | AMERICA                        |                                   |
| Sort                 | BINARY                         | Let's keeps things simple here!   | 
| Comparison           | BINARY                         | Let's keeps things simple here!   |
| Date Language        | AMERICAN                       |                                   |
| Date Format          | YYYY-MM-DD HH24:MI:SS          |                                   |
| Timestamp Format     | YYYY-MM-DD HH24:MI:SSXFF4      |                                   |
| Timestamp TZ Format  | YYYY-MM-DD HH24:MI:SSXFF4 TZR  | or TZH:TZM                        |
| Decimal Separator    | ,                              |                                   |
| Group Separator      | ''                             | Void (no group separator)         |
| Currency             | €                             |                                   |
| ISO Currency         | FRANCE                         |                                   |
| Length               | BYTE                           | This sets NLS\_LENGTH\_SEMANTICS  |
| Skip NLS Settings    | Unchecked                      |                                   |

#### Database: Reports

| Parameter                        | Value      | Remarks  |
|:---------------------------------|:-----------|:---------|
| Close all reports on disconnect  | Unchecked  |          | 
| Charts Row Limit                 | 50000      |          |

#### Database: Utilities: Export

| Parameter            | Value                | Remarks                                                       |
|:---------------------|:---------------------|:--------------------------------------------------------------|
| Format               | excel 2003+ (xlsx)   | This defines the _default_ format of data export files        |
| Directory            | `E:\Home\...\Temp`   | This defines the _default_ directory for saving export files  |

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
| Select default path to look for scripts          | `E:\Home\...\SQL_Developer\scripts`  | Search path for scripts called using the `@file` syntax (see [SQLPATH](#sqlpath) below) |
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


### SQLPATH

A default search path for scripts called using the `@file` syntax may be specified in the
[Database: Worksheet](#database-worksheet) Preferences tab. Multiple directories may be
specified, separated by a semicolon (`;`) on Windows.

Actually, the complete search path is dynamic, and subject to subtle rules. 

*  For new, unsaved SQL worksheets, the search path is built by concatenating several directories:

     1. The current working directory, as specified by the `CD` command (if used)
     2. The `java.io.tmpdir` directory, which serves as the _initial_ current directory (\*)
     3. Directories from the search path specified in Preferences
     4. Directories from `%SQLPATH%`, if that environment variable is set. 

*  Once the SQL worksheet is saved to disk, the `java.io.tmpdir` directory in position (ii)
   above is replaced by the directory of the `.sql` file.

The behaviour of SQLcl is similar, but simpler: there is no "search path from Preferences"
(iii) to begin with, and the initial current directory (ii) is simply the OS working directory.
(Of course, SQLcl does not have worksheets.)

Both SQL Developer and SQLcl mysteriously add a `.` entry to the search path,
though not at the same position; that entry doesn't seem to matter in searches.

Use `show sqlpath` to display the current search path.

(\*) Unfortunately the _script-generating-script_ pattern (`SPOOL temp.sql`, `CALL temp.sql`)
appears not to work when the current directory is the same as `java.io.tmpdir`, because in that
particular case the spool file is created in another directory (SQL Dev: `%APPDATA%\SQL Developer`,
SQLcl: `%USERPROFILE%\.sqldeveloper`), so the `CALL` command cannot find it! :worried: 
The solution is simple: just `CD` to another directory. This is the main reason for adding a `CD`
command to SQL Developer's connection [startup script](login-scripts#the-sqldev-loginsql-file).

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
     * Or: enable it on a _per-connection_ basis. In the **Connection** properties dialog,
       on the **Advanced** tab, check the **Use OCI** checkbox.
