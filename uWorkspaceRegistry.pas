unit uWorkspaceRegistry;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TWorkspaceEntry = record
    Id: string;
    DisplayName: string;
    FolderPath: string;
    LastSessionId: string;
  end;

  TWorkspaceRegistry = class
  private
    FEntries: array of TWorkspaceEntry;
    FActiveWorkspaceId: string;
    function IndexOfId(const AId: string): Integer;
    function IndexOfPath(const AFolderPath: string): Integer;
  public
    function Count: Integer;
    function GetEntry(AIndex: Integer): TWorkspaceEntry;
    function FindById(const AId: string; out AEntry: TWorkspaceEntry): Boolean;
    function FindByPath(const AFolderPath: string; out AEntry: TWorkspaceEntry): Boolean;
    function WorkspaceIdFromPath(const AFolderPath: string): string;

    property ActiveWorkspaceId: string read FActiveWorkspaceId write FActiveWorkspaceId;

    function AddWorkspace(const ADisplayName, AFolderPath: string): string;
    function UpdateWorkspace(const AId: string; const ADisplayName, AFolderPath: string): Boolean;
    procedure SetLastSessionId(const AWorkspaceId, ASessionId: string);
    function RemoveWorkspace(const AId: string): Boolean;

    procedure Load;
    procedure Save;
    procedure MigrateFromLegacyIni(const ALegacyName, ALegacyRoot: string);
  end;

function WorkspaceRegistryFileName: string;
function NormalizeWorkspaceFolderPath(const APath: string): string;

implementation

uses
  Forms, fpjson, jsonparser;

function WorkspaceRegistryFileName: string;
begin
  Result := IncludeTrailingPathDelimiter(GetAppConfigDir(False)) + 'lazycodingagent' +
    PathDelim + 'workspaces.json';
end;

function NormalizeWorkspaceFolderPath(const APath: string): string;
begin
  Result := ExpandFileName(ExcludeTrailingPathDelimiter(Trim(APath)));
end;

function WorkspaceIdFromNormalizedPath(const ANormalizedPath: string): string;
var
  I: Integer;
  H: UInt64;
begin
  H := 5381;
  for I := 1 to Length(ANormalizedPath) do
    H := ((H shl 5) + H) + Ord(ANormalizedPath[I]);
  Result := 'ws_' + IntToHex(H, 16);
end;

{ TWorkspaceRegistry }

function TWorkspaceRegistry.Count: Integer;
begin
  Result := Length(FEntries);
end;

function TWorkspaceRegistry.GetEntry(AIndex: Integer): TWorkspaceEntry;
begin
  Result := FEntries[AIndex];
end;

function TWorkspaceRegistry.IndexOfId(const AId: string): Integer;
var
  I: Integer;
begin
  for I := 0 to High(FEntries) do
    if SameText(FEntries[I].Id, AId) then
      Exit(I);
  Result := -1;
end;

function TWorkspaceRegistry.IndexOfPath(const AFolderPath: string): Integer;
var
  I: Integer;
  Norm: string;
begin
  Norm := NormalizeWorkspaceFolderPath(AFolderPath);
  for I := 0 to High(FEntries) do
    if SameText(NormalizeWorkspaceFolderPath(FEntries[I].FolderPath), Norm) then
      Exit(I);
  Result := -1;
end;

function TWorkspaceRegistry.WorkspaceIdFromPath(const AFolderPath: string): string;
begin
  Result := WorkspaceIdFromNormalizedPath(NormalizeWorkspaceFolderPath(AFolderPath));
end;

function TWorkspaceRegistry.FindById(const AId: string; out AEntry: TWorkspaceEntry): Boolean;
var
  Idx: Integer;
begin
  Idx := IndexOfId(AId);
  Result := Idx >= 0;
  if Result then
    AEntry := FEntries[Idx];
end;

function TWorkspaceRegistry.FindByPath(const AFolderPath: string; out AEntry: TWorkspaceEntry): Boolean;
var
  Idx: Integer;
begin
  Idx := IndexOfPath(AFolderPath);
  Result := Idx >= 0;
  if Result then
    AEntry := FEntries[Idx];
end;

function TWorkspaceRegistry.AddWorkspace(const ADisplayName, AFolderPath: string): string;
var
  E: TWorkspaceEntry;
  Idx: Integer;
  Norm: string;
begin
  Norm := NormalizeWorkspaceFolderPath(AFolderPath);
  Idx := IndexOfPath(Norm);
  if Idx >= 0 then begin
    Result := FEntries[Idx].Id;
    if Trim(ADisplayName) <> '' then
      FEntries[Idx].DisplayName := Trim(ADisplayName);
    Exit;
  end;

  E.Id := WorkspaceIdFromNormalizedPath(Norm);
  E.FolderPath := Norm;
  if Trim(ADisplayName) <> '' then
    E.DisplayName := Trim(ADisplayName)
  else
    E.DisplayName := ExtractFileName(Norm);
  E.LastSessionId := '';

  SetLength(FEntries, Length(FEntries) + 1);
  FEntries[High(FEntries)] := E;
  Result := E.Id;
