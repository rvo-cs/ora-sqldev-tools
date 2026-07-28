-- Prevent an infinite start loop if an exception is raised
define def_script_suffix = "b-error"
define def_diag_msg = ""

-- Main JavaScript block
-- This is where the file copy actually happens, if at all
script
    var ideLegacyOracleSqlDev = "oracle.sqldeveloper"

    // "Arguments" of this scripts are the following substitution variables
    var defDirectoryName = ctx.getMap().get("DEF_DIRNAME")
    var defTraceFileName = ctx.getMap().get("DEF_TRACEFILE")
    var defDestFilePath = ctx.getMap().get("DEF_DESTFILE")

    // The following prop. serve to find out if the client is SQL Developer (legacy)
    var ideProduct = java.lang.System.getProperty("ide.product")
    var ideStartingCwd = java.lang.System.getProperty("ide.startingcwd")

    // Check "arguments"
    var argErrMsg = ""
    if (defDirectoryName == null || defDirectoryName.trim().isEmpty()) {
        argErrMsg += "ERROR: unspecified input directory\n"
    }
    if (defTraceFileName == null || defTraceFileName.trim().isEmpty()) {
        argErrMsg += "ERROR: unspecified input filename\n"
    }
    if (defDestFilePath == null || defDestFilePath.trim().isEmpty()) {
        argErrMsg += "ERROR: unspecified destination path\n"
    }
    if (! argErrMsg.isEmpty()) {
        ctx.write('\n')
        throw argErrMsg
    }

    // Create a BFILE reference for the source file
    var getBFileBinds = {}
    getBFileBinds.DIRNAME = defDirectoryName
    getBFileBinds.FILENAME = defTraceFileName
    var ret = util.executeReturnList(
            "select bfilename(:DIRNAME, :FILENAME) as bfile_ref from dual",
            getBFileBinds
        )
    if (ret.length != 1) {  // CAN'T HAPPEN
        ctx.write('\n')
        throw "ERROR: expected exactly 1 row, got: " + ret.length + "\n"
    }
    var bfileRef = ret[0].BFILE_REF
        
    // Destination file
    var destFilePath = java.nio.file.Paths.get(defDestFilePath).toAbsolutePath()
    // Make sure we don't create files into the install. dir. tree of legacy SQL Dev.
    if (ideProduct == ideLegacyOracleSqlDev) {
        ideDirPath = java.nio.file.Paths.get(ideStartingCwd).getParent().toAbsolutePath()
        if (destFilePath.startsWith(ideDirPath)) {
            ctx.write('\n')
            throw "ERROR: the output file would be created in the SQL Developer directory tree\n"
        }
    }

    if (bfileRef == null) {
        ctx.getMap().put("DEF_DIAG_MSG", "ERROR: expected a BFILE locator, got null")
    }
    else {
        // Open the BFILE; various exceptions can be raised at that point, so we'll 
        // assign into the DEF_DIAG_MSG substitution variable if one is caught
        try {
            bfileRef.openFile()
        }
        catch (ex) {
            ctx.getMap().put("DEF_DIAG_MSG", ex.message)
        }
        if (bfileRef.isOpen()) {
            try {
                // Get the BFILE binary stream
                var bfileStream = bfileRef.getBinaryStream(1)
                // Copy into the destination; if that fails, we'll print the whole
                // exception stack trace, and (again) copy the error message into
                // the DEF_DIAG_MSG substitution variable
                try {
                    java.nio.file.Files.copy(bfileStream, destFilePath,
                            java.nio.file.StandardCopyOption.REPLACE_EXISTING)
                    ctx.getMap().put("DEF_SCRIPT_SUFFIX", "b-success")
                }
                catch (ioex) {
                    ioex.printStackTrace(new java.io.PrintStream(out.getMainStream()))
                    ctx.getMap().put(
                        "DEF_DIAG_MSG",
                        "ERROR: BFILE copy failed\n" 
                            + "Reason: " + ioex.getClass().getName() + ": " + ioex.getMessage()
                    )
                }
            }
            finally {
                bfileRef.closeFile()
            }
        }
    }
/

-- Provide feedback
@@copy_tracefile_impl_&&def_script_suffix..sql

undefine def_script_suffix
undefine def_diag_msg
