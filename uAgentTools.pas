unit uAgentTools;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Process, fpjson, jsonparser, FileUtil, LazFileUtils, uAgentTypes;

type
  { Tool Execution Result }
  TToolExecutionResult = record
    Success: Boolean;
    Output: string;
    Summary: string;
  end;

  { Tool Context State (Tasks, Workspace Root, etc.) }
  TAgentToolContext = class
  private
    FWorkspaceRoot: string;
    FTasks: array of TTaskItem;
    function ResolvePath(const APath: string): string;
  public
    constructor Create(const AWorkspaceRoot: string);
    procedure ClearTasks;
    procedure AddTask(const AId, AText, AStatus: string);
    function GetTasksJson: string;

    property WorkspaceRoot: string read FWorkspaceRoot write FWorkspaceRoot;
  end;

  { Tool Registry and Executor }
  TAgentToolRegistry = class
  private
    FContext: TAgentToolContext;
    function ToolReadFile(const Args: TJSONObject): TToolExecutionResult;
    function ToolWriteFile(const Args: TJSONObject): TToolExecutionResult;
    function ToolListDirectory(const Args: TJSONObject): TToolExecutionResult;
    function ToolSearchCode(const Args: TJSONObject): TToolExecutionResult;
    function ToolRunProcess(const Args: TJSONObject): TToolExecutionResult;
    function ToolDiagnostics(const Args: TJSONObject): TToolExecutionResult;
    function ToolTodo(const Args: TJSONObject): TToolExecutionResult;
  public
    constructor Create(AContext: TAgentToolContext);
    function GetToolDefinitions: TToolDefArray;
    function ExecuteTool(const AName, AArgumentsJson: string): TToolExecutionResult;
  end;

implementation

{ TAgentToolContext }

constructor TAgentToolContext.Create(const AWorkspaceRoot: string);
begin
  inherited Create;
  if Trim(AWorkspaceRoot) <> '' then
    FWorkspaceRoot := ExpandFileName(AWorkspaceRoot)
  else
    FWorkspaceRoot := GetCurrentDir;
  SetLength(FTasks, 0);
end;

function TAgentToolContext.ResolvePath(const APath: string): string;
begin
  if FilenameIsAbsolute(APath) then
    Result := ExpandFileName(APath)
  else
    Result := ExpandFileName(IncludeTrailingPathDelimiter(FWorkspaceRoot) + APath);
end;

procedure TAgentToolContext.ClearTasks;
begin
  SetLength(FTasks, 0);
end;

procedure TAgentToolContext.AddTask(const AId, AText, AStatus: string);
var
  Idx: Integer;
begin
  Idx := Length(FTasks);
  SetLength(FTasks, Idx + 1);
  FTasks[Idx].Id := AId;
  FTasks[Idx].Text := AText;
  FTasks[Idx].Status := AStatus;
end;

function TAgentToolContext.GetTasksJson: string;
var
  Arr: TJSONArray;
  Obj: TJSONObject;
  I: Integer;
begin
  Arr := TJSONArray.Create;
  try
    for I := Low(FTasks) to High(FTasks) do begin
      Obj := TJSONObject.Create;
      Obj.Add('id', FTasks[I].Id);
      Obj.Add('text', FTasks[I].Text);
      Obj.Add('status', FTasks[I].Status);
      Arr.Add(Obj);
    end;
    Result := Arr.AsJSON;
  finally
    Arr.Free;
  end;
end;

{ TAgentToolRegistry }

constructor TAgentToolRegistry.Create(AContext: TAgentToolContext);
begin
  inherited Create;
  FContext := AContext;
end;

