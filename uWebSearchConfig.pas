unit uWebSearchConfig;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, uWebSearchTypes;

function WebSearchConfigIniPath: string;
function LoadWebSearchConfig: TWebSearchGlobalConfig;
procedure SaveWebSearchConfig(const AConfig: TWebSearchGlobalConfig);
function WebSearchHasUsableConnection(const AConfig: TWebSearchGlobalConfig): Boolean;
function WebSearchIsToolAvailable: Boolean;
function ConnectionIsConfigured(const AConn: TWebSearchConnection): Boolean; overload;
function ConnectionIsConfigured(const AConn: TWebSearchConnection;
  AAllowPrivateInstances: Boolean): Boolean; overload;
function NewWebSearchConnectionId: string;
procedure SortConnectionsByPriority(var AConnections: array of TWebSearchConnection);
procedure SetWebSearchConfigOverrideForTests(const AConfig: TWebSearchGlobalConfig);
procedure ClearWebSearchConfigOverrideForTests;

implementation

uses
  IniFiles, Classes
  {$IFDEF LCL}
  , Forms
  {$ENDIF}
  , uWebSearchSecrets, uWebSearchUrl;

var
  GTestConfigOverride: TWebSearchGlobalConfig;
  GTestConfigOverrideActive: Boolean = False;

procedure SetWebSearchConfigOverrideForTests(const AConfig: TWebSearchGlobalConfig);
begin
  GTestConfigOverride := AConfig;
  GTestConfigOverrideActive := True;
end;

procedure ClearWebSearchConfigOverrideForTests;
begin
  GTestConfigOverrideActive := False;
end;

procedure LoadWebSearchConfigFromIni(out Result: TWebSearchGlobalConfig); forward;

function WebSearchConfigIniPath: string;
begin
  {$IFDEF LCL}
  if Assigned(Application) then
    Exit(GetAppConfigFile(False));
  {$ENDIF}
  Result := IncludeTrailingPathDelimiter(GetEnvironmentVariable('HOME')) +
    '.config/lazycodingagent/config.ini';
end;

function NewWebSearchConnectionId: string;
var
  G: TGUID;
begin
  CreateGUID(G);
  Result := GUIDToString(G);
  Result := StringReplace(Result, '{', '', [rfReplaceAll]);
  Result := StringReplace(Result, '}', '', [rfReplaceAll]);
end;

function ConnectionSection(const AId: string): string;
begin
  Result := 'WebSearchConn_' + AId;
end;

function LoadWebSearchConfig: TWebSearchGlobalConfig;
begin
  if GTestConfigOverrideActive then
    Exit(GTestConfigOverride);
  Result := DefaultWebSearchGlobalConfig;
  LoadWebSearchConfigFromIni(Result);
end;

procedure LoadWebSearchConfigFromIni(out Result: TWebSearchGlobalConfig);
var
  I: TIniFile;
  Path: string;
  IdList: TStringList;
  Idx, J, Pri: Integer;
  Conn: TWebSearchConnection;
  KindStr: string;
begin
  Path := WebSearchConfigIniPath;
  if Path = '' then Exit;
  if not FileExists(Path) then Exit;
  I := TIniFile.Create(Path);
  IdList := TStringList.Create;
  try
    Result.ConfigVersion := I.ReadInteger('WebSearch', 'ConfigVersion', WEB_SEARCH_CONFIG_VERSION);
    Result.Enabled := I.ReadBool('WebSearch', 'Enabled', False);
    Result.MaxResults := I.ReadInteger('WebSearch', 'MaxResults', WEB_SEARCH_DEFAULT_MAX_RESULTS);
    if Result.MaxResults < 1 then Result.MaxResults := 1;
    if Result.MaxResults > 50 then Result.MaxResults := 50;
    Result.TotalTimeoutMs := I.ReadInteger('WebSearch', 'TotalTimeoutMs',
      WEB_SEARCH_DEFAULT_TOTAL_TIMEOUT_MS);
    if Result.TotalTimeoutMs < 1000 then Result.TotalTimeoutMs := 1000;
    Result.AutomaticFallback := I.ReadBool('WebSearch', 'AutomaticFallback', True);
    Result.FallbackOnEmptyResults := I.ReadBool('WebSearch', 'FallbackOnEmptyResults', False);
    Result.AllowPrivateInstances := I.ReadBool('WebSearch', 'AllowPrivateInstances', False);

    I.ReadSectionValues('WebSearchConnections', IdList);
    SetLength(Result.Connections, 0);
    for Idx := 0 to IdList.Count - 1 do
    begin
      Conn.Id := Trim(IdList.Names[Idx]);
      if Conn.Id = '' then Continue;
      Conn.Name := I.ReadString(ConnectionSection(Conn.Id), 'Name', 'Connection');
      KindStr := I.ReadString(ConnectionSection(Conn.Id), 'Provider', 'brave');
      if not ParseWebSearchProviderKind(KindStr, Conn.Kind) then
        Conn.Kind := wspkBrave;
      Conn.Enabled := I.ReadBool(ConnectionSection(Conn.Id), 'Enabled', True);
      Pri := I.ReadInteger(ConnectionSection(Conn.Id), 'Priority', Idx + 1);
      Conn.Priority := Pri;
      Conn.TimeoutMs := I.ReadInteger(ConnectionSection(Conn.Id), 'TimeoutMs',
        WEB_SEARCH_DEFAULT_CONNECTION_TIMEOUT_MS);
      if Conn.TimeoutMs < 1000 then Conn.TimeoutMs := 1000;
      Conn.InstanceUrl := I.ReadString(ConnectionSection(Conn.Id), 'InstanceUrl', '');
      Conn.TavilySearchDepth := I.ReadString(ConnectionSection(Conn.Id), 'TavilySearchDepth', 'basic');
      if not SameText(Conn.TavilySearchDepth, 'advanced') then
        Conn.TavilySearchDepth := 'basic';
      Conn.CustomHeaderName := I.ReadString(ConnectionSection(Conn.Id), 'CustomHeaderName', '');
      Conn.CustomHeaderValue := I.ReadString(ConnectionSection(Conn.Id), 'CustomHeaderValue', '');
      J := Length(Result.Connections);
      SetLength(Result.Connections, J + 1);
      Result.Connections[J] := Conn;
    end;
    SortConnectionsByPriority(Result.Connections);
  finally
    IdList.Free;
    I.Free;
  end;
