-- login-PUBLIC.sql
--
-- DESCRIPTION
--      Template file for login-&_USER.sql

@@login-common-sessioninit

set sqlprompt "@|bg_black,fg_green,bold _USER @ _CONNECT_IDENTIFIER >|@ "

--vv-- User-specific inits (if any) after this line --vv--