function TAgentToolRegistry.GetToolDefinitions: TToolDefArray;
begin
  SetLength(Result, 7);

  // 1. read_file
  Result[0].Name := 'read_file';
  Result[0].Description := 'Read the text contents of a file with optional line offset and limit.';
  SetLength(Result[0].Params, 3);
  Result[0].Params[0].Name := 'path';
  Result[0].Params[0].ParamType := 'string';
  Result[0].Params[0].Description := 'Relative or absolute file path to read.';
  Result[0].Params[0].Required := True;
  Result[0].Params[1].Name := 'offset';
  Result[0].Params[1].ParamType := 'integer';
  Result[0].Params[1].Description := 'Line number to start reading from (1-indexed).';
  Result[0].Params[1].Required := False;
  Result[0].Params[2].Name := 'limit';
  Result[0].Params[2].ParamType := 'integer';
  Result[0].Params[2].Description := 'Maximum number of lines to read (default: 2000).';
  Result[0].Params[2].Required := False;

  // 2. write_file
  Result[1].Name := 'write_file';
  Result[1].Description := 'Write or overwrite complete content to a file. Automatically creates directories.';
  SetLength(Result[1].Params, 2);
  Result[1].Params[0].Name := 'path';
  Result[1].Params[0].ParamType := 'string';
  Result[1].Params[0].Description := 'Relative or absolute file path to write.';
  Result[1].Params[0].Required := True;
  Result[1].Params[1].Name := 'content';
  Result[1].Params[1].ParamType := 'string';
  Result[1].Params[1].Description := 'Complete text content to write to the file.';
  Result[1].Params[1].Required := True;

  // 3. list_directory
  Result[2].Name := 'list_directory';
  Result[2].Description := 'List files and directories in a directory with sizes and types.';
  SetLength(Result[2].Params, 2);
  Result[2].Params[0].Name := 'path';
  Result[2].Params[0].ParamType := 'string';
  Result[2].Params[0].Description := 'Directory path to list (empty for workspace root).';
  Result[2].Params[0].Required := False;
  Result[2].Params[1].Name := 'include_hidden';
  Result[2].Params[1].ParamType := 'boolean';
  Result[2].Params[1].Description := 'Whether to include hidden files.';
  Result[2].Params[1].Required := False;

  // 4. search_code
  Result[3].Name := 'search_code';
  Result[3].Description := 'Search files for query text or regex patterns across the workspace.';
  SetLength(Result[3].Params, 3);
  Result[3].Params[0].Name := 'query';
  Result[3].Params[0].ParamType := 'string';
  Result[3].Params[0].Description := 'String query to search for.';
  Result[3].Params[0].Required := True;
  Result[3].Params[1].Name := 'path';
  Result[3].Params[1].ParamType := 'string';
  Result[3].Params[1].Description := 'Subdirectory or specific file path to search within.';
  Result[3].Params[1].Required := False;
  Result[3].Params[2].Name := 'case_sensitive';
  Result[3].Params[2].ParamType := 'boolean';
  Result[3].Params[2].Description := 'Whether search should be case sensitive.';
  Result[3].Params[2].Required := False;

  // 5. run_process
  Result[4].Name := 'run_process';
  Result[4].Description := 'Execute a shell command or executable in the workspace directory.';
  SetLength(Result[4].Params, 3);
  Result[4].Params[0].Name := 'command';
  Result[4].Params[0].ParamType := 'string';
  Result[4].Params[0].Description := 'Command or executable with arguments to run.';
  Result[4].Params[0].Required := True;
  Result[4].Params[1].Name := 'cwd';
  Result[4].Params[1].ParamType := 'string';
  Result[4].Params[1].Description := 'Current working directory (defaults to workspace root).';
  Result[4].Params[1].Required := False;
  Result[4].Params[2].Name := 'timeout_ms';
  Result[4].Params[2].ParamType := 'integer';
  Result[4].Params[2].Description := 'Execution timeout in milliseconds.';
  Result[4].Params[2].Required := False;

  // 6. diagnostics
  Result[5].Name := 'diagnostics';
  Result[5].Description := 'Run compiler / build diagnostics (e.g. lazbuild / fpc) against a project file.';
  SetLength(Result[5].Params, 2);
  Result[5].Params[0].Name := 'target';
  Result[5].Params[0].ParamType := 'string';
  Result[5].Params[0].Description := 'Project file (.lpi, .lpr, .pas) to check or build.';
  Result[5].Params[0].Required := False;
  Result[5].Params[1].Name := 'action';
  Result[5].Params[1].ParamType := 'string';
  Result[5].Params[1].Description := 'Action to perform: "build" or "read".';
  Result[5].Params[1].Required := True;

  // 7. todo
  Result[6].Name := 'todo';
  Result[6].Description := 'Read or update session task checklist.';
  SetLength(Result[6].Params, 2);
  Result[6].Params[0].Name := 'action';
  Result[6].Params[0].ParamType := 'string';
  Result[6].Params[0].Description := 'Action to perform: "read" or "replace".';
  Result[6].Params[0].Required := True;
  Result[6].Params[1].Name := 'items';
  Result[6].Params[1].ParamType := 'array';
  Result[6].Params[1].Description := 'List of tasks [{id, text, status}].';
  Result[6].Params[1].Required := False;
