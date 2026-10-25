unit uBrowserPermissions;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TBrowserSensitiveConfirmEvent = procedure(const AMessage: string;
    var AApproved, AAllowForSession: Boolean) of object;

procedure SetBrowserSensitiveConfirmHandler(AHandler: TBrowserSensitiveConfirmEvent);

function RequestBrowserSensitiveConfirm(const AMessage: string;
  var AAllowForSession: Boolean): Boolean;

implementation

uses
  {$IFDEF LCL}
  Forms, Classes;
  {$ENDIF}

var
  GHandler: TBrowserSensitiveConfirmEvent;

type
  TConfirmSyncData = record
    Message: string;
    Approved: Boolean;
    AllowForSession: Boolean;
    Done: Boolean;
  end;

  TConfirmThreadBridge = class
  public
    class var Data: TConfirmSyncData;
    class procedure SyncConfirm;
  end;

procedure SetBrowserSensitiveConfirmHandler(AHandler: TBrowserSensitiveConfirmEvent);
begin
  GHandler := AHandler;
end;

class procedure TConfirmThreadBridge.SyncConfirm;
var
  Allow: Boolean;
begin
  Data.Approved := False;
  Data.AllowForSession := False;
  if Assigned(GHandler) then
    GHandler(Data.Message, Data.Approved, Allow);
  if Allow then
    Data.AllowForSession := True;
  Data.Done := True;
end;

function RequestBrowserSensitiveConfirm(const AMessage: string;
  var AAllowForSession: Boolean): Boolean;
var
  Data: TConfirmSyncData;
begin
  if not Assigned(GHandler) then
    Exit(False);
  TConfirmThreadBridge.Data.Message := AMessage;
  TConfirmThreadBridge.Data.Done := False;
  TConfirmThreadBridge.Data.Approved := False;
  TConfirmThreadBridge.Data.AllowForSession := False;
  {$IFDEF LCL}
  if Assigned(Application) and (GetCurrentThreadId <> MainThreadID) then
    TThread.Synchronize(nil, @TConfirmThreadBridge.SyncConfirm)
  else
  {$ENDIF}
    TConfirmThreadBridge.SyncConfirm;
  AAllowForSession := TConfirmThreadBridge.Data.AllowForSession;
  Result := TConfirmThreadBridge.Data.Approved;
end;

end.
