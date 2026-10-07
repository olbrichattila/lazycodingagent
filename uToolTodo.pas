unit uToolTodo;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, uAppTypes, uAgentTypes, uAgentToolBase;

type
  TToolTodo = class(TAgentTool)
  public
    constructor Create(AContext: TAgentToolContext); reintroduce;
    function MatchesName(const AName: string): Boolean; override;
    function GetDefinition: TToolDef; override;
    function Execute(const Args: TJSONObject): TToolExecutionResult; override;
  end;

implementation

constructor TToolTodo.Create(AContext: TAgentToolContext);
begin
  inherited Create(AContext);
  FAliases := 'plan';
  AllowedModes := [wmAsk, wmPlan, wmAgent];
  MutatesFiles := False;
end;

function TToolTodo.MatchesName(const AName: string): Boolean;
begin
  Result := inherited MatchesName(AName);
end;

function TToolTodo.GetDefinition: TToolDef;
begin
  Result.Name := 'todo';
  Result.Description := 'Read or replace chat-local tasks; use stable IDs and pending, in_progress or completed status.';
  SetLength(Result.Params, 2);
  Result.Params[0].Name := 'action';
  Result.Params[0].ParamType := 'string';
  Result.Params[0].Description := 'read or replace.';
  Result.Params[0].Required := True;
  Result.Params[1].Name := 'items';
  Result.Params[1].ParamType := 'array';
  Result.Params[1].Description := 'Task list for replace.';
  Result.Params[1].Required := False;
end;

function TToolTodo.Execute(const Args: TJSONObject): TToolExecutionResult;
var
  Action, ID, Status, Json: string;
  Items, CopyItems: TJSONArray;
  Item: TJSONObject;
  IDs: TStringList;
  I: Integer;
  O: TJSONObject;
  Session: TAgentToolSession;
begin
  Session := FContext.Session;
  Action := Args.Get('action', 'read');

  try
    if Action = 'replace' then
    begin
      Items := Args.Find('items') as TJSONArray;
      if Items = nil then raise Exception.Create('replace requires items');
      if Items.Count > 100 then raise Exception.Create('At most 100 tasks are supported');
      IDs := TStringList.Create;
      try
        for I := 0 to Items.Count - 1 do
        begin
          if not (Items[I] is TJSONObject) then raise Exception.Create('Task must be an object');
          Item := TJSONObject(Items[I]);
          if (Item.Find('id') = nil) or (Item.Find('text') = nil) or (Item.Find('status') = nil) then
            raise Exception.Create('Task requires id, text, and status');
          ID := Item.Get('id', '');
          Status := Item.Get('status', '');
          if (Trim(ID) = '') or (Trim(Item.Get('text', '')) = '') or (IDs.IndexOf(ID) >= 0) then
            raise Exception.Create('Task IDs must be nonempty and unique; text is required');
          if not ((Status = 'pending') or (Status = 'in_progress') or (Status = 'completed')) then
            raise Exception.Create('Invalid task status');
          IDs.Add(ID);
        end;
        CopyItems := Items.Clone as TJSONArray;
        Session.Tasks.Free;
        Session.Tasks := CopyItems;
      finally
        IDs.Free;
      end;
    end
    else if Action <> 'read' then
      raise Exception.Create('action must be read or replace');

    O := TJSONObject.Create;
    try
      O.Add('items', Session.Tasks.Clone);
      Json := O.AsJSON;
    finally
      O.Free;
    end;
  except
    on E: Exception do
      Json := ToolError(E.Message);
  end;
  Result := ToolResultFromJson(Json);
end;

end.