end;

procedure SaveWebSearchConfig(const AConfig: TWebSearchGlobalConfig);
var
  I: TIniFile;
  Path, Dir: string;
  J: Integer;
  Conn: TWebSearchConnection;
  OldIds: TStringList;
  Idx: Integer;
begin
  Path := WebSearchConfigIniPath;
  if Path = '' then Exit;
  Dir := ExtractFilePath(Path);
  if (Dir <> '') and not DirectoryExists(Dir) then
    ForceDirectories(Dir);
  I := TIniFile.Create(Path);
  OldIds := TStringList.Create;
  try
    I.WriteInteger('WebSearch', 'ConfigVersion', WEB_SEARCH_CONFIG_VERSION);
    I.WriteBool('WebSearch', 'Enabled', AConfig.Enabled);
    I.WriteInteger('WebSearch', 'MaxResults', AConfig.MaxResults);
    I.WriteInteger('WebSearch', 'TotalTimeoutMs', AConfig.TotalTimeoutMs);
    I.WriteBool('WebSearch', 'AutomaticFallback', AConfig.AutomaticFallback);
    I.WriteBool('WebSearch', 'FallbackOnEmptyResults', AConfig.FallbackOnEmptyResults);
    I.WriteBool('WebSearch', 'AllowPrivateInstances', AConfig.AllowPrivateInstances);

    I.ReadSectionValues('WebSearchConnections', OldIds);
    for Idx := 0 to OldIds.Count - 1 do
      if Trim(OldIds.Names[Idx]) <> '' then
        I.DeleteKey('WebSearchConnections', OldIds.Names[Idx]);
    I.EraseSection('WebSearchConnections');

    for J := 0 to High(AConfig.Connections) do
    begin
      Conn := AConfig.Connections[J];
      if Trim(Conn.Id) = '' then Continue;
      I.WriteString('WebSearchConnections', Conn.Id, '1');
      I.WriteString(ConnectionSection(Conn.Id), 'Name', Conn.Name);
      I.WriteString(ConnectionSection(Conn.Id), 'Provider', WebSearchProviderKindToString(Conn.Kind));
      I.WriteBool(ConnectionSection(Conn.Id), 'Enabled', Conn.Enabled);
      I.WriteInteger(ConnectionSection(Conn.Id), 'Priority', Conn.Priority);
      I.WriteInteger(ConnectionSection(Conn.Id), 'TimeoutMs', Conn.TimeoutMs);
      I.WriteString(ConnectionSection(Conn.Id), 'InstanceUrl', Conn.InstanceUrl);
      I.WriteString(ConnectionSection(Conn.Id), 'TavilySearchDepth', Conn.TavilySearchDepth);
      I.WriteString(ConnectionSection(Conn.Id), 'CustomHeaderName', Conn.CustomHeaderName);
      I.WriteString(ConnectionSection(Conn.Id), 'CustomHeaderValue', Conn.CustomHeaderValue);
    end;
  finally
    OldIds.Free;
    I.Free;
  end;
end;

function ConnectionIsConfigured(const AConn: TWebSearchConnection): Boolean;
begin
  Result := ConnectionIsConfigured(AConn, False);
end;

function ConnectionIsConfigured(const AConn: TWebSearchConnection;
  AAllowPrivateInstances: Boolean): Boolean;
var
  Base: string;
  Err: string;
begin
  case AConn.Kind of
    wspkBrave, wspkTavily:
      Result := WebSearchApiKeyIsSet(AConn.Id);
    wspkSearxng:
      Result := ValidateSearxngInstanceUrl(AConn.InstanceUrl,
        AAllowPrivateInstances or WebSearchTrustedLocalAllowed(), Base, Err);
  else
    Result := False;
  end;
end;

function WebSearchHasUsableConnection(const AConfig: TWebSearchGlobalConfig): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(AConfig.Connections) do
    if AConfig.Connections[I].Enabled and
      ConnectionIsConfigured(AConfig.Connections[I], AConfig.AllowPrivateInstances) then
      Exit(True);
  Result := False;
end;

function WebSearchIsToolAvailable: Boolean;
var
  Cfg: TWebSearchGlobalConfig;
begin
  Cfg := LoadWebSearchConfig;
  Result := Cfg.Enabled and WebSearchHasUsableConnection(Cfg);
end;

procedure SortConnectionsByPriority(var AConnections: array of TWebSearchConnection);
var
  I, J, Best: Integer;
  Tmp: TWebSearchConnection;
begin
  for I := Low(AConnections) to High(AConnections) - 1 do
  begin
    Best := I;
    for J := I + 1 to High(AConnections) do
      if (AConnections[J].Priority < AConnections[Best].Priority) or
        ((AConnections[J].Priority = AConnections[Best].Priority) and
         (CompareText(AConnections[J].Id, AConnections[Best].Id) < 0)) then
        Best := J;
    if Best <> I then
    begin
      Tmp := AConnections[I];
      AConnections[I] := AConnections[Best];
      AConnections[Best] := Tmp;
    end;
  end;
end;

end.
