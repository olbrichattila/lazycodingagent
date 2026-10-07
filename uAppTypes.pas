unit uAppTypes;

{$mode objfpc}{$H+}

interface

type
  TNavigationItem = (niHome, niProjects, niSessions, niBots);
  TWorkspaceMode = (wmAsk, wmPlan, wmAgent);
  TPanelId = (piNavigation, piChat, piReserved);
  TThemeKind = (tkDark, tkLight);

function NavigationCaption(AItem: TNavigationItem): string;
function NavigationHint(AItem: TNavigationItem): string;
function NavigationIconSymbol(AItem: TNavigationItem): string;
function WorkspaceModeCaption(AMode: TWorkspaceMode): string;
function WorkspaceModeDesc(AMode: TWorkspaceMode): string;
function PanelCaption(AId: TPanelId): string;

implementation

function NavigationCaption(AItem: TNavigationItem): string;
begin
  case AItem of
    niHome: Result := 'Home';
    niProjects: Result := 'Projects';
    niSessions: Result := 'Sessions';
    niBots: Result := 'Bots';
  end;
end;

function NavigationHint(AItem: TNavigationItem): string;
begin
  case AItem of
    niHome: Result := 'Home - Dashboard & Overview';
    niProjects: Result := 'Projects - Workspace files & tree';
    niSessions: Result := 'Sessions - Conversation history & agents';
    niBots: Result := 'Bots - Custom assistants & prompts';
  end;
end;

function NavigationIconSymbol(AItem: TNavigationItem): string;
begin
  case AItem of
    niHome: Result := '⌂';
    niProjects: Result := '◫';
    niSessions: Result := '💬';
    niBots: Result := '⚡';
  end;
end;

function WorkspaceModeCaption(AMode: TWorkspaceMode): string;
begin
  case AMode of
    wmAsk: Result := 'Ask';
    wmPlan: Result := 'Plan';
    wmAgent: Result := 'Agent';
  end;
end;

function WorkspaceModeDesc(AMode: TWorkspaceMode): string;
begin
  case AMode of
    wmAsk: Result := 'Ask questions without editing code';
    wmPlan: Result := 'Generate architectural plans & checklists';
    wmAgent: Result := 'Autonomous coding agent with full workspace access';
  end;
end;

function PanelCaption(AId: TPanelId): string;
begin
  case AId of
    piNavigation: Result := 'Navigation & Workspace';
    piChat: Result := 'Chat / AI Agent Workspace';
    piReserved: Result := 'Instructions & Context';
  end;
end;

end.
