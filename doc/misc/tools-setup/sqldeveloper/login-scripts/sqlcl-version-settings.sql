-- sqlcl-version-settings.sql
--
-- PURPOSE
--      This script sets substitution variables according to the version
--      of the SQLcl client. This enables to take version-specific changes
--      of behaviour into account.
--
-- PREREQUISITE
--      RVOCS_ORASQLDEVTOOLS_DIR
--          This substitution variable must be set to the path of the root
--          of the working copy of the ora-sqldev-tools Git repository.
--

@&&RVOCS_ORASQLDEVTOOLS_DIR/src/scripts/tools/common/util/def_sqlcl_client.sql

define ora_sqlcl_client_unknown       = "&&def_sqlcl_client_unknown"
define ora_sqlcl_client_errmsg        = "&&def_sqlcl_client_errmsg"
define ora_sqlcl_client               = "&&def_sqlcl_client"
define ora_sqlcl_client_version       = "&&def_sqlcl_client_version"
define ora_sqlcl_client_version_major = "&&def_sqlcl_client_version_major"
define ora_sqlcl_client_version_minor = "&&def_sqlcl_client_version_minor"

@@sqlcl-version-settings-errmsg&def_sqlcl_client_unknown..sql

@&&RVOCS_ORASQLDEVTOOLS_DIR/src/scripts/tools/common/util/undef_sqlcl_client.sql