end;

function TAgentToolRegistry.ExecuteTool(const AName, AArgumentsJson: string): TToolExecutionResult;
var
  Data: TJSONData;
  Args: TJSONObject;
begin
  Result.Success := False;
  Result.Output := '';
  Result.Summary := '';

  try
    Data := GetJSON(AArgumentsJson);
  except
    on E: Exception do begin
      Result.Output := 'JSON argument parsing error: ' + E.Message;
      Result.Summary := 'Invalid Arguments';
      Exit;
    end;
  end;

  try
    if Data is TJSONObject then
      Args := TJSONObject(Data)
    else
      Args := TJSONObject.Create;

    if SameText(AName, 'read_file') then
      Result := ToolReadFile(Args)
    else if SameText(AName, 'write_file') then
      Result := ToolWriteFile(Args)
    else if SameText(AName, 'list_directory') then
      Result := ToolListDirectory(Args)
    else if SameText(AName, 'search_code') then
      Result := ToolSearchCode(Args)
    else if SameText(AName, 'run_process') or SameText(AName, 'shell') then
      Result := ToolRunProcess(Args)
    else if SameText(AName, 'diagnostics') then
      Result := ToolDiagnostics(Args)
    else if SameText(AName, 'todo') then
      Result := ToolTodo(Args)
    else begin
      Result.Output := Format('Unknown tool "%s"', [AName]);
      Result.Summary := 'Unknown Tool';
    end;
  finally
    if not (Data is TJSONObject) then
      Args.Free;
    Data.Free;
  end;
end;

function TAgentToolRegistry.ToolReadFile(const Args: TJSONObject): TToolExecutionResult;
var
  FilePath, FullPath: string;
  Offset, Limit, I, StartIdx, EndIdx: Integer;
  Lines: TStringList;
  OutLines: TStringList;
begin
  FilePath := Args.Get('path', '');
  Offset := Args.Get('offset', 1);
  Limit := Args.Get('limit', 2000);

  if FilePath = '' then begin
    Result.Success := False;
    Result.Output := 'Error: "path" argument is required.';
    Result.Summary := 'Missing path';
    Exit;
  end;

  FullPath := FContext.ResolvePath(FilePath);
  if not FileExists(FullPath) then begin
    Result.Success := False;
    Result.Output := Format('Error: File "%s" not found at %s', [FilePath, FullPath]);
    Result.Summary := 'File not found';
    Exit;
  end;

  Lines := TStringList.Create;
  OutLines := TStringList.Create;
  try
    try
      Lines.LoadFromFile(FullPath);
      if Offset < 1 then Offset := 1;
      if Limit < 1 then Limit := 2000;

      StartIdx := Offset - 1;
      if StartIdx >= Lines.Count then begin
        Result.Success := True;
        Result.Output := Format('(File has %d lines, offset %d exceeds total)', [Lines.Count, Offset]);
        Result.Summary := Format('Read %s (0 lines)', [ExtractFileName(FilePath)]);
        Exit;
      end;

      EndIdx := StartIdx + Limit - 1;
      if EndIdx >= Lines.Count then EndIdx := Lines.Count - 1;

      for I := StartIdx to EndIdx do
        OutLines.Add(Format('%d|%s', [I + 1, Lines[I]]));

      Result.Success := True;
      Result.Output := OutLines.Text;
      Result.Summary := Format('Read %s (%d lines)', [ExtractFileName(FilePath), EndIdx - StartIdx + 1]);
    except
      on E: Exception do begin
        Result.Success := False;
        Result.Output := 'Error reading file: ' + E.Message;
        Result.Summary := 'Read error';
      end;
    end;
  finally
    OutLines.Free;
    Lines.Free;
  end;
