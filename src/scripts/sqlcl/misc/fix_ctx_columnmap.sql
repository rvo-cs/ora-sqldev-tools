/*
  This script is a workaround for recent versions of SQLcl not correctly
  clearing the map from column settings to substitution variables when the
  COLUMN xxx CLEAR command (or the CLEAR COLUMNS command) is run : we may
  have to do that ourselves!

  The map of column settings to substitution variables is returned by
  ctx.getColumnMap(), whereas ctx.getStoredFormatCmds() returns the map
  of column format settings.

  E.g., after:

  column FOO noprint new_value BAR

  the following are true:
         i.  ctx.getStoredFormatCmds().get('foo')[0] === 'noprint'
    And: ii. ctx.getColumnMap().get('FOO') === 'bar'

  Note that keys are normalized to lowercase in ctx.getStoredFormatCmds(),
  whereas they are normalized to uppercase in ctx.getColumnMap().

  After: column FOO clear (or: clear columns), neither i nor ii should
  remain true. As it turns out, ii still holds true, hence the deletion
  from ctx.getColumnMap() does not happen.

 */ 
script
    var tabCol = ctx.getColumnMap().keySet().toArray()
    for (i = 0; i < tabCol.length; i++) {
        if (! ctx.getStoredFormatCmds().containsKey(tabCol[i].toLowerCase())) {
            ctx.getColumnMap().remove(tabCol[i])
        }
    }
/

