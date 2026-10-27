unit LazySqliteStatic;

{$mode objfpc}{$H+}

{ Links the vendored SQLite amalgamation object into the executable (no system libsqlite3). }

interface

function LazySqliteEmbeddedVersion: PAnsiChar;

implementation

uses
  ctypes;

function LazySqliteEmbeddedVersion: PAnsiChar; cdecl; external 'sqlite3_libversion';

end.
