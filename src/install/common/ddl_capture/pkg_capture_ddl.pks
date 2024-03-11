create or replace package pkg_capture_ddl authid definer as
/*
 * SPDX-FileCopyrightText: 2024 R.Vassallo
 * SPDX-License-Identifier: BSD Zero Clause License
 */

    procedure capture_pre;
    procedure capture_post;

end pkg_capture_ddl;
/
