unit uSqlite3Embed;

{$mode objfpc}{$H+}
{$packrecords C}

{ Minimal SQLite3 C API bindings for statically linked amalgamation. }

interface

uses
  ctypes;

const
  SQLITE_OK = 0;
  SQLITE_ROW = 100;
  SQLITE_DONE = 101;
  SQLITE_ERROR = 1;

  SQLITE_OPEN_READWRITE = $00000002;
  SQLITE_OPEN_CREATE = $00000004;

  SQLITE_TRANSIENT = Pointer(-1);

type
  PSqlite3 = Pointer;
  PPSqlite3 = ^PSqlite3;
  PSqlite3Stmt = Pointer;
  PPSqlite3Stmt = ^PSqlite3Stmt;

function sqlite3_libversion: PAnsiChar; cdecl;
function sqlite3_open_v2(filename: PAnsiChar; ppDb: PPSqlite3; flags: cint; zVfs: PAnsiChar): cint; cdecl;
function sqlite3_close(db: PSqlite3): cint; cdecl;
function sqlite3_errmsg(db: PSqlite3): PAnsiChar; cdecl;
function sqlite3_exec(db: PSqlite3; sql: PAnsiChar; callback: Pointer; arg: Pointer; errmsg: PPAnsiChar): cint; cdecl;
function sqlite3_free(ptr: Pointer): cint; cdecl;
function sqlite3_prepare_v2(db: PSqlite3; zSql: PAnsiChar; nByte: cint; ppStmt: PPSqlite3Stmt; pzTail: PPAnsiChar): cint; cdecl;
function sqlite3_finalize(pStmt: PSqlite3Stmt): cint; cdecl;
function sqlite3_step(pStmt: PSqlite3Stmt): cint; cdecl;
function sqlite3_bind_text(pStmt: PSqlite3Stmt; i: cint; z: PAnsiChar; n: cint; xDel: Pointer): cint; cdecl;
function sqlite3_bind_int(pStmt: PSqlite3Stmt; i: cint; iValue: cint): cint; cdecl;
function sqlite3_reset(pStmt: PSqlite3Stmt): cint; cdecl;
function sqlite3_column_text(pStmt: PSqlite3Stmt; iCol: cint): PAnsiChar; cdecl;
function sqlite3_column_int(pStmt: PSqlite3Stmt; iCol: cint): cint; cdecl;

implementation

{$ifdef UNIX}
  {$linklib c}
  {$linklib m}
{$endif}
{$L sqlite3_embed.o}

function sqlite3_libversion: PAnsiChar; cdecl; external;
function sqlite3_open_v2(filename: PAnsiChar; ppDb: PPSqlite3; flags: cint; zVfs: PAnsiChar): cint; cdecl; external;
function sqlite3_close(db: PSqlite3): cint; cdecl; external;
function sqlite3_errmsg(db: PSqlite3): PAnsiChar; cdecl; external;
function sqlite3_exec(db: PSqlite3; sql: PAnsiChar; callback: Pointer; arg: Pointer; errmsg: PPAnsiChar): cint; cdecl; external;
function sqlite3_free(ptr: Pointer): cint; cdecl; external;
function sqlite3_prepare_v2(db: PSqlite3; zSql: PAnsiChar; nByte: cint; ppStmt: PPSqlite3Stmt; pzTail: PPAnsiChar): cint; cdecl; external;
function sqlite3_finalize(pStmt: PSqlite3Stmt): cint; cdecl; external;
function sqlite3_step(pStmt: PSqlite3Stmt): cint; cdecl; external;
function sqlite3_bind_text(pStmt: PSqlite3Stmt; i: cint; z: PAnsiChar; n: cint; xDel: Pointer): cint; cdecl; external;
function sqlite3_bind_int(pStmt: PSqlite3Stmt; i: cint; iValue: cint): cint; cdecl; external;
function sqlite3_reset(pStmt: PSqlite3Stmt): cint; cdecl; external;
function sqlite3_column_text(pStmt: PSqlite3Stmt; iCol: cint): PAnsiChar; cdecl; external;
function sqlite3_column_int(pStmt: PSqlite3Stmt; iCol: cint): cint; cdecl; external;

end.