end;

function TWorkspaceRegistry.UpdateWorkspace(const AId: string; const ADisplayName, AFolderPath: string): Boolean;
var
  Idx, OtherIdx: Integer;
  Norm: string;
begin
  Idx := IndexOfId(AId);
  if Idx < 0 then
    Exit(False);

  Norm := NormalizeWorkspaceFolderPath(AFolderPath);
  OtherIdx := IndexOfPath(Norm);
  if (OtherIdx >= 0) and (OtherIdx <> Idx) then
    Exit(False);

  FEntries[Idx].FolderPath := Norm;
  if Trim(ADisplayName) <> '' then
    FEntries[Idx].DisplayName := Trim(ADisplayName);
  Result := True;
end;

procedure TWorkspaceRegistry.SetLastSessionId(const AWorkspaceId, ASessionId: string);
var
  Idx: Integer;
begin
  Idx := IndexOfId(AWorkspaceId);
  if Idx < 0 then Exit;
  FEntries[Idx].LastSessionId := ASessionId;
end;

function TWorkspaceRegistry.RemoveWorkspace(const AId: string): Boolean;
var
  Idx, I: Integer;
begin
  Idx := IndexOfId(AId);
  if Idx < 0 then
    Exit(False);
  if SameText(FActiveWorkspaceId, AId) then
    FActiveWorkspaceId := '';
  for I := Idx to High(FEntries) - 1 do
    FEntries[I] := FEntries[I + 1];
  SetLength(FEntries, Length(FEntries) - 1);
  Result := True;
end;

procedure TWorkspaceRegistry.Load;
var
  Path: string;
  Raw: string;
  Data: TJSONData;
  Root, Item: TJSONObject;
  Arr: TJSONArray;
  I, N: Integer;
begin
  SetLength(FEntries, 0);
  FActiveWorkspaceId := '';
  Path := WorkspaceRegistryFileName;
  if not FileExists(Path) then
    Exit;

  with TStringList.Create do
  try
    LoadFromFile(Path);
    Raw := Text;
  finally
    Free;
  end;

  if Trim(Raw) = '' then Exit;

  try
    Data := GetJSON(Raw);
    try
      if not (Data is TJSONObject) then Exit;
      Root := TJSONObject(Data);
      FActiveWorkspaceId := Root.Get('activeWorkspaceId', '');
      if not (Root.Find('workspaces') is TJSONArray) then Exit;
      Arr := TJSONArray(Root.Find('workspaces'));
      N := Arr.Count;
      SetLength(FEntries, N);
      for I := 0 to N - 1 do begin
        if not (Arr.Items[I] is TJSONObject) then Continue;
        Item := TJSONObject(Arr.Items[I]);
        FEntries[I].Id := Item.Get('id', '');
        FEntries[I].DisplayName := Item.Get('displayName', '');
        FEntries[I].FolderPath := Item.Get('folderPath', '');
        FEntries[I].LastSessionId := Item.Get('lastSessionId', '');
      end;
    finally
      Data.Free;
    end;
  except
    SetLength(FEntries, 0);
    FActiveWorkspaceId := '';
  end;
end;

procedure TWorkspaceRegistry.Save;
var
  Root, Item: TJSONObject;
  Arr: TJSONArray;
  I: Integer;
  Path, Dir: string;
  SL: TStringList;
begin
  Root := TJSONObject.Create;
  try
    Root.Add('activeWorkspaceId', FActiveWorkspaceId);
    Arr := TJSONArray.Create;
    for I := 0 to High(FEntries) do begin
      Item := TJSONObject.Create;
      Item.Add('id', FEntries[I].Id);
      Item.Add('displayName', FEntries[I].DisplayName);
      Item.Add('folderPath', FEntries[I].FolderPath);
      Item.Add('lastSessionId', FEntries[I].LastSessionId);
      Arr.Add(Item);
    end;
    Root.Add('workspaces', Arr);

    Path := WorkspaceRegistryFileName;
    Dir := ExtractFilePath(Path);
    if not DirectoryExists(Dir) then
      ForceDirectories(Dir);

    SL := TStringList.Create;
    try
      SL.Text := Root.AsJSON;
      SL.SaveToFile(Path);
    finally
      SL.Free;
    end;
  finally
    Root.Free;
  end;
end;

procedure TWorkspaceRegistry.MigrateFromLegacyIni(const ALegacyName, ALegacyRoot: string);
var
  Norm: string;
  Id: string;
begin
  if Count > 0 then Exit;
  Norm := NormalizeWorkspaceFolderPath(ALegacyRoot);
  if (Norm = '') or not DirectoryExists(Norm) then Exit;
  Id := AddWorkspace(ALegacyName, Norm);
  if FActiveWorkspaceId = '' then
    FActiveWorkspaceId := Id;
  Save;
end;

end.
