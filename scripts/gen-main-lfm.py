#!/usr/bin/env python3
"""Generate mainunit.lfm for static designer layout."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
menu_tail = (ROOT / "mainunit.lfm").read_text().split("  object MainMenu1: TMainMenu", 1)[1]
menu_tail = "  object MainMenu1: TMainMenu" + menu_tail

nav_items = [
    ("sbtnNavBrain", 10, "◉"), ("sbtnNavKnowledge", 9, "📖"), ("sbtnNavExecPlans", 8, "☑"),
    ("sbtnNavMultiAgent", 7, "⬡"), ("sbtnNavToolErrors", 6, "⚠"), ("sbtnNavTasks", 5, "☰"),
    ("sbtnNavTools", 4, "◈"), ("sbtnNavBots", 3, "✦"), ("sbtnNavSessions", 2, "✉"),
    ("sbtnNavProjects", 1, "◫"), ("sbtnNavHome", 0, "⌂"),
]
nav_rail = ""
for name, tag, cap in nav_items:
    nav_rail += f"""      object {name}: TSpeedButton
        Tag = {tag}
        Left = 6
        Height = 40
        Top = 0
        Width = 100
        Align = alTop
        Caption = '{cap}'
        Flat = True
        GroupIndex = 1
        OnClick = NavRailBtnClick
      end