end;

function TAgentToolRegistry.ToolWriteFile(const Args: TJSONObject): TToolExecutionResult;
var
  FilePath, Content, FullPath, Dir: string;
  Lines: TStringList;
begin
  FilePath := Args.Get('path', '');
  Content := Args.Get('content', '');

  if FilePath = '' then begin
    Result.Success := False;
    Result.Output := 'Error: "path" argument is required.';
    Result.Summary := 'Missing path';
    Exit;
  end;

  FullPath := FContext.ResolvePath(FilePath);
  Dir := ExtractFileDir(FullPath);
  if (Dir <> '') and not DirectoryExists(Dir) then
    ForceDirectories(Dir);

  Lines := TStringList.Create;
  try
    try
      Lines.Text := Content;
      Lines.SaveToFile(FullPath);
      Result.Success := True;
      Result.Output := Format('Successfully wrote %d bytes to "%s".', [Length(Content), FilePath]);
      Result.Summary := Format('Wrote %s (%d bytes)', [ExtractFileName(FilePath), Length(Content)]);
    except
      on E: Exception do begin
        Result.Success := False;
        Result.Output := 'Error writing file: ' + E.Message;
        Result.Summary := 'Write error';
      end;
    end;
  finally
    Lines.Free;
  end;
end;

function TAgentToolRegistry.ToolListDirectory(const Args: TJSONObject): TToolExecutionResult;
var
  DirPath, FullPath: string;
  IncludeHidden: Boolean;
  Rec: TSearchRec;
  OutLines: TStringList;
begin
  DirPath := Args.Get('path', '');
  IncludeHidden := Args.Get('include_hidden', False);

  if DirPath = '' then
    FullPath := FContext.WorkspaceRoot
  else
    FullPath := FContext.ResolvePath(DirPath);

  if not DirectoryExists(FullPath) then begin
    Result.Success := False;
    Result.Output := Format('Error: Directory "%s" does not exist.', [FullPath]);
    Result.Summary := 'Dir not found';
    Exit;
  end;

  OutLines := TStringList.Create;
  try
    if FindFirst(IncludeTrailingPathDelimiter(FullPath) + '*', faAnyFile, Rec) = 0 then begin
      repeat
        if (Rec.Name = '.') or (Rec.Name = '..') then Continue;
        if not IncludeHidden and (Rec.Name[1] = '.') then Continue;

        if (Rec.Attr and faDirectory) <> 0 then
          OutLines.Add(Format('[DIR]  %s', [Rec.Name]))
        else
          OutLines.Add(Format('[FILE] %s (%d bytes)', [Rec.Name, Rec.Size]));
      until FindNext(Rec) <> 0;
      FindClose(Rec);
    end;

    Result.Success := True;
    Result.Output := OutLines.Text;
    Result.Summary := Format('Listed %s (%d items)', [ExtractFileName(FullPath), OutLines.Count]);
  finally
    OutLines.Free;
  end;
end;

