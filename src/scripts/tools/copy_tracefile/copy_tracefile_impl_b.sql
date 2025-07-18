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
    if (defDirectoryName == null
            || defTraceFileName == null
            || defDestFilePath == null) {
        throw new java.lang.IllegalArgumentException(
                "unassigned input substitution variables\n")
    }

    // Create a BFILE reference for the source file
    var getBFileBinds = {}
    getBFileBinds.DIRNAME = defDirectoryName
    getBFileBinds.FILENAME = defTraceFileName
    var ret = util.executeReturnList(
            "select bfilename(:DIRNAME, :FILENAME) as bfile_ref from dual",
            getBFileBinds
        )
    if (ret.length != 1) {  /* CAN'T HAPPEN */
        throw new java.lang.RuntimeException(
                "expected exactly 1 row, got: " + ret.length + "\n")
    }
    var bfileRef = ret[0].BFILE_REF
        
    // Destination file
    var destFilePath = java.nio.file.Paths.get(defDestFilePath).toAbsolutePath()
    // Make sure we don't create files into the install. dir. tree of legacy SQL Dev.
    if (ideProduct == ideLegacyOracleSqlDev) {
        ideDirPath = java.nio.file.Paths.get(ideStartingCwd).getParent().toAbsolutePath()
        if (destFilePath.startsWith(ideDirPath)) {
            throw new java.lang.IllegalArgumentException(
                    "destination file would be created in SQL Dev install. dir. tree\n")
        }
    }

    // Open the BFILE; various exceptions can be raised at that point, so we'll 
    // assign into the DEF_DIAG_MSG substitution variable if one is caught
    try {
        bfileRef.openFile()
    }
    catch (ex) {
        ctx.getMap().put("DEF_DIAG_MSG", ex.getMessage())
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
/

-- Provide feedback
@@copy_tracefile_impl_&&def_script_suffix

undefine def_script_suffix
undefine def_diag_msg
