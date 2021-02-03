/*----------------*/
/* Sample aliases */
/*----------------*/

alias group=rva sysdate=
select /*ansiconsole*/ sysdate from dual
;

alias desc sysdate : this just displays SYSDATE.


/*----------------------------*/
/* Aliases for rvo-cs scripts */
/*----------------------------*/

@&rvocs_orasqldevtools_dir\src\scripts\sqlcl_aliases