function TAgentToolRegistry.ToolSearchCode(const Args: TJSONObject): TToolExecutionResult;
var
  Query, SubPath, FullPath: string;
  CaseSens: Boolean;
  Matches: TStringList;

  procedure SearchDir(const ADir: string);
  var
    Rec: TSearchRec;
    FileLines: TStringList;
    I: Integer;
    LineStr, SearchTarget, TargetQuery: string;
  begin
    if FindFirst(IncludeTrailingPathDelimiter(ADir) + '*', faAnyFile, Rec) = 0 then begin
      repeat
        if (Rec.Name = '.') or (Rec.Name = '..') or (Rec.Name = '.git') or (Rec.Name = 'backup') or (Rec.Name = 'lib') then Continue;

        if (Rec.Attr and faDirectory) <> 0 then
          SearchDir(IncludeTrailingPathDelimiter(ADir) + Rec.Name)
        else begin
          FileLines := TStringList.Create;
          try
            try
              FileLines.LoadFromFile(IncludeTrailingPathDelimiter(ADir) + Rec.Name);
              for I := 0 to FileLines.Count - 1 do begin
                LineStr := FileLines[I];
                if CaseSens then begin
                  SearchTarget := LineStr;
                  TargetQuery := Query;
                end else begin
                  SearchTarget := LowerCase(LineStr);
                  TargetQuery := LowerCase(Query);
                end;

                if Pos(TargetQuery, SearchTarget) > 0 then begin
                  Matches.Add(Format('%s:%d: %s', [ExtractRelativePath(FContext.WorkspaceRoot, IncludeTrailingPathDelimiter(ADir) + Rec.Name), I + 1, Trim(LineStr)]));
                  if Matches.Count >= 200 then Exit;
                end;
              end;
            except
              // ignore binary or unreadable files
            end;
          finally
            FileLines.Free;
          end;
        end;
        if Matches.Count >= 200 then Break;
      until FindNext(Rec) <> 0;
      FindClose(Rec);
    end;
  end;

begin
  Query := Args.Get('query', '');
  SubPath := Args.Get('path', '');
  CaseSens := Args.Get('case_sensitive', False);

  if Query = '' then begin
    Result.Success := False;
    Result.Output := 'Error: "query" parameter is required.';
    Result.Summary := 'Missing query';
    Exit;
  end;

  if SubPath = '' then
    FullPath := FContext.WorkspaceRoot
  else
    FullPath := FContext.ResolvePath(SubPath);

  Matches := TStringList.Create;
  try
    if DirectoryExists(FullPath) then
      SearchDir(FullPath)
    else if FileExists(FullPath) then begin
      // search single file
      SearchDir(ExtractFileDir(FullPath));
    end;

    Result.Success := True;
    if Matches.Count = 0 then
      Result.Output := 'No matches found.'
    else
      Result.Output := Matches.Text;
    Result.Summary := Format('Search "%s" (%d matches)', [Query, Matches.Count]);
  finally
    Matches.Free;
  end;
end;

function TAgentToolRegistry.ToolRunProcess(const Args: TJSONObject): TToolExecutionResult;
var
  Cmd, Cwd: string;
  TimeoutMs: Integer;
  AProcess: TProcess;
  OutStream: TStringStream;
  Buffer: array[0..2047] of Byte;
  BytesRead: Integer;
  StartTime: QWord;
