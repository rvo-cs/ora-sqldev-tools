create or replace package pkg_capture_ddl authid definer as

    procedure capture_pre;
    procedure capture_post;

end pkg_capture_ddl;
/
