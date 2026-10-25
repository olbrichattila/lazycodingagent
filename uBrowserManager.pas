unit uBrowserManager;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, SyncObjs, uBrowserReadTypes;

procedure BrowserManagerAcquire(const Config: TBrowserReadConfig);
procedure BrowserManagerRelease;
procedure BrowserManagerShutdownAll;

implementation

var
  GLock: TCriticalSection;
  GActive: Integer;
  GMaxConcurrent: Integer;

procedure BrowserManagerAcquire(const Config: TBrowserReadConfig);
begin
  if GLock = nil then
    GLock := TCriticalSection.Create;
  GMaxConcurrent := Config.MaxConcurrent;
  if GMaxConcurrent < 1 then
    GMaxConcurrent := 1;
  while True do
  begin
    GLock.Enter;
    try
      if GActive < GMaxConcurrent then
      begin
        Inc(GActive);
        Exit;
      end;
    finally
      GLock.Leave;
    end;
    Sleep(50);
  end;
end;

procedure BrowserManagerRelease;
begin
  if GLock = nil then Exit;
  GLock.Enter;
  try
    if GActive > 0 then
      Dec(GActive);
  finally
    GLock.Leave;
  end;
end;

procedure BrowserManagerShutdownAll;
begin
  // Sessions are one-shot per call; nothing to pool yet.
end;

finalization
  GLock.Free;
  GLock := nil;

end.
