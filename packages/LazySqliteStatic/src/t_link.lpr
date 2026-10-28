program t;
{$mode objfpc}
uses uStubCreateFile;
{$L sqlite3_embed.o}
function sqlite3_libversion: PAnsiChar; cdecl; external;
begin
  WriteLn(sqlite3_libversion);
end.
