-- Spool directory
-- 
define def_spool_directory = "E:/Home/romain/Temp"

-- Choice of naming scheme for the spool file
-- Use "simple" to omit the source database and schema names,
-- or "normal" to include both in the name of the spool file
--
define def_spool_naming_scheme = "simple"
--define def_spool_naming_scheme = "normal"

-- Constraints as ALTER statements?
-- Use "true" to have constraints generated as ALTER TABLE statements
-- or "false" to have constraints generated inline
--
define def_constraint_pk_as_alter       = "true"
--define def_constraint_pk_as_alter       = "false"

define def_constraint_unique_as_alter   = "true"
--define def_constraint_unique_as_alter   = "false"

define def_constraint_check_as_alter    = "true"
--define def_constraint_check_as_alter    = "false"

define def_cnstraint_foreign_as_alter  = "true"
--define def_cnstraint_foreign_as_alter  = "false"

define def_cnstraint_notnull_as_alter = "false"
--define def_cnstraint_notnull_as_alter = "true"

-- How to deal with synonyms?
-- Use "true" to print synonyms, "false" to omit them
--
--define def_print_private_synonyms   = "false"
define def_print_private_synonyms   = "true"

define def_print_public_synonyms    = "true"
--define def_print_public_synonyms    = "false"

-- Strip / include object schema?
-- Use "true" to omit the schema name, "false" to include it
--
define def_strip_object_schema  = "true"
--define def_strip_object_schema  = "false"

-- Strip / include segment attributes?
-- Use "true" to omit segment attributes, "false" to keep them
--
define def_strip_segment_attrs = "true"
--define def_strip_segment_attrs = "false"

-- Strip / include the tablespace clause?
-- Use "true" to omit the tablespace clause, "false" to keep it
--
define def_strip_tablespace_clause = "true"
--define def_strip_tablespace_clause = "false"

-- Sort GRANT statements on tables and views?
-- Use "true" to sort GRANT statements, "false" to keep them unsorted.
--
define def_sort_table_grants = "true"
--define def_sort_table_grants = "false"