begin
  Cmd := Args.Get('command', '');
  Cwd := Args.Get('cwd', '');
  TimeoutMs := Args.Get('timeout_ms', 60000);

  if Cmd = '' then begin
    Result.Success := False;
    Result.Output := 'Error: "command" parameter is required.';
    Result.Summary := 'Missing command';
    Exit;
  end;

  if Cwd = '' then
    Cwd := FContext.WorkspaceRoot
  else
    Cwd := FContext.ResolvePath(Cwd);

  AProcess := TProcess.Create(nil);
  OutStream := TStringStream.Create('');
  try
    {$IFDEF WINDOWS}
    AProcess.Executable := 'cmd.exe';
    AProcess.Parameters.Add('/c');
    AProcess.Parameters.Add(Cmd);
    {$ELSE}
    AProcess.Executable := '/bin/sh';
    AProcess.Parameters.Add('-c');
    AProcess.Parameters.Add(Cmd);
    {$ENDIF}

    AProcess.CurrentDirectory := Cwd;
    AProcess.Options := [poUsePipes, poStderrToOutPut, poNoConsole];
    AProcess.ShowWindow := swoNone;

    try
      AProcess.Execute;
      StartTime := GetTickCount64;

      while AProcess.Running do begin
        while AProcess.Output.NumBytesAvailable > 0 do begin
          BytesRead := AProcess.Output.Read(Buffer, SizeOf(Buffer));
          if BytesRead > 0 then
            OutStream.Write(Buffer, BytesRead);
        end;

        if (GetTickCount64 - StartTime) > QWord(TimeoutMs) then begin
          AProcess.Terminate(1);
          Result.Success := False;
          Result.Output := OutStream.DataString + #10 + Format('[Timed out after %d ms]', [TimeoutMs]);
          Result.Summary := 'Command timed out';
          Exit;
        end;
        Sleep(20);
      end;

      // Drain remaining
      while AProcess.Output.NumBytesAvailable > 0 do begin
        BytesRead := AProcess.Output.Read(Buffer, SizeOf(Buffer));
        if BytesRead > 0 then
          OutStream.Write(Buffer, BytesRead);
      end;

      Result.Success := (AProcess.ExitCode = 0);
      Result.Output := OutStream.DataString;
      Result.Summary := Format('Exec "%s" (Exit code %d)', [Cmd, AProcess.ExitCode]);
    except
      on E: Exception do begin
        Result.Success := False;
        Result.Output := 'Execution Error: ' + E.Message;
        Result.Summary := 'Exec failed';
      end;
    end;
  finally
    OutStream.Free;
    AProcess.Free;
  end;
end;

function TAgentToolRegistry.ToolDiagnostics(const Args: TJSONObject): TToolExecutionResult;
var
  Target, Action, FullTarget: string;
  RunCmd: string;
  RunArgs: TJSONObject;
begin
  Target := Args.Get('target', '');
  Action := Args.Get('action', 'build');

  if Target = '' then begin
    Target := 'lazycodingagent.lpi';
  end;

  FullTarget := FContext.ResolvePath(Target);
  if Action = 'build' then begin
    RunCmd := Format('lazbuild "%s"', [FullTarget]);
  end else begin
    RunCmd := Format('fpc "%s"', [FullTarget]);
  end;

  RunArgs := TJSONObject.Create;
  try
    RunArgs.Add('command', RunCmd);
    RunArgs.Add('cwd', FContext.WorkspaceRoot);
    Result := ToolRunProcess(RunArgs);
    Result.Summary := Format('Diagnostics on %s', [ExtractFileName(Target)]);
  finally
    RunArgs.Free;
  end;
end;

function TAgentToolRegistry.ToolTodo(const Args: TJSONObject): TToolExecutionResult;
var
  Action: string;
  ItemsArr: TJSONArray;
  ItemObj: TJSONObject;
  I: Integer;
begin
  Action := Args.Get('action', 'read');

  if SameText(Action, 'read') then begin
    Result.Success := True;
    Result.Output := FContext.GetTasksJson;
    Result.Summary := 'Read task list';
  end else if SameText(Action, 'replace') then begin
    if Args.IndexOfName('items') >= 0 then begin
      ItemsArr := Args.Arrays['items'];
      FContext.ClearTasks;
      for I := 0 to ItemsArr.Count - 1 do begin
        ItemObj := ItemsArr.Objects[I];
        FContext.AddTask(
          ItemObj.Get('id', Format('task_%d', [I + 1])),
          ItemObj.Get('text', ''),
          ItemObj.Get('status', 'pending')
        );
      end;
      Result.Success := True;
      Result.Output := Format('Updated %d tasks.', [ItemsArr.Count]);
      Result.Summary := Format('Saved %d tasks', [ItemsArr.Count]);
    end else begin
      Result.Success := False;
      Result.Output := 'Error: "items" array parameter is required for replace.';
      Result.Summary := 'Missing items';
    end;
  end else begin
    Result.Success := False;
    Result.Output := Format('Unknown action "%s"', [Action]);
    Result.Summary := 'Unknown action';
  end;
end;

end.
