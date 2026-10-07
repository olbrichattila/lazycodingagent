unit uAgentToolBase;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, fpjson, jsonparser, LazFileUtils, uAppTypes, uAgentTypes;

type
  TWorkspaceModeSet = set of TWorkspaceMode;

  TAgentToolSession = class
  public
    Tasks: TJSONArray;
    Diagnostics: TJSONObject;
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
  end;

  TToolExecutionResult = record
    Success: Boolean;
    Output: string;
    Summary: string;
  end;

  TAgentToolContext = class
  private
    FWorkspaceRoot: string;
    FMode: TWorkspaceMode;
    FSession: TAgentToolSession;
    FCancelFlag: PBoolean;
    FCancelDeadline: QWord;
  public
    constructor Create(const AWorkspaceRoot: string);
    destructor Destroy; override;

    function ResolvePath(const APath: string): string;
    function IsCancelled: Boolean;
    procedure SetCancelFlag(AFlag: PBoolean);
    procedure SetCancelDeadline(ADeadline: QWord);
    procedure ClearSession;

    property WorkspaceRoot: string read FWorkspaceRoot write FWorkspaceRoot;
    property Mode: TWorkspaceMode read FMode write FMode;
    property Session: TAgentToolSession read FSession;
  end;

  TAgentTool = class
  protected
    FContext: TAgentToolContext;
    FAliases: string;
    FAllowedModes: TWorkspaceModeSet;
    FAdvertised: Boolean;
    FMutatesFiles: Boolean;
  public
    constructor Create(AContext: TAgentToolContext); virtual;
    function MatchesName(const AName: string): Boolean; virtual;
    function GetDefinition: TToolDef; virtual; abstract;
    function Execute(const Args: TJSONObject): TToolExecutionResult; virtual; abstract;
    function ToolAllowedInMode(AMode: TWorkspaceMode): Boolean; virtual;

    property Context: TAgentToolContext read FContext;
    property Aliases: string read FAliases write FAliases;
    property AllowedModes: TWorkspaceModeSet read FAllowedModes write FAllowedModes;
    property Advertised: Boolean read FAdvertised write FAdvertised;
    property MutatesFiles: Boolean read FMutatesFiles write FMutatesFiles;
  end;

  TAgentToolClass = class of TAgentTool;

function CurrentToolContext: TAgentToolContext;
procedure SetCurrentToolContext(AContext: TAgentToolContext);

function SafeToolText(const S: RawByteString; MaxBytes: Integer = MaxInt): UTF8String;
function ToolError(const AMessage: string): string;
function ToolResultFromJson(const AJson: string): TToolExecutionResult;
function WorkspaceModeToCaption(AMode: TWorkspaceMode): string;
function ToolCancelled: Boolean;
function NotifyToolFileChanged(const APath: string): string;

implementation

uses
  uAgentToolPaths;

var
  GActiveToolContext: TAgentToolContext = nil;

function CurrentToolContext: TAgentToolContext;
begin
  Result := GActiveToolContext;
end;

procedure SetCurrentToolContext(AContext: TAgentToolContext);
begin
  GActiveToolContext := AContext;
end;

function WorkspaceModeToCaption(AMode: TWorkspaceMode): string;
begin
  Result := WorkspaceModeCaption(AMode);
end;

function SafeToolText(const S: RawByteString; MaxBytes: Integer): UTF8String;
var
  I, J, N, W, B, SecondMin, SecondMax: Integer;
begin
  SetLength(Result, Min(Int64(Length(S)) * 3, Int64(MaxBytes)));
  I := 1;
  W := 0;
  while I <= Length(S) do
  begin
    B := Ord(S[I]);
    N := 0;
    SecondMin := $80;
    SecondMax := $BF;
    if B < $80 then
      N := 1
    else if (B >= $C2) and (B <= $DF) then
      N := 2
    else if (B >= $E0) and (B <= $EF) then
    begin
      N := 3;
      if B = $E0 then SecondMin := $A0;
      if B = $ED then SecondMax := $9F;
    end
    else if (B >= $F0) and (B <= $F4) then
    begin
      N := 4;
      if B = $F0 then SecondMin := $90;
      if B = $F4 then SecondMax := $8F;
    end;
    if I + N - 1 > Length(S) then N := 0;
    if N > 1 then
    begin
      if (Ord(S[I + 1]) < SecondMin) or (Ord(S[I + 1]) > SecondMax) then N := 0;
      for J := 2 to N - 1 do
        if (Ord(S[I + J]) < $80) or (Ord(S[I + J]) > $BF) then begin N := 0; Break; end;
    end;
    if N = 0 then
    begin
      if W + 3 > MaxBytes then Break;
      Result[W + 1] := #239;
      Result[W + 2] := #191;
      Result[W + 3] := #189;
      Inc(W, 3);
      Inc(I);
    end
    else
    begin
      if W + N > MaxBytes then Break;
      Move(S[I], Result[W + 1], N);
      Inc(W, N);
      Inc(I, N);
    end;
  end;
  SetLength(Result, W);
