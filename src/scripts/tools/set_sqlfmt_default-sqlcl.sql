-- SQLcl now defaults to ansiconsole, which is fine for console output
-- but not so helpful in old-fashioned spooled reports.

set sqlformat default

-- Unfortunately, as of now there's no way to save the previous state
-- of sqlformat in order to restore it when the script completes. The
-- SQL*Plus STORE SET command does exist in SQLcl, but oddly enough not
-- in SQL Developer (which breaks SQLcl / SQL Developer compatibility),
-- and furthermore it doesn't seem to record the state of sqlformat.
