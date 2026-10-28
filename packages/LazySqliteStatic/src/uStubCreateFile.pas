unit uStubCreateFile;
{$mode objfpc}{$H+}
interface
implementation
uses Windows;
function Sqlite_CreateFileW(lpFileName: PWideChar; dwDesiredAccess, dwShareMode: DWORD;
  lpSecurity: Pointer; dwCreationDisposition, dwFlagsAndAttributes: DWORD;
  hTemplateFile: THandle): THandle; stdcall; public name 'CreateFileW';
begin
  Result := Windows.CreateFileW(lpFileName, dwDesiredAccess, dwShareMode, lpSecurity,
    dwCreationDisposition, dwFlagsAndAttributes, hTemplateFile);
end;
end.