end;

function ToolError(const AMessage: string): string;
var
  O: TJSONObject;
begin
  O := TJSONObject.Create(['error', SafeToolText(AMessage)]);
  try
    Result := O.AsJSON;
  finally
    O.Free;
  end;
end;

function ToolResultFromJson(const AJson: string): TToolExecutionResult;
var
  D: TJSONData;
  O: TJSONObject;
begin
  Result.Output := AJson;
  Result.Success := True;
  Result.Summary := 'OK';
  if Trim(AJson) = '' then Exit;
  if AJson[1] <> '{' then Exit;
  try
    D := GetJSON(AJson);
    try
      if D is TJSONObject then
      begin
        O := TJSONObject(D);
        if O.Find('error') <> nil then
        begin
          Result.Success := False;
          Result.Summary := O.Get('error', 'Error');
          if O.Find('error_kind') <> nil then
            Result.Summary := O.Get('error_kind', '') + ': ' + Result.Summary;
        end
        else if O.Find('status') <> nil then
          Result.Summary := O.Get('status', 'success')
        else
          Result.Summary := 'OK';
      end;
    finally
      D.Free;
    end;
  except
    Result.Success := True;
  end;
end;

function ToolCancelled: Boolean;
begin
  Result := Assigned(GActiveToolContext) and GActiveToolContext.IsCancelled;
end;

function NotifyToolFileChanged(const APath: string): string;
begin
  Result := '';
  { Standalone app: no IDE refresh hook yet. }
  if APath <> '' then ;
end;

{ TAgentToolSession }

constructor TAgentToolSession.Create;
begin
  inherited Create;
  Tasks := TJSONArray.Create;
  Diagnostics := TJSONObject.Create;
end;

destructor TAgentToolSession.Destroy;
begin
  Tasks.Free;
  Diagnostics.Free;
  inherited Destroy;
end;

procedure TAgentToolSession.Clear;
begin
  Tasks.Clear;
  Diagnostics.Clear;
end;

{ TAgentToolContext }

constructor TAgentToolContext.Create(const AWorkspaceRoot: string);
begin
  inherited Create;
  if Trim(AWorkspaceRoot) <> '' then
    FWorkspaceRoot := ExpandFileName(AWorkspaceRoot)
  else
    FWorkspaceRoot := GetCurrentDir;
  FMode := wmAgent;
  FSession := TAgentToolSession.Create;
  FCancelFlag := nil;
  FCancelDeadline := 0;
end;

destructor TAgentToolContext.Destroy;
begin
  FSession.Free;
  inherited Destroy;
end;

function TAgentToolContext.ResolvePath(const APath: string): string;
begin
  Result := uAgentToolPaths.ResolveProjectPath(APath);
end;

function TAgentToolContext.IsCancelled: Boolean;
begin
  Result := Assigned(FCancelFlag) and FCancelFlag^;
  if not Result and (FCancelDeadline > 0) then
    Result := GetTickCount64 >= FCancelDeadline;
end;

procedure TAgentToolContext.SetCancelFlag(AFlag: PBoolean);
begin
  FCancelFlag := AFlag;
end;

procedure TAgentToolContext.SetCancelDeadline(ADeadline: QWord);
begin
  FCancelDeadline := ADeadline;
end;

procedure TAgentToolContext.ClearSession;
begin
  FSession.Clear;
end;

{ TAgentTool }

constructor TAgentTool.Create(AContext: TAgentToolContext);
begin
  inherited Create;
  FContext := AContext;
  FAliases := '';
  FAllowedModes := [wmAgent];
  FAdvertised := True;
  FMutatesFiles := True;
end;

function TAgentTool.MatchesName(const AName: string): Boolean;
var
  Def: TToolDef;
begin
  Def := GetDefinition;
  if SameText(Def.Name, AName) then Exit(True);
  Result := Pos(';' + LowerCase(AName) + ';', ';' + LowerCase(FAliases) + ';') > 0;
end;

function TAgentTool.ToolAllowedInMode(AMode: TWorkspaceMode): Boolean;
begin
  Result := AMode in FAllowedModes;
end;

end.
