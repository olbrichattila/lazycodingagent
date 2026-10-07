program tool_driver;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Classes, SysUtils, fpjson, jsonparser,
  uAppTypes, uAgentTypes, uAgentToolBase, uAgentTools, uBuildTargetResolver, uDiagnosticParse;

function ParseMode(const S: string): TWorkspaceMode;
begin
  if SameText(S, 'Ask') then Exit(wmAsk);
  if SameText(S, 'Plan') then Exit(wmPlan);
  Result := wmAgent;
end;

function ToolDefToDeclaration(const Def: TToolDef): TJSONObject;
var
  FnObj, Params, Props: TJSONObject;
  I: Integer;
  P: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('type', 'function');
  FnObj := TJSONObject.Create;
  FnObj.Add('name', Def.Name);
  FnObj.Add('description', Def.Description);
  Params := TJSONObject.Create;
  Params.Add('type', 'object');
  Props := TJSONObject.Create;
  for I := Low(Def.Params) to High(Def.Params) do
  begin
    P := TJSONObject.Create;
    P.Add('type', Def.Params[I].ParamType);
    P.Add('description', Def.Params[I].Description);
    Props.Add(Def.Params[I].Name, P);
  end;
  Params.Add('properties', Props);
  FnObj.Add('parameters', Params);
  Result.Add('function', FnObj);
end;

var
  Line, Name, Args, ModeStr, TargetPath: string;
  A, OutObj: TJSONObject;
  Context: TAgentToolContext;
  Registry: TAgentToolRegistry;
  D: TJSONArray;
  I: Integer;
  Mode: TWorkspaceMode;
  Res: TToolExecutionResult;
  Inv: TBuildInvocation;
  Messages: TJSONArray;
begin
  if ParamCount < 1 then
  begin
    WriteLn('Usage: tool_driver <project_root>');
    Halt(2);
  end;

  Context := TAgentToolContext.Create(ParamStr(1));
  Context.SetCancelFlag(nil);
  Registry := TAgentToolRegistry.Create(Context);
  try
    while not EOF(Input) do
    begin
      ReadLn(Line);
      if Trim(Line) = '' then Continue;
      try
        A := TJSONObject(GetJSON(Line));
        try
          ModeStr := A.Get('mode', 'Agent');
          Mode := ParseMode(ModeStr);
          Name := A.Get('tool', '');
          Context.SetCancelDeadline(0);
          if A.Get('cancel_after_ms', 0) > 0 then
            Context.SetCancelDeadline(GetTickCount64 + QWord(A.Get('cancel_after_ms', 0)));

          if Name = '_clear' then
          begin
            Context.ClearSession;
            WriteLn('{}');
          end
          else if Name = '_resolve_build' then
          begin
            TargetPath := A.Get('target', '');
            FillChar(Inv, SizeOf(Inv), 0);
            try
              if not ResolveBuildInvocation(ParamStr(1), TargetPath, Inv) then
                WriteLn('{"error":"resolve failed"}')
              else
              begin
                OutObj := TJSONObject.Create;
                try
                  OutObj.Add('runner', Inv.RunnerLabel);
                  OutObj.Add('executable', Inv.Executable);
                  OutObj.Add('target', Inv.ResolvedTarget);
                  OutObj.Add('use_shell', Inv.UseShell);
                  if Inv.UseShell then
                    OutObj.Add('shell_command', Inv.ShellCommand)
                  else
                    OutObj.Add('args', Inv.Args.CommaText);
                  WriteLn(OutObj.AsJSON);
                finally
                  OutObj.Free;
                end;
              end;
            finally
              FreeBuildInvocation(Inv);
            end;
          end
          else if Name = '_parse_diagnostics' then
          begin
            Messages := TJSONArray.Create;
            try
              ParseCompilerOutput(A.Get('text', ''), Messages);
              WriteLn(Messages.AsJSON);
            finally
              Messages.Free;
            end;
          end
          else if Name = '_json_wellformed' then
          begin
            if A.Find('args') = nil then Args := '{}'
            else if A.Types['args'] = jtString then Args := A.Get('args', '{}')
            else Args := A.Find('args').AsJSON;
            OutObj := TJSONObject.Create;
            try
              OutObj.Add('wellformed', JsonToolArgumentsWellFormed(Args));
              WriteLn(OutObj.AsJSON);
            finally
              OutObj.Free;
            end;
          end
          else if Name = '_declarations' then
          begin
            D := TJSONArray.Create;
            try
              for I := 0 to Registry.ToolCount - 1 do
              begin
                if not Registry.GetTool(I).Advertised then Continue;
                if not Registry.GetTool(I).ToolAllowedInMode(Mode) then Continue;
                D.Add(ToolDefToDeclaration(Registry.GetTool(I).GetDefinition));
              end;
              WriteLn(D.AsJSON);
            finally
              D.Free;
            end;
          end
          else
          begin
            if A.Find('args') = nil then Args := '{}'
            else if A.Types['args'] = jtString then Args := A.Get('args', '{}')
            else Args := A.Find('args').AsJSON;
            Res := Registry.ExecuteTool(Name, Args, Mode);
            WriteLn(Res.Output);
          end;
        finally
          A.Free;
        end;
      except
        on E: Exception do
          WriteLn(ToolError(E.Message));
      end;
      Flush(Output);
    end;
  finally
    Registry.Free;
    Context.Free;
  end;
end.