"""

body = f"""object LazyCodingAgentForm: TLazyCodingAgentForm
  Left = 5960
  Height = 1800
  Top = 468
  Width = 2880
  Caption = 'LazyCodingAgent — AI Workspace'
  ClientHeight = 1800
  ClientWidth = 2880
  Constraints.MinHeight = 1200
  Constraints.MinWidth = 1800
  DesignTimePPI = 192
  Menu = MainMenu1
  Position = poScreenCenter
  LCLVersion = '4.8.0.0'
  OnCloseQuery = FormCloseQuery
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnShow = FormShow
  object pnlMainContainer: TPanel
    Left = 0
    Height = 1312
    Top = 0
    Width = 2880
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 0
    object pnlNavRailHost: TPanel
      Left = 0
      Height = 1312
      Top = 0
      Width = 112
      Align = alLeft
      BevelOuter = bvNone
      TabOrder = 0
{nav_rail}    end
    object pnlNavHost: TPanel
      Left = 112
      Height = 1312
      Top = 0
      Width = 500
      Align = alLeft
      BevelOuter = bvNone
      TabOrder = 1
      object pnlNavChrome: TPanel
        Left = 0
        Height = 68
        Top = 0
        Width = 500
        Align = alTop
        BevelOuter = bvNone
        object lblNavTitle: TLabel
          Left = 16
          Height = 36
          Top = 18
          Width = 142
          Caption = 'Navigation'
        end
        object btnNavHide: TButton
          Tag = 0
          Left = 428
          Height = 50
          Top = 8
          Width = 64
          Caption = '✕'
          TabOrder = 0
          OnClick = PanelHideClick
        end
      end
      object pnlNavContent: TPanel
        Left = 0
        Height = 1244
        Top = 68
        Width = 500
        Align = alClient
        BevelOuter = bvNone
        TabOrder = 1
        object lblNavViewTitle: TLabel
          Left = 12
          Height = 28
          Top = 12
          Width = 476
          Align = alTop
          Caption = 'Workspaces'
          Layout = tlCenter
        end
        object lblNavViewSub: TLabel
          Left = 12
          Height = 22
          Top = 40
          Width = 476
          Align = alTop
          Caption = 'Select a workspace'
          Layout = tlCenter
        end
        object btnNavPrimary: TButton
          Left = 12
          Height = 40
          Top = 1192
          Width = 476
          Align = alBottom
          Caption = 'Action'
          TabOrder = 0
        end
        object btnNavSecondary: TButton
          Left = 12
          Height = 36
          Top = 1156
          Width = 476
          Align = alBottom
          Caption = 'Secondary'
          TabOrder = 1
          Visible = False
        end
        object lstNavFile: TListBox
          Left = 12
          Height = 1082
          Top = 62
          Width = 476
          Align = alClient
          ItemHeight = 0
          TabOrder = 2
        end
        object tvNavProjects: TTreeView
          Left = 12
          Height = 1082
          Top = 62
          Width = 476
          Align = alClient
          ReadOnly = True
          TabOrder = 3
          Visible = False
        end
        object lstNavLog: TListBox
          Left = 12
          Height = 1082
          Top = 62
          Width = 476
          Align = alClient
          ItemHeight = 0
          TabOrder = 4
          Visible = False
        end
        object lstNavErrors: TListBox
          Left = 12
          Height = 1082
          Top = 62
          Width = 476
          Align = alClient
          ItemHeight = 0
          TabOrder = 5
          Visible = False
        end
      end
    end
    object splNav: TSplitter
      Left = 612
      Height = 1312
      Top = 0
      Width = 10
      MinSize = 160
    end
    object pnlUtilityHost: TPanel
      Left = 2320
      Height = 1312
      Top = 0
      Width = 560
      Align = alRight
      BevelOuter = bvNone
      TabOrder = 2
      Visible = False
      object pnlUtilityChrome: TPanel
        Left = 0
        Height = 68
        Top = 0
        Width = 560
        Align = alTop
        BevelOuter = bvNone
        object lblUtilityTitle: TLabel
          Left = 16
          Height = 36
          Top = 18
          Width = 80
          Caption = 'Utility'
        end
        object btnUtilityHide: TButton
          Tag = 3
          Left = 488
          Height = 50
          Top = 8
          Width = 64
          Caption = '✕'
          TabOrder = 0
          OnClick = PanelHideClick
        end
      end
      object pnlUtilityContent: TPanel
        Left = 0
        Height = 1244
        Top = 68
        Width = 560
        Align = alClient
        BevelOuter = bvNone
        TabOrder = 1
        object pgcUtility: TPageControl
          Left = 0
          Height = 1244
          Top = 0
          Width = 560
          Align = alClient
          TabOrder = 0
          object tsUtilityScratch: TTabSheet
            Caption = 'Scratchpad'
            object memUtilityScratch: TMemo
              Left = 0
              Height = 1216
              Top = 0
              Width = 552
              Align = alClient
              ScrollBars = ssVertical
              TabOrder = 0
            end
          end
          object tsUtilityExecDetail: TTabSheet
            Caption = 'Execution Detail'
            object memUtilityExecDetail: TMemo
              Left = 0
              Height = 1216
              Top = 0
              Width = 552
              Align = alClient
              ReadOnly = True
              ScrollBars = ssBoth
              TabOrder = 0
              WordWrap = False
            end
          end
          object tsUtilityPlan: TTabSheet
            Caption = 'Plan'
            object pnlPlanHeader: TPanel
              Left = 0
              Height = 36
              Top = 0
              Width = 552
              Align = alTop
              BevelOuter = bvNone
              TabOrder = 0
              object lblPlanPath: TLabel
                Left = 8
                Height = 15
                Top = 10
                Width = 52
                Caption = 'Plan file:'
              end
              object cboPlanModel: TComboBox
                Left = 280
                Height = 25
                Top = 4
                Width = 180
                Anchors = [akTop, akRight]
                ItemHeight = 22
                Style = csDropDownList
                TabOrder = 0
              end
              object btnPlanBuild: TButton
                Left = 468
                Height = 28
                Top = 4
                Width = 72
                Anchors = [akTop, akRight]
                Caption = 'Build'
                TabOrder = 1
              end
            end
            object memPlanBody: TMemo
              Left = 0
              Height = 1180
              Top = 36
              Width = 552
              Align = alClient
              ReadOnly = True
              ScrollBars = ssVertical
              TabOrder = 1
            end
          end
        end
      end
    end
    object splUtility: TSplitter
      Left = 2310
      Height = 1312
      Top = 0
      Width = 10
      Align = alRight
      MinSize = 160
      ResizeAnchor = akRight
      Visible = False
    end
    object pnlReservedHost: TPanel
      Left = 1740
      Height = 1312
      Top = 0
      Width = 570
      Align = alRight
      BevelOuter = bvNone
      TabOrder = 3
      Visible = False
      object pnlReservedChrome: TPanel
        Left = 0
        Height = 68
        Top = 0
        Width = 570
        Align = alTop
        BevelOuter = bvNone
        object lblReservedTitle: TLabel
          Left = 16
          Height = 36
          Top = 18
          Width = 137
          Caption = 'Guidelines'
        end
        object btnReservedHide: TButton
          Tag = 2
          Left = 498
          Height = 50
          Top = 8
          Width = 64
          Caption = '✕'
          TabOrder = 0
          OnClick = PanelHideClick
        end
      end
      object pnlReservedContent: TPanel
        Left = 0
        Height = 1244
        Top = 68
        Width = 570
        Align = alClient
        BevelOuter = bvNone
        TabOrder = 1
        object memReserved: TMemo
          Left = 0
          Height = 1244
          Top = 0
          Width = 570
          Align = alClient
          BorderStyle = bsNone
          ScrollBars = ssVertical
          TabOrder = 0
        end
      end
    end
    object splReserved: TSplitter
      Left = 1730
      Height = 1312
      Top = 0
      Width = 10
      Align = alRight
      MinSize = 180
      ResizeAnchor = akRight
      Visible = False
    end
    object pnlChatHost: TPanel
      Left = 622
      Height = 1312
      Top = 0
      Width = 1108
      Align = alClient
      BevelOuter = bvNone
      TabOrder = 5
      object pnlChatChrome: TPanel
        Left = 0
        Height = 68
        Top = 0
        Width = 1108
        Align = alTop
        BevelOuter = bvNone
        object lblChatTitle: TLabel
          Left = 16
          Height = 36
          Top = 18
          Width = 62
          Caption = 'Chat'
        end
        object btnChatHide: TButton
          Tag = 1
          Left = 1020
          Height = 50
          Top = 8
          Width = 64
          Caption = '✕'
          TabOrder = 0
          OnClick = PanelHideClick
        end
      end
      object pgcCenter: TPageControl
        Left = 0
        Height = 1244
        Top = 68
        Width = 1108
        Align = alClient
        TabOrder = 1
        object tsChat: TTabSheet
          Caption = 'Chat'
          object lblChatHeading: TLabel
            Left = 16
            Height = 32
            Top = 8
            Width = 400
            Caption = 'What should we build?'
          end
          object lblChatSession: TLabel
            Left = 16
            Height = 20
            Top = 44
            Width = 200
            Caption = 'Session:'
          end
          object lblChatSub: TLabel
            Left = 16
            Height = 20
            Top = 68
            Width = 500
            Caption = 'Autonomous AI agent workspace'
          end
          object pnlChatComposer: TPanel
            Left = 0
            Height = 200
            Top = 1044
            Width = 1100
            Align = alBottom
            BevelOuter = bvNone
            TabOrder = 0
            object lblChatWorkspaceTag: TLabel
              Left = 12
              Height = 16
              Top = 8
              Width = 200
              Caption = 'PROJECT'
            end
            object memChatPrompt: TMemo
              Left = 12
              Height = 100
              Top = 28
              Width = 1076
              Anchors = [akLeft, akTop, akRight]
              ScrollBars = ssVertical
              TabOrder = 0
            end
            object pnlChatFooter: TPanel
              Left = 0
              Height = 56
              Top = 144
              Width = 1100
              Align = alBottom
              BevelOuter = bvNone
              TabOrder = 1
              object cboChatMode: TComboBox
                Left = 12
                Height = 25
                Top = 14
                Width = 140
                ItemHeight = 22
                Style = csDropDownList
                TabOrder = 0
              end
              object cboChatModel: TComboBox
                Left = 164
                Height = 25
                Top = 14
                Width = 220
                ItemHeight = 22
                Style = csDropDownList
                TabOrder = 1
              end
              object btnChatStop: TButton
                Left = 900
                Height = 32
                Top = 12
                Width = 80
                Anchors = [akTop, akRight]
                Caption = 'Stop'
                TabOrder = 2
                Visible = False
              end
              object btnChatSend: TButton
                Left = 992
                Height = 32
                Top = 12
                Width = 96
                Anchors = [akTop, akRight]
                Caption = 'Run Agent'
                TabOrder = 3
              end
            end
          end
          object memChatHistory: TMemo
            Left = 0
            Height = 940
            Top = 96
            Width = 1100
            Align = alClient
            ReadOnly = True
            ScrollBars = ssVertical
            TabOrder = 1
          end
        end
        object tsEditor: TTabSheet
          Caption = 'Editor'
          object synEditor: TSynEdit
            Left = 0
            Height = 1216
            Top = 0
            Width = 1100
            Align = alClient
            TabOrder = 0
          end
        end
        object tsMarkdown: TTabSheet
          Caption = 'Markdown'
          object memMarkdownPreview: TMemo
            Left = 0
            Height = 1216
            Top = 0
            Width = 1100
            Align = alClient
            ReadOnly = True
            ScrollBars = ssVertical
            TabOrder = 0
          end
        end
      end
    end
  end
  object splTerminal: TSplitter
    Cursor = crVSplit
    Left = 0
    Height = 10
    Top = 1312
    Width = 2880
    Align = alBottom
    MinSize = 120
    ResizeAnchor = akBottom
    Visible = False
    OnMoved = SplTerminalMoved
  end
  object pnlTerminalHost: TPanel
    Left = 0
    Height = 440
    Top = 1322
    Width = 2880
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 2
    Visible = False
    object pnlTerminalChrome: TPanel
      Left = 0
      Height = 68
      Top = 0
      Width = 2880
      Align = alTop
      BevelOuter = bvNone
      object lblTerminalTitle: TLabel
        Left = 16
        Height = 36
        Top = 18
        Width = 114
        Caption = 'Terminal'
      end
      object btnTerminalHide: TButton
        Tag = 4
        Left = 2808
        Height = 50
        Top = 8
        Width = 64
        Anchors = [akTop, akRight]
        Caption = '✕'
        TabOrder = 0
        OnClick = PanelHideClick
      end
    end
    object pnlTerminalContent: TPanel
      Left = 0
      Height = 372
      Top = 68
      Width = 2880
      Align = alClient
      BevelOuter = bvNone
      TabOrder = 1
      object lblTerminalStatus: TLabel
        Left = 8
        Height = 15
        Top = 4
        Width = 4
        Align = alTop
        AutoSize = True
        WordWrap = True
      end
    end
  end
  object StatusBar1: TStatusBar
    Left = 0
    Height = 38
    Top = 1762
    Width = 2880
    Panels = <>
  end
{menu_tail}
end
"""

body = body.replace("{menu_tail}", menu_tail)
(ROOT / "mainunit.lfm").write_text(body)
print("Wrote", ROOT / "mainunit.lfm", "lines", len(body.splitlines()))
