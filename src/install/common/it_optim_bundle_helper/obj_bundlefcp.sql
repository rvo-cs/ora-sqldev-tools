/*
   Object type describing the content of the optimizer bundle
   parameter file (bundlefcp_DBBP.xml)
 */
create type obj_bundlefcp as object (
    bundle_id           number,
    bundle_description  varchar2(50),
    bug_id              number,
    fix_control_id      number,
    bundle_value        number
)
/

