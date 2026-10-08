unit uAgentRunThread;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, uAppTypes, uAgentEngine;

type
  TAgentRunThread = class(TThread)
  private
    FEngine: TAgentEngine;
    FUserPrompt: string;
    FMode: TWorkspaceMode;
    FModel: string;
  protected
    procedure Execute; override;
  public
    constructor Create(AEngine: TAgentEngine; const AUserPrompt: string;
      AMode: TWorkspaceMode; const AModel: string);
  end;

implementation

constructor TAgentRunThread.Create(AEngine: TAgentEngine; const AUserPrompt: string;
  AMode: TWorkspaceMode; const AModel: string);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FEngine := AEngine;
  FUserPrompt := AUserPrompt;
  FMode := AMode;
  FModel := AModel;
end;

procedure TAgentRunThread.Execute;
begin
  try
    try
      FEngine.ExecuteRun(FUserPrompt, FMode, FModel);
    except
      on E: Exception do
        FEngine.ReportRunException(E);
    end;
  finally
    FEngine.RunThreadFinished;
  end;
end;

end.
