/*
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

-- This file generates linetest.c, linetest.c is licensed per the below.

-- ------ cql-verify db helpers

@echo c, "\n";
@echo c, "\n";
@echo c, "//\n";
@echo c, "// This file is auto-generated by linetest.sql, it is checked in just\n";
@echo c, "// in case CQL is broken by a change.  The Last Known Good Verifier\n";
@echo c, "// can be used to verify the tests pass again, or report failures\n";
@echo c, "// while things are still otherwise broken.  Rebuild with 'regen.sh'\n";
@echo c, "//\n";
@echo c, "\n";

-- setup the table and the index
create procedure linetest_setup()
begin
  create table linedata(
     source text not null,
     procname text not null,
     line integer not null,
     data text not null,
     physical_line integer not null
  );

  create table procs(
     procname text not null primary key);

  create index __idx__test_lines on linedata (source, procname);
end;

-- add a row to the results table
create procedure linetest_add(like linedata)
begin
  insert into linedata from arguments;
  insert or ignore into procs from arguments(like procs);
end;

create procedure linetest_dump()
begin
  declare C cursor for select * from linedata;
  loop fetch C
  begin
    call printf("%s %s %4d %3d %s\n", C.source, C.procname, C.physical_line, C.line, C.data);
  end;
end;

create proc dump_proc_records(source_ text not null, procname_ text not null)
begin
  declare C cursor for select * from linedata where procname = procname_ and source = source_;
  loop fetch C
  begin
    call printf("%5d %s\n", C.line, C.data);
  end;
end;

create proc dump(procname text not null)
begin
  call printf("%s: difference encountered\n", procname);
  call printf("<<<< EXPECTED\n");
  call dump_proc_records("exp", procname);
  call printf(">>>> ACTUAL\n");
  call dump_proc_records("act", procname);
end;

create procedure compare_lines(
  out procs integer not null,
  out compares integer not null,
  out errors integer not null)
begin
  declare p cursor for select * from procs;
  loop fetch p
  begin
    set procs := procs + 1;

    declare actual cursor for
      select * from linedata where
        source = 'act' and
        procname = p.procname;

    declare expected cursor for
      select * from linedata where
        source = 'exp' and
        procname = p.procname;

    fetch actual;
    fetch expected;

    while actual and expected
    begin
      set compares := compares + 1;
      if (actual.line != expected.line or
          actual.data != expected.data) then
          call dump(p.procname);
          call printf("\nFirst difference:\n");
          call printf("expected: %5d %s\n", expected.line, expected.data);
          call printf("  actual: %5d %s\n", actual.line, actual.data);
          call printf("\nDifferences at:\n line %d in expected\n line %d in actual", expected.physical_line, actual.physical_line);
          call printf("\n");
          set errors := errors + 1;
          leave;
      end if;
      fetch actual;
      fetch expected;
    end;

    if (actual != expected) then
      if (not actual) then
          call dump(p.procname);
          call printf("\nRan out of lines in actual:\n");
          call printf("\nDifferences at:\n line %d in expected\n", expected.physical_line);
          call printf("\n");
          set errors := errors + 1;
      end if;

      if (not expected) then
          call dump(p.procname);
          call printf("\nRan out of lines in expected:\n");
          call printf("\nDifferences at:\n line %d in actual\n", actual.physical_line);
          call printf("\n");
          set errors := errors + 1;
      end if;
    end if;
  end;
end;
