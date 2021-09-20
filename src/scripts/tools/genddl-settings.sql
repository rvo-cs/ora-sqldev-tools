-- Spool directory
-- 
define def_spool_directory = "E:\Home\romain\Temp"

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

define def_constraint_foreign_as_alter  = "true"
--define def_constraint_foreign_as_alter  = "false"

define def_constraint_not_null_as_alter = "false"
--define def_constraint_not_null_as_alter = "true"

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
