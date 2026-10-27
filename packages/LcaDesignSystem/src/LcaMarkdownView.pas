unit LcaMarkdownView;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Contnrs, Controls, Graphics, Types, LCLType, LMessages, LcaThemedControl, LcaTheme;

type
  TSelectFragRec = record
    StartIdx: Integer;
    Text: string;
    DocRect: TRect;
  end;

  TLcaMarkdownView = class(TLcaThemedControl)
  private
    FSource: string;
    FBlocks: TObjectList;
    FContentHeight: Integer;
    FLayoutTextWidth: Integer;
    FScrollY: Integer;
    FAutoScrollToEnd: Boolean;
    FStickToBottom: Boolean;
    FShowVBar: Boolean;
    FDragScrollActive: Boolean;
    FDragThumbOffset: Integer;
    FWheelAccumY: Integer;
    FWheelFlushQueued: Boolean;
    FLayoutGuard: Boolean;
    FNeedsLayout: Boolean;
    FPlainText: string;
    FSelectFrags: array of TSelectFragRec;
    FSelAnchor: Integer;
    FSelCaret: Integer;
    FSelActive: Boolean;
    FTextSelDrag: Boolean;
    procedure SetAutoScrollToEnd(AValue: Boolean);
    procedure RebuildBlocksFromSource;
    procedure RelayoutDocument;
    function ContentPad: Integer;
    function ScrollbarThickness: Integer;
    function TextAreaWidth: Integer;
    function MaxScrollY: Integer;
    procedure ClampScroll;
    procedure UpdateStickToBottomFromScroll;
    procedure ApplyScrollPolicy(AForceStick: Boolean);
    procedure ScrollToEnd;
    function VerticalTrackRect: TRect;
    function VerticalThumbRect: TRect;
    function HitOnVerticalThumb(X, Y: Integer): Boolean;
    function HitInVerticalTrack(X, Y: Integer): Boolean;
    procedure ScrollByDelta(ADeltaY: Integer);
    procedure ScheduleWheelFlush;
    procedure WheelFlush(Data: PtrInt);
    procedure PaintDocument(ACanvas: TCanvas; const P: TThemePalette);
    procedure PaintCodeBlockLines(ACanvas: TCanvas; const ABlockRect: TRect; APad, ABodySize: Integer;
      const P: TThemePalette; const ACode: string);
    procedure PaintScrollbar(const P: TThemePalette);
    procedure PaintScrollbarTrack(ACanvas: TCanvas; const ARect: TRect; const P: TThemePalette);
    procedure PaintScrollbarThumb(ACanvas: TCanvas; const ARect: TRect; const P: TThemePalette);
    procedure ClearTextSelection;
    procedure BuildSelectionLayout;
    function SelectionBounds(out ALo, AHi: Integer): Boolean;
    function SelectedPlainText: string;
    function ClientPointToPlainIndex(AX, AY: Integer): Integer;
    procedure PaintTextSelection(ACanvas: TCanvas; const P: TThemePalette);
    procedure CopySelectionToClipboard;
    procedure SelectAllText;
    procedure SelectWordAt(AIndex: Integer);
    procedure WMCopy(var Msg: TLMessage); message LM_COPY;
  protected
    procedure DoApplyThemeColors(const P: TThemePalette); override;
    procedure PaintThemedClient(const ARect: TRect; const P: TThemePalette); override;
    procedure Paint; override;
    procedure Loaded; override;
    procedure CreateWnd; override;
    procedure Resize; override;
    procedure ChangeScale(M, D: Integer); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure AppendChunk(const AText: string);
    procedure SetMarkdownText(const AText: string);
    procedure Clear;
    procedure SetMarkdown(const AMarkdown: string; AScrollToEndAfterRender: Boolean = False);
    procedure RequestRender;
  published
    property AutoScrollToEnd: Boolean read FAutoScrollToEnd write SetAutoScrollToEnd default True;
    property Align;
    property Anchors;
    property Left;
    property Top;
    property Width;
    property Height;
    property TabOrder;
    property TabStop;
  end;

implementation

uses
  Math, LCLIntf, StrUtils, Forms, Clipbrd, LcaUiPaintProfile, LcaPaintPrimitives;

type
  TSelectLayoutState = record
    Plain: string;
    Frags: array of TSelectFragRec;
  end;

const
  LCA_MD_PAD_BASE = 8;
  LCA_MD_CODE_PAD_BASE = 8;
  LCA_MD_BULLET_INDENT_BASE = 18;
  LCA_MD_LINE_LEADING_BASE = 4;
  LCA_MD_LINE_EXTRA_BASE = 6;
  LCA_MD_EMPTY_BLOCK_BASE = 6;
  LCA_MD_HRULE_BLOCK_BASE = 16;
  LCA_MD_SCROLL_BOTTOM_EPS = 4;

type
  TMarkdownBlockKind = (
    mbkEmpty, mbkHeading, mbkParagraph, mbkCode, mbkBullet, mbkHRule,
    mbkThinking, mbkTool);

  TChatLabelRole = (clrNone, clrUser, clrAgent, clrTool, clrThinking);

  TInlineStyle = (isNormal, isBold, isItalic, isCode);

  TInlineRun = record
    Text: string;
    Style: TInlineStyle;
  end;

  TInlineRunArray = array of TInlineRun;

  TMarkdownBlockObj = class
  public
    Kind: TMarkdownBlockKind;
    HeadingLevel: Byte;
    ChatLabelRole: TChatLabelRole;
    Runs: array of TInlineRun;
    CodeText: string;
    CalculatedHeight: Integer;
    LayoutTop: Integer;
  end;

procedure AppendInlineRun(var ARuns: TInlineRunArray; const AText: string;
  AStyle: TInlineStyle);
var
  N: Integer;
begin
  if AText = '' then Exit;
  N := Length(ARuns);
  SetLength(ARuns, N + 1);
  ARuns[N].Text := AText;
  ARuns[N].Style := AStyle;
end;

procedure ParseInlineMarkdown(const S: string; out ARuns: TInlineRunArray);
var
  I, N: Integer;
  InBold, InCode, InItalic: Boolean;
  Token: string;
  Style: TInlineStyle;
begin
  SetLength(ARuns, 0);
  I := 1;
  InBold := False;
  InCode := False;
  InItalic := False;
  while I <= Length(S) do begin
    if (I + 1 <= Length(S)) and (S[I] = '*') and (S[I + 1] = '*') then begin
      if InCode then
        AppendInlineRun(ARuns, Copy(S, I, 2), isNormal)
      else
        InBold := not InBold;
      Inc(I, 2);
      Continue;
    end;
    if (not InBold) and (not InCode) and (S[I] = '*') then begin
      InItalic := not InItalic;
      Inc(I);
      Continue;
    end;
    if S[I] = '`' then begin
      if InBold or InItalic then
        AppendInlineRun(ARuns, '`', isNormal)
      else
        InCode := not InCode;
      Inc(I);
      Continue;
    end;
    N := I;
    while (N <= Length(S)) and not (
      ((N + 1 <= Length(S)) and (S[N] = '*') and (S[N + 1] = '*')) or
      (S[N] = '`') or
      ((not InBold) and (not InCode) and (S[N] = '*'))) do
      Inc(N);
    Token := Copy(S, I, N - I);
    if InCode then
      Style := isCode
    else if InBold then
      Style := isBold
    else if InItalic then
      Style := isItalic
    else
      Style := isNormal;
    AppendInlineRun(ARuns, Token, Style);
    I := N;
  end;
end;

function ClassifyChatHeadingRole(const ABody: string): TChatLabelRole;
var
  T: string;
begin
  T := Trim(ABody);
  if SameText(T, 'You') then
    Exit(clrUser);
  if SameText(T, 'Agent') then
    Exit(clrAgent);
  if (Length(T) >= 4) and SameText(Copy(T, 1, 4), 'Tool') then
    Exit(clrTool);
  Result := clrNone;
end;

function ChatLabelTextColor(const P: TThemePalette; ARole: TChatLabelRole): TColor;
begin
  case ARole of
    clrUser: Result := P.ChatLabelUser;
    clrAgent: Result := P.ChatLabelAgent;
    clrTool: Result := P.ChatLabelTool;
    clrThinking: Result := P.ChatLabelThinking;
  else
    Result := P.Text;
  end;
end;

function IsHorizontalRuleLine(const ATrimmed: string): Boolean;
var
  I: Integer;
begin
  if Length(ATrimmed) < 3 then Exit(False);
  for I := 1 to Length(ATrimmed) do
    if ATrimmed[I] <> '-' then
      Exit(False);
  Result := True;
end;

procedure AddBlockParagraph(ABlocks: TObjectList;
  AKind: TMarkdownBlockKind; const ALine: string; AHeadingLevel: Byte = 0);
var
  B: TMarkdownBlockObj;
begin
  B := TMarkdownBlockObj.Create;
  B.Kind := AKind;
  B.HeadingLevel := AHeadingLevel;
  B.ChatLabelRole := clrNone;
  case AKind of
    mbkHeading: B.ChatLabelRole := ClassifyChatHeadingRole(ALine);
    mbkThinking: B.ChatLabelRole := clrThinking;
    mbkTool: B.ChatLabelRole := clrTool;
  end;
  ParseInlineMarkdown(ALine, B.Runs);
  ABlocks.Add(B);
end;

procedure ParseMarkdownSource(const AMarkdown: string; ABlocks: TObjectList);
var
  Lines: TStringList;
  I, Level: Integer;
  Line, Trimmed, Body: string;
  InFence: Boolean;
  InList: Boolean;
  B: TMarkdownBlockObj;
begin
  ABlocks.Clear;
  Lines := TStringList.Create;
  try
    Lines.Text := AMarkdown;
    InFence := False;
    InList := False;
    for I := 0 to Lines.Count - 1 do begin
      Line := Lines[I];
      Trimmed := Trim(Line);
      if InFence then begin
        if Trimmed = '```' then begin
          InFence := False;
        end else if ABlocks.Count > 0 then begin
          B := TMarkdownBlockObj(ABlocks[ABlocks.Count - 1]);
          if B.CodeText <> '' then
            B.CodeText := B.CodeText + LineEnding;
          B.CodeText := B.CodeText + Line;
        end else begin
          B := TMarkdownBlockObj.Create;
          B.Kind := mbkCode;
          B.CodeText := Line;
          ABlocks.Add(B);
        end;
        Continue;
      end;
      if (Length(Trimmed) >= 3) and (Copy(Trimmed, 1, 3) = '```') then begin
        if InList then
          InList := False;
        B := TMarkdownBlockObj.Create;
        B.Kind := mbkCode;
        B.CodeText := '';
        ABlocks.Add(B);
        InFence := True;
        Continue;
      end;
      if Trimmed = '' then begin
        if InList then
          InList := False;
        B := TMarkdownBlockObj.Create;
        B.Kind := mbkEmpty;
        ABlocks.Add(B);
        Continue;
      end;
      if IsHorizontalRuleLine(Trimmed) then begin
        if InList then
          InList := False;
        B := TMarkdownBlockObj.Create;
        B.Kind := mbkHRule;
        ABlocks.Add(B);
        Continue;
      end;
      if (Length(Trimmed) > 0) and (Trimmed[1] = '#') then begin
        if InList then
          InList := False;
        Level := 0;
        while (Level < Length(Trimmed)) and (Trimmed[Level + 1] = '#') do
          Inc(Level);
        if (Level >= 1) and (Level <= 6) and
           ((Level = Length(Trimmed)) or (Trimmed[Level + 1] = ' ')) then begin
          Body := Trim(Copy(Trimmed, Level + 1, MaxInt));
          AddBlockParagraph(ABlocks, mbkHeading, Body, Level);
          Continue;
        end;
      end;
      if (Length(Trimmed) >= 2) and ((Copy(Trimmed, 1, 2) = '- ') or (Copy(Trimmed, 1, 2) = '* ')) then begin
        Body := Trim(Copy(Trimmed, 3, MaxInt));
        AddBlockParagraph(ABlocks, mbkBullet, Body);
        InList := True;
        Continue;
      end;
      if InList then
        InList := False;
      if (Length(Trimmed) > Length('@think ')) and
         (Copy(Trimmed, 1, Length('@think ')) = '@think ') then begin
        Body := Trim(Copy(Trimmed, Length('@think ') + 1, MaxInt));
        AddBlockParagraph(ABlocks, mbkThinking, Body);
        Continue;
      end;
      if (Length(Trimmed) > Length('@tool ')) and
         (Copy(Trimmed, 1, Length('@tool ')) = '@tool ') then begin
        Body := Trim(Copy(Trimmed, Length('@tool ') + 1, MaxInt));
        AddBlockParagraph(ABlocks, mbkTool, '- ' + Body);
        Continue;
      end;
      AddBlockParagraph(ABlocks, mbkParagraph, Trimmed);
    end;
    if InFence and (ABlocks.Count > 0) then
      ; // leave open fence as code block
  finally
    Lines.Free;
  end;
end;

function RunFontStyle(AStyle: TInlineStyle; ABase: TFontStyles): TFontStyles;
begin
  Result := ABase;
  case AStyle of
    isBold: Include(Result, fsBold);
    isItalic: Include(Result, fsItalic);
    isCode: ;
  end;
end;

procedure ConfigureBodyFont(ACanvas: TCanvas; AControl: TControl; ASize: Integer);
begin
  ACanvas.Font.Name := ThemedUiFontName;
  ACanvas.Font.Size := ASize;
  ACanvas.Font.Style := [];
end;

procedure ConfigureMonoFont(ACanvas: TCanvas; AControl: TControl; ASize: Integer);
begin
  ACanvas.Font.Name := ThemedMonospaceFontName;
  ACanvas.Font.Pitch := fpFixed;
  ACanvas.Font.Size := ASize;
end;

function LineHeightForCanvas(ACanvas: TCanvas; AControl: TControl): Integer;
begin
  Result := ACanvas.TextHeight('Ag') +
    ScaledLayoutMetric(AControl, LCA_MD_LINE_LEADING_BASE);
end;

type
  TCanvasFontSnapshot = record
    Name: string;
    Pitch: TFontPitch;
    Size: Integer;
    Style: TFontStyles;
  end;

procedure SaveCanvasFont(ACanvas: TCanvas; out ASnap: TCanvasFontSnapshot);
begin
  ASnap.Name := ACanvas.Font.Name;
  ASnap.Pitch := ACanvas.Font.Pitch;
  ASnap.Size := ACanvas.Font.Size;
  ASnap.Style := ACanvas.Font.Style;
end;

procedure RestoreCanvasFont(ACanvas: TCanvas; const ASnap: TCanvasFontSnapshot);
begin
  ACanvas.Font.Name := ASnap.Name;
  ACanvas.Font.Pitch := ASnap.Pitch;
  ACanvas.Font.Size := ASnap.Size;
  ACanvas.Font.Style := ASnap.Style;
end;

procedure ApplyInlineRunFont(ACanvas: TCanvas; AStyle: TInlineStyle;
  const ABaseStyle: TFontStyles);
begin
  if AStyle = isCode then begin
    ConfigureMonoFont(ACanvas, nil, ACanvas.Font.Size);
    ACanvas.Font.Style := [];
  end else begin
    ACanvas.Font.Name := ThemedUiFontName;
    ACanvas.Font.Pitch := fpDefault;
    ACanvas.Font.Style := RunFontStyle(AStyle, ABaseStyle);
  end;
end;

function MeasureRunSegmentWidth(ACanvas: TCanvas; const AText: string;
  AStyle: TInlineStyle): Integer;
var
  Saved: TCanvasFontSnapshot;
begin
  SaveCanvasFont(ACanvas, Saved);
  ApplyInlineRunFont(ACanvas, AStyle, Saved.Style);
  Result := ACanvas.TextWidth(AText);
  RestoreCanvasFont(ACanvas, Saved);
end;

type
  TWrapMeasureState = record
    LineW: Integer;
    TotalHeight: Integer;
    MaxWidth: Integer;
    LineHeight: Integer;
  end;

  TWrapDrawState = record
    CurX, CurY, LineW: Integer;
    OriginX: Integer;
    MaxWidth, LineHeight: Integer;
  end;

procedure WrapMeasureFinishLine(var S: TWrapMeasureState);
begin
  if S.TotalHeight = 0 then
    S.TotalHeight := S.LineHeight
  else
    S.TotalHeight := S.TotalHeight + S.LineHeight;
  S.LineW := 0;
end;

procedure WrapMeasureEmitWord(ACanvas: TCanvas; var S: TWrapMeasureState;
  const AW: string; AStyle: TInlineStyle);
var
  WW, I, W: Integer;
begin
  if AW = '' then Exit;
  WW := MeasureRunSegmentWidth(ACanvas, AW, AStyle);
  if (S.LineW > 0) and (S.LineW + WW > S.MaxWidth) then
    WrapMeasureFinishLine(S);
  if WW > S.MaxWidth then begin
    for I := 1 to Length(AW) do begin
      W := MeasureRunSegmentWidth(ACanvas, AW[I], AStyle);
      if (S.LineW > 0) and (S.LineW + W > S.MaxWidth) then
        WrapMeasureFinishLine(S);
      S.LineW := S.LineW + W;
    end;
  end else
    S.LineW := S.LineW + WW;
end;

procedure WrapDrawFinishLine(var S: TWrapDrawState);
begin
  S.CurX := S.OriginX;
  S.CurY := S.CurY + S.LineHeight;
  S.LineW := 0;
end;

procedure WrapDrawWord(ACanvas: TCanvas; var S: TWrapDrawState; const AW: string;
  AStyle: TInlineStyle; ATextColor, ACodeBg: TColor);
var
  WW, J, W: Integer;
  Saved: TCanvasFontSnapshot;
  SavedColor: TColor;
  TR: TRect;
begin
  if AW = '' then Exit;
  SaveCanvasFont(ACanvas, Saved);
  SavedColor := ACanvas.Font.Color;
  ApplyInlineRunFont(ACanvas, AStyle, Saved.Style);
  WW := ACanvas.TextWidth(AW);
  if (S.LineW > 0) and (S.CurX + WW - S.OriginX > S.MaxWidth) then
    WrapDrawFinishLine(S);
  if WW > S.MaxWidth then begin
    for J := 1 to Length(AW) do begin
      W := ACanvas.TextWidth(AW[J]);
      if (S.CurX > S.OriginX) and (S.CurX + W - S.OriginX > S.MaxWidth) then
        WrapDrawFinishLine(S);
      if AStyle = isCode then begin
        TR := Rect(S.CurX, S.CurY, S.CurX + W, S.CurY + S.LineHeight);
        ACanvas.Brush.Color := ACodeBg;
        ACanvas.FillRect(TR);
      end;
      ACanvas.Font.Color := ATextColor;
      ACanvas.TextOut(S.CurX, S.CurY, AW[J]);
      S.CurX := S.CurX + W;
      S.LineW := S.CurX - S.OriginX;
    end;
  end else begin
    if AStyle = isCode then begin
      TR := Rect(S.CurX, S.CurY, S.CurX + WW, S.CurY + S.LineHeight);
      ACanvas.Brush.Color := ACodeBg;
      ACanvas.FillRect(TR);
    end;
    ACanvas.Font.Color := ATextColor;
    ACanvas.TextOut(S.CurX, S.CurY, AW);
    S.CurX := S.CurX + WW;
    S.LineW := S.CurX - S.OriginX;
  end;
  RestoreCanvasFont(ACanvas, Saved);
  ACanvas.Font.Color := SavedColor;
end;

function MeasureWrappedRunsHeight(ACanvas: TCanvas; const ARuns: TInlineRunArray;
  AMaxWidth, ALineHeight: Integer; AMono: Boolean): Integer;
var
  R, I, W: Integer;
  Word: string;
  Ch: Char;
  Style: TInlineStyle;
  SavedName: string;
  MS: TWrapMeasureState;
begin
  if AMaxWidth <= 0 then Exit(ALineHeight);
  SavedName := ACanvas.Font.Name;
  if AMono then
    ConfigureMonoFont(ACanvas, nil, ACanvas.Font.Size)
  else
    ACanvas.Font.Name := ThemedUiFontName;
  MS.LineW := 0;
  MS.TotalHeight := 0;
  MS.MaxWidth := AMaxWidth;
  MS.LineHeight := ALineHeight;
  for R := 0 to High(ARuns) do begin
    Word := '';
    Style := ARuns[R].Style;
    for I := 1 to Length(ARuns[R].Text) do begin
      Ch := ARuns[R].Text[I];
      if Ch <= ' ' then begin
        WrapMeasureEmitWord(ACanvas, MS, Word, Style);
        Word := '';
        if (Ch = ' ') and (MS.LineW > 0) then begin
          W := MeasureRunSegmentWidth(ACanvas, ' ', Style);
          if MS.LineW + W > MS.MaxWidth then
            WrapMeasureFinishLine(MS)
          else
            MS.LineW := MS.LineW + W;
        end;
      end else
        Word := Word + Ch;
    end;
    WrapMeasureEmitWord(ACanvas, MS, Word, Style);
  end;
  if (MS.LineW > 0) or (MS.TotalHeight = 0) then
    WrapMeasureFinishLine(MS);
  Result := MS.TotalHeight;
  ACanvas.Font.Name := SavedName;
end;

function MeasureCodeBlockHeight(ACanvas: TCanvas; const ACode: string; AMaxWidth: Integer;
  APad, ALineHeight: Integer): Integer;
var
  Lines: TStringList;
  I, LineW, MaxLineW: Integer;
begin
  Lines := TStringList.Create;
  try
    if ACode = '' then
      Lines.Add('')
    else
      Lines.Text := ACode;
    MaxLineW := 0;
    for I := 0 to Lines.Count - 1 do begin
      LineW := ACanvas.TextWidth(Lines[I]);
      if LineW > MaxLineW then
        MaxLineW := LineW;
    end;
    if MaxLineW > AMaxWidth then
      Result := ALineHeight * Lines.Count
    else
      Result := ALineHeight * Max(1, Lines.Count);
    Result := Result + 2 * APad;
  finally
    Lines.Free;
  end;
end;

procedure DrawWrappedRuns(ACanvas: TCanvas; const ARuns: TInlineRunArray;
  X, Y, AMaxWidth, ALineHeight: Integer; ATextColor, ACodeBg: TColor; AMono: Boolean);
var
  R, I, W: Integer;
  Word: string;
  Ch: Char;
  Style: TInlineStyle;
  Saved: TCanvasFontSnapshot;
  SpaceSnap: TCanvasFontSnapshot;
  DS: TWrapDrawState;
begin
  SaveCanvasFont(ACanvas, Saved);
  if AMono then
    ConfigureMonoFont(ACanvas, nil, ACanvas.Font.Size)
  else
    ACanvas.Font.Name := ThemedUiFontName;
  DS.OriginX := X;
  DS.MaxWidth := AMaxWidth;
  DS.LineHeight := ALineHeight;
  DS.CurX := X;
  DS.CurY := Y;
  DS.LineW := 0;
  for R := 0 to High(ARuns) do begin
    Word := '';
    Style := ARuns[R].Style;
    for I := 1 to Length(ARuns[R].Text) do begin
      Ch := ARuns[R].Text[I];
      if Ch <= ' ' then begin
        WrapDrawWord(ACanvas, DS, Word, Style, ATextColor, ACodeBg);
        Word := '';
        if (Ch = ' ') and (DS.LineW > 0) then begin
          W := MeasureRunSegmentWidth(ACanvas, ' ', Style);
          if DS.CurX + W - X > AMaxWidth then
            WrapDrawFinishLine(DS)
          else begin
            SaveCanvasFont(ACanvas, SpaceSnap);
            ApplyInlineRunFont(ACanvas, Style, SpaceSnap.Style);
            ACanvas.Font.Color := ATextColor;
            ACanvas.TextOut(DS.CurX, DS.CurY, ' ');
            RestoreCanvasFont(ACanvas, SpaceSnap);
            DS.CurX := DS.CurX + W;
          end;
        end;
      end else
        Word := Word + Ch;
    end;
    WrapDrawWord(ACanvas, DS, Word, Style, ATextColor, ACodeBg);
  end;
  RestoreCanvasFont(ACanvas, Saved);
end;

procedure LayoutAppendFragment(var L: TSelectLayoutState; const ARect: TRect;
  const AText: string);
var
  N: Integer;
begin
  if AText = '' then Exit;
  N := Length(L.Frags);
  SetLength(L.Frags, N + 1);
  L.Frags[N].StartIdx := Length(L.Plain);
  L.Frags[N].Text := AText;
  L.Frags[N].DocRect := ARect;
  L.Plain := L.Plain + AText;
end;

procedure LayoutAppendNewline(var L: TSelectLayoutState);
begin
  if (L.Plain <> '') and (L.Plain[Length(L.Plain)] <> #10) then
    L.Plain := L.Plain + LineEnding;
end;

procedure LayoutWrapFinishLine(var S: TWrapDrawState);
begin
  S.CurX := S.OriginX;
  S.CurY := S.CurY + S.LineHeight;
  S.LineW := 0;
end;

procedure LayoutWrapWord(ACanvas: TCanvas; var L: TSelectLayoutState; var S: TWrapDrawState;
  const AW: string; AStyle: TInlineStyle);
var
  WW, J, W: Integer;
  Saved: TCanvasFontSnapshot;
  R: TRect;
begin
  if AW = '' then Exit;
  SaveCanvasFont(ACanvas, Saved);
  ApplyInlineRunFont(ACanvas, AStyle, Saved.Style);
  WW := ACanvas.TextWidth(AW);
  if (S.LineW > 0) and (S.CurX + WW - S.OriginX > S.MaxWidth) then
    LayoutWrapFinishLine(S);
  if WW > S.MaxWidth then begin
    for J := 1 to Length(AW) do begin
      W := ACanvas.TextWidth(AW[J]);
      if (S.CurX > S.OriginX) and (S.CurX + W - S.OriginX > S.MaxWidth) then
        LayoutWrapFinishLine(S);
      R := Rect(S.CurX, S.CurY, S.CurX + W, S.CurY + S.LineHeight);
      LayoutAppendFragment(L, R, AW[J]);
      S.CurX := S.CurX + W;
      S.LineW := S.CurX - S.OriginX;
    end;
  end else begin
    R := Rect(S.CurX, S.CurY, S.CurX + WW, S.CurY + S.LineHeight);
    LayoutAppendFragment(L, R, AW);
    S.CurX := S.CurX + WW;
    S.LineW := S.CurX - S.OriginX;
  end;
  RestoreCanvasFont(ACanvas, Saved);
end;

procedure LayoutWrappedRuns(ACanvas: TCanvas; var L: TSelectLayoutState;
  const ARuns: TInlineRunArray; X, Y, AMaxWidth, ALineHeight: Integer; AMono: Boolean);
var
  RunIdx, I, W: Integer;
  Word: string;
  Ch: Char;
  Style: TInlineStyle;
  Saved: TCanvasFontSnapshot;
  DS: TWrapDrawState;
  FragR: TRect;
begin
  SaveCanvasFont(ACanvas, Saved);
  if AMono then
    ConfigureMonoFont(ACanvas, nil, ACanvas.Font.Size)
  else
    ACanvas.Font.Name := ThemedUiFontName;
  DS.OriginX := X;
  DS.MaxWidth := AMaxWidth;
  DS.LineHeight := ALineHeight;
  DS.CurX := X;
  DS.CurY := Y;
  DS.LineW := 0;
  for RunIdx := 0 to High(ARuns) do begin
    Word := '';
    Style := ARuns[RunIdx].Style;
    for I := 1 to Length(ARuns[RunIdx].Text) do begin
      Ch := ARuns[RunIdx].Text[I];
      if Ch <= ' ' then begin
        LayoutWrapWord(ACanvas, L, DS, Word, Style);
        Word := '';
        if (Ch = ' ') and (DS.LineW > 0) then begin
          W := MeasureRunSegmentWidth(ACanvas, ' ', Style);
          if DS.CurX + W - X > AMaxWidth then
            LayoutWrapFinishLine(DS)
          else begin
            FragR := Rect(DS.CurX, DS.CurY, DS.CurX + W, DS.CurY + DS.LineHeight);
            LayoutAppendFragment(L, FragR, ' ');
            DS.CurX := DS.CurX + W;
          end;
        end;
      end else
        Word := Word + Ch;
    end;
    LayoutWrapWord(ACanvas, L, DS, Word, Style);
  end;
  RestoreCanvasFont(ACanvas, Saved);
end;

procedure LayoutCodeBlockLines(ACanvas: TCanvas; var L: TSelectLayoutState;
  const ABlockRect: TRect; APad, ABodySize: Integer; const ACode: string);
var
  Lines: TStringList;
  I, LineH, LineY, LineW: Integer;
  R: TRect;
begin
  ConfigureMonoFont(ACanvas, nil, ABodySize);
  LineH := LineHeightForCanvas(ACanvas, nil);
  Lines := TStringList.Create;
  try
    if ACode = '' then
      Lines.Add('')
    else
      Lines.Text := ACode;
    LineY := ABlockRect.Top + APad;
    for I := 0 to Lines.Count - 1 do begin
      LineW := ACanvas.TextWidth(Lines[I]);
      if LineW = 0 then
        LineW := ACanvas.TextWidth(' ');
      R := Rect(ABlockRect.Left + APad, LineY, ABlockRect.Left + APad + LineW,
        LineY + LineH);
      LayoutAppendFragment(L, R, Lines[I]);
      LineY := LineY + LineH;
    end;
  finally
    Lines.Free;
  end;
end;

{ TLcaMarkdownView }

procedure TLcaMarkdownView.SetAutoScrollToEnd(AValue: Boolean);
begin
  if FAutoScrollToEnd = AValue then Exit;
  FAutoScrollToEnd := AValue;
  if FAutoScrollToEnd and FStickToBottom then
    ScrollToEnd;
end;

constructor TLcaMarkdownView.Create(AOwner: TComponent);
begin
  { Before inherited: theme/apply may Invalidate and Paint — FBlocks must exist. }
  FBlocks := TObjectList.Create(True);
  FSource := '';
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csCaptureMouse, csClickEvents, csDoubleClicks];
  TabStop := True;
  FAutoScrollToEnd := True;
  FStickToBottom := True;
  FScrollY := 0;
  FPlainText := '';
  FSelAnchor := 0;
  FSelCaret := 0;
  FSelActive := False;
  FTextSelDrag := False;
end;

destructor TLcaMarkdownView.Destroy;
begin
  FreeAndNil(FBlocks);
  inherited Destroy;
end;

procedure TLcaMarkdownView.DoApplyThemeColors(const P: TThemePalette);
begin
  Color := P.Background;
  Font.Color := P.Text;
end;

procedure TLcaMarkdownView.PaintThemedClient(const ARect: TRect; const P: TThemePalette);
begin
  Canvas.Brush.Color := P.Background;
  Canvas.FillRect(ARect);
end;

function TLcaMarkdownView.ContentPad: Integer;
begin
  Result := ScaledLayoutMetric(Self, LCA_MD_PAD_BASE);
end;

function TLcaMarkdownView.ScrollbarThickness: Integer;
begin
  Result := ScaledThemedScrollbarThickness(Self);
end;

function TLcaMarkdownView.TextAreaWidth: Integer;
var
  W: Integer;
begin
  W := ClientWidth - 2 * ContentPad;
  if FShowVBar then
    Dec(W, ScrollbarThickness);
  if W < 1 then
    W := 1;
  Result := W;
end;

function TLcaMarkdownView.MaxScrollY: Integer;
begin
  Result := Max(0, FContentHeight - ClientHeight);
end;

procedure TLcaMarkdownView.ClampScroll;
begin
  if FScrollY < 0 then FScrollY := 0;
  if FScrollY > MaxScrollY then FScrollY := MaxScrollY;
end;

procedure TLcaMarkdownView.UpdateStickToBottomFromScroll;
begin
  if MaxScrollY <= 0 then begin
    FStickToBottom := True;
    Exit;
  end;
  if FScrollY >= MaxScrollY - LCA_MD_SCROLL_BOTTOM_EPS then
    FStickToBottom := True
  else
    FStickToBottom := False;
end;

procedure TLcaMarkdownView.ScrollToEnd;
begin
  FScrollY := MaxScrollY;
  ClampScroll;
end;

procedure TLcaMarkdownView.ApplyScrollPolicy(AForceStick: Boolean);
begin
  if AForceStick then
    FStickToBottom := True;
  if FAutoScrollToEnd and FStickToBottom then
    ScrollToEnd;
end;

procedure TLcaMarkdownView.RebuildBlocksFromSource;
var
  NewBlocks: TObjectList;
begin
  NewBlocks := TObjectList.Create(True);
  ParseMarkdownSource(FSource, NewBlocks);
  FreeAndNil(FBlocks);
  FBlocks := NewBlocks;
end;

procedure TLcaMarkdownView.RelayoutDocument;
var
  Pass, Y, BodySize, LineH, CodePad, W, BulletInd: Integer;
  OldScroll: Integer;

  procedure MeasureAllBlockHeights;
  var
    Idx: Integer;
    Blk: TMarkdownBlockObj;
    BlockLineH: Integer;
  begin
    ConfigureBodyFont(Canvas, Self, BodySize);
    LineH := LineHeightForCanvas(Canvas, Self);
    Y := ContentPad;
    for Idx := 0 to FBlocks.Count - 1 do begin
      Blk := TMarkdownBlockObj(FBlocks[Idx]);
      if Blk = nil then Continue;
      case Blk.Kind of
        mbkEmpty:
          Blk.CalculatedHeight := ScaledLayoutMetric(Self, LCA_MD_EMPTY_BLOCK_BASE);
        mbkHRule:
          Blk.CalculatedHeight := ScaledLayoutMetric(Self, LCA_MD_HRULE_BLOCK_BASE);
        mbkCode:
          begin
            ConfigureMonoFont(Canvas, Self, BodySize);
            Blk.CalculatedHeight := MeasureCodeBlockHeight(Canvas, Blk.CodeText, W - 2 * CodePad,
              CodePad, LineHeightForCanvas(Canvas, Self));
            ConfigureBodyFont(Canvas, Self, BodySize);
          end;
        mbkHeading:
          begin
            Canvas.Font.Style := [fsBold];
            Canvas.Font.Size := BodySize + Max(0, 4 - Blk.HeadingLevel);
            Blk.CalculatedHeight := MeasureWrappedRunsHeight(Canvas, Blk.Runs, W,
              LineHeightForCanvas(Canvas, Self), False);
            ConfigureBodyFont(Canvas, Self, BodySize);
          end;
        mbkBullet:
          Blk.CalculatedHeight := MeasureWrappedRunsHeight(Canvas, Blk.Runs,
            W - BulletInd, LineH, False);
        mbkThinking:
          begin
            Canvas.Font.Style := [fsItalic];
            Blk.CalculatedHeight := MeasureWrappedRunsHeight(Canvas, Blk.Runs, W, LineH, False);
            ConfigureBodyFont(Canvas, Self, BodySize);
          end;
        mbkTool:
          begin
            Canvas.Font.Size := Max(8, BodySize - 1);
            BlockLineH := LineHeightForCanvas(Canvas, Self);
            Blk.CalculatedHeight := MeasureWrappedRunsHeight(Canvas, Blk.Runs, W,
              BlockLineH, False);
            ConfigureBodyFont(Canvas, Self, BodySize);
          end;
        mbkParagraph:
          Blk.CalculatedHeight := MeasureWrappedRunsHeight(Canvas, Blk.Runs, W, LineH, False);
      end;
      Blk.LayoutTop := Y;
      Y := Y + Blk.CalculatedHeight + ScaledLayoutMetric(Self, LCA_MD_LINE_EXTRA_BASE);
    end;
    FContentHeight := Y + ContentPad;
  end;

begin
  if not Assigned(FBlocks) or FLayoutGuard then Exit;
  if not HandleAllocated then begin
    FNeedsLayout := True;
    Exit;
  end;
  FLayoutGuard := True;
  FNeedsLayout := False;
  LcaUiProfileRecordMarkdownGetContentSize;
  OldScroll := FScrollY;
  BodySize := ThemedMarkdownBodyFontSize(Self);
  CodePad := ScaledLayoutMetric(Self, LCA_MD_CODE_PAD_BASE);
  BulletInd := ScaledLayoutMetric(Self, LCA_MD_BULLET_INDENT_BASE);
  FShowVBar := False;
  for Pass := 0 to 1 do begin
    W := TextAreaWidth;
    FLayoutTextWidth := W;
    MeasureAllBlockHeights;
    if FContentHeight <= ClientHeight then begin
      FShowVBar := False;
      Break;
    end;
    FShowVBar := True;
    if Pass = 1 then
      Break;
  end;
  ClampScroll;
  if (OldScroll <> FScrollY) and not (FAutoScrollToEnd and FStickToBottom) then
    ; // keep user scroll
  UpdateStickToBottomFromScroll;
  BuildSelectionLayout;
  FLayoutGuard := False;
end;

procedure TLcaMarkdownView.ClearTextSelection;
begin
  FSelAnchor := 0;
  FSelCaret := 0;
  FSelActive := False;
  FTextSelDrag := False;
end;

procedure TLcaMarkdownView.BuildSelectionLayout;
var
  L: TSelectLayoutState;
  I, X, Y, W, BodySize, LineH, CodePad, BulletInd: Integer;
  B: TMarkdownBlockObj;
  BlockRect: TRect;
  BulletR: TRect;
begin
  L.Plain := '';
  SetLength(L.Frags, 0);
  if not Assigned(FBlocks) or not HandleAllocated then begin
    FPlainText := '';
    SetLength(FSelectFrags, 0);
    Exit;
  end;
  BodySize := ThemedMarkdownBodyFontSize(Self);
  ConfigureBodyFont(Canvas, Self, BodySize);
  LineH := LineHeightForCanvas(Canvas, Self);
  CodePad := ScaledLayoutMetric(Self, LCA_MD_CODE_PAD_BASE);
  BulletInd := ScaledLayoutMetric(Self, LCA_MD_BULLET_INDENT_BASE);
  W := TextAreaWidth;
  X := ContentPad;
  for I := 0 to FBlocks.Count - 1 do begin
    B := TMarkdownBlockObj(FBlocks[I]);
    if B = nil then Continue;
    Y := B.LayoutTop;
    case B.Kind of
      mbkEmpty, mbkHRule:
        Continue;
      mbkCode:
        begin
          BlockRect := Rect(X, Y, X + W, Y + B.CalculatedHeight);
          LayoutCodeBlockLines(Canvas, L, BlockRect, CodePad, BodySize, B.CodeText);
          LayoutAppendNewline(L);
        end;
      mbkHeading:
        begin
          Canvas.Font.Style := [fsBold];
          Canvas.Font.Size := BodySize + Max(0, 4 - B.HeadingLevel);
          LayoutWrappedRuns(Canvas, L, B.Runs, X, Y, W, LineHeightForCanvas(Canvas, Self), False);
          ConfigureBodyFont(Canvas, Self, BodySize);
          LayoutAppendNewline(L);
        end;
      mbkBullet:
        begin
          BulletR := Rect(X, Y, X + Canvas.TextWidth(#8226), Y + LineH);
          LayoutAppendFragment(L, BulletR, #8226);
          LayoutWrappedRuns(Canvas, L, B.Runs, X + BulletInd, Y, W - BulletInd, LineH, False);
          LayoutAppendNewline(L);
        end;
      mbkThinking:
        begin
          Canvas.Font.Style := [fsItalic];
          LayoutWrappedRuns(Canvas, L, B.Runs, X, Y, W, LineH, False);
          ConfigureBodyFont(Canvas, Self, BodySize);
          LayoutAppendNewline(L);
        end;
      mbkTool:
        begin
          Canvas.Font.Size := Max(8, BodySize - 1);
          LayoutWrappedRuns(Canvas, L, B.Runs, X, Y, W, LineH, False);
          ConfigureBodyFont(Canvas, Self, BodySize);
          LayoutAppendNewline(L);
        end;
      mbkParagraph:
        begin
          LayoutWrappedRuns(Canvas, L, B.Runs, X, Y, W, LineH, False);
          LayoutAppendNewline(L);
        end;
    end;
  end;
  FPlainText := L.Plain;
  FSelectFrags := L.Frags;
  if FSelActive then begin
    if FSelAnchor > Length(FPlainText) then
      ClearTextSelection
    else if FSelCaret > Length(FPlainText) then
      FSelCaret := Length(FPlainText);
  end;
end;

function TLcaMarkdownView.SelectionBounds(out ALo, AHi: Integer): Boolean;
begin
  if not FSelActive then
    Exit(False);
  ALo := FSelAnchor;
  AHi := FSelCaret;
  if ALo > AHi then begin
    ALo := FSelCaret;
    AHi := FSelAnchor;
  end;
  Result := True;
end;

function TLcaMarkdownView.SelectedPlainText: string;
var
  Lo, Hi: Integer;
begin
  if not SelectionBounds(Lo, Hi) or (Lo >= Hi) then
    Exit('');
  Result := Copy(FPlainText, Lo + 1, Hi - Lo);
end;

function TLcaMarkdownView.ClientPointToPlainIndex(AX, AY: Integer): Integer;
var
  DocX, DocY, I, J, Lo, Hi, Mid, W: Integer;
  F: TSelectFragRec;
  BestDist, Dist, DY: Integer;
  BestIdx: Integer;
begin
  if Length(FSelectFrags) = 0 then
    Exit(0);
  DocX := AX;
  DocY := AY + FScrollY;
  BestIdx := 0;
  BestDist := MaxInt;
  for I := 0 to High(FSelectFrags) do begin
    F := FSelectFrags[I];
    if PtInRect(F.DocRect, Point(DocX, DocY)) then begin
      if Length(F.Text) = 1 then
        Exit(F.StartIdx);
      Lo := 1;
      Hi := Length(F.Text);
      while Lo < Hi do begin
        Mid := (Lo + Hi) div 2;
        W := Canvas.TextWidth(Copy(F.Text, 1, Mid));
        if DocX < F.DocRect.Left + W then
          Hi := Mid
        else
          Lo := Mid + 1;
      end;
      J := Lo;
      if J > Length(F.Text) then
        J := Length(F.Text);
      Exit(F.StartIdx + J - 1);
    end;
    DY := DocY - ((F.DocRect.Top + F.DocRect.Bottom) div 2);
    Dist := Abs(DY) * 1000 + Abs(DocX - ((F.DocRect.Left + F.DocRect.Right) div 2));
    if Dist < BestDist then begin
      BestDist := Dist;
      if DocX <= F.DocRect.Left then
        BestIdx := F.StartIdx
      else if DocX >= F.DocRect.Right then
        BestIdx := F.StartIdx + Length(F.Text)
      else
        BestIdx := F.StartIdx + Length(F.Text) div 2;
    end;
  end;
  if BestIdx < 0 then
    BestIdx := 0;
  if BestIdx > Length(FPlainText) then
    BestIdx := Length(FPlainText);
  Result := BestIdx;
end;

procedure TLcaMarkdownView.PaintTextSelection(ACanvas: TCanvas; const P: TThemePalette);
var
  Lo, Hi, I, SelStartInFrag, SelEndInFrag, LeftW, RightW: Integer;
  F: TSelectFragRec;
  R: TRect;
begin
  if not SelectionBounds(Lo, Hi) or (Lo >= Hi) then Exit;
  ACanvas.Brush.Color := P.AccentActive;
  ACanvas.Pen.Style := psClear;
  for I := 0 to High(FSelectFrags) do begin
    F := FSelectFrags[I];
    if (F.StartIdx + Length(F.Text) <= Lo) or (F.StartIdx >= Hi) then Continue;
    SelStartInFrag := Max(0, Lo - F.StartIdx);
    SelEndInFrag := Min(Length(F.Text), Hi - F.StartIdx);
    if SelStartInFrag >= SelEndInFrag then Continue;
    LeftW := 0;
    if SelStartInFrag > 0 then
      LeftW := ACanvas.TextWidth(Copy(F.Text, 1, SelStartInFrag));
    RightW := ACanvas.TextWidth(Copy(F.Text, 1, SelEndInFrag));
    R := F.DocRect;
    R.Left := R.Left + LeftW;
    R.Right := F.DocRect.Left + RightW;
    Dec(R.Top, FScrollY);
    Dec(R.Bottom, FScrollY);
    ACanvas.FillRect(R);
  end;
  ACanvas.Pen.Style := psSolid;
end;

procedure TLcaMarkdownView.CopySelectionToClipboard;
var
  S: string;
begin
  S := SelectedPlainText;
  if S = '' then Exit;
  Clipboard.AsText := S;
end;

procedure TLcaMarkdownView.SelectAllText;
begin
  FSelAnchor := 0;
  FSelCaret := Length(FPlainText);
  FSelActive := FSelCaret > 0;
  Invalidate;
end;

procedure TLcaMarkdownView.SelectWordAt(AIndex: Integer);
var
  Lo, Hi: Integer;
begin
  if FPlainText = '' then Exit;
  if AIndex < 0 then AIndex := 0;
  if AIndex > Length(FPlainText) then AIndex := Length(FPlainText);
  Lo := AIndex + 1;
  Hi := AIndex + 1;
  while (Lo > 1) and (FPlainText[Lo - 1] > ' ') and (FPlainText[Lo - 1] <> #10) do
    Dec(Lo);
  while (Hi <= Length(FPlainText)) and (FPlainText[Hi] > ' ') and (FPlainText[Hi] <> #10) do
    Inc(Hi);
  FSelAnchor := Lo - 1;
  FSelCaret := Hi - 1;
  FSelActive := FSelCaret > FSelAnchor;
  Invalidate;
end;

procedure TLcaMarkdownView.WMCopy(var Msg: TLMessage);
begin
  CopySelectionToClipboard;
  Msg.Result := 1;
end;

procedure TLcaMarkdownView.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  if (Key = Ord('C')) and (ssCtrl in Shift) then begin
    CopySelectionToClipboard;
    Key := 0;
  end else if (Key = Ord('A')) and (ssCtrl in Shift) then begin
    SelectAllText;
    Key := 0;
  end;
end;

procedure TLcaMarkdownView.Clear;
var
  Empty: TObjectList;
begin
  FSource := '';
  Empty := TObjectList.Create(True);
  FreeAndNil(FBlocks);
  FBlocks := Empty;
  FContentHeight := ContentPad * 2;
  FScrollY := 0;
  FStickToBottom := True;
  FNeedsLayout := False;
  ClearTextSelection;
  Invalidate;
end;

procedure TLcaMarkdownView.SetMarkdownText(const AText: string);
begin
  ClearTextSelection;
  FSource := AText;
  RebuildBlocksFromSource;
  RelayoutDocument;
  ApplyScrollPolicy(False);
  Invalidate;
  LcaUiProfileRecordMarkdownRender;
end;

procedure TLcaMarkdownView.AppendChunk(const AText: string);
begin
  if AText = '' then Exit;
  ClearTextSelection;
  FSource := FSource + AText;
  RebuildBlocksFromSource;
  RelayoutDocument;
  ApplyScrollPolicy(False);
  Invalidate;
  LcaUiProfileRecordMarkdownRender;
end;

procedure TLcaMarkdownView.SetMarkdown(const AMarkdown: string; AScrollToEndAfterRender: Boolean);
begin
  SetMarkdownText(AMarkdown);
  if AScrollToEndAfterRender then
    ApplyScrollPolicy(True);
end;

procedure TLcaMarkdownView.RequestRender;
begin
  RelayoutDocument;
  Invalidate;
end;

function TLcaMarkdownView.VerticalTrackRect: TRect;
var
  BarW: Integer;
begin
  BarW := ScrollbarThickness;
  Result := Rect(ClientWidth - BarW, 0, ClientWidth, ClientHeight);
end;

function TLcaMarkdownView.VerticalThumbRect: TRect;
var
  TrackR: TRect;
  ThumbH, ThumbY, MinThumb, MaxS, ViewH: Integer;
begin
  TrackR := VerticalTrackRect;
  Result := TrackR;
  if not FShowVBar then Exit;
  MaxS := MaxScrollY;
  if MaxS <= 0 then Exit;
  ViewH := ClientHeight;
  MinThumb := Max(ScrollbarThickness, ScaledLayoutMetric(Self, 20));
  ThumbH := Max(MinThumb, MulDiv(TrackR.Height, ViewH, FContentHeight));
  if ThumbH > TrackR.Height then
    ThumbH := TrackR.Height;
  ThumbY := TrackR.Top;
  if TrackR.Height > ThumbH then
    ThumbY := TrackR.Top + MulDiv(TrackR.Height - ThumbH, FScrollY, MaxS);
  Result := Rect(TrackR.Left + 2, ThumbY, TrackR.Right - 1, ThumbY + ThumbH);
end;

function TLcaMarkdownView.HitOnVerticalThumb(X, Y: Integer): Boolean;
begin
  if not FShowVBar then Exit(False);
  Result := PtInRect(VerticalThumbRect, Point(X, Y));
end;

function TLcaMarkdownView.HitInVerticalTrack(X, Y: Integer): Boolean;
begin
  if not FShowVBar then Exit(False);
  Result := PtInRect(VerticalTrackRect, Point(X, Y));
end;

procedure TLcaMarkdownView.ScrollByDelta(ADeltaY: Integer);
begin
  if ADeltaY = 0 then Exit;
  FScrollY := FScrollY + ADeltaY;
  ClampScroll;
  UpdateStickToBottomFromScroll;
  Invalidate;
end;

procedure TLcaMarkdownView.ScheduleWheelFlush;
begin
  if FWheelFlushQueued then Exit;
  FWheelFlushQueued := True;
  Application.QueueAsyncCall(@WheelFlush, PtrInt(Self));
end;

procedure TLcaMarkdownView.WheelFlush(Data: PtrInt);
var
  Delta: Integer;
begin
  FWheelFlushQueued := False;
  if PtrInt(Self) <> Data then Exit;
  Delta := FWheelAccumY;
  FWheelAccumY := 0;
  if Delta <> 0 then
    ScrollByDelta(-Delta);
end;

procedure TLcaMarkdownView.PaintScrollbarTrack(ACanvas: TCanvas; const ARect: TRect;
  const P: TThemePalette);
begin
  PaintThemedScrollbarTrack(ACanvas, ARect, P.SurfaceAlt);
end;

procedure TLcaMarkdownView.PaintScrollbarThumb(ACanvas: TCanvas; const ARect: TRect;
  const P: TThemePalette);
var
  ThumbColor: TColor;
begin
  ThumbColor := BlendRgb(P.Border, P.TextMuted, 0.35);
  PaintThemedScrollbarThumb(ACanvas, ARect, ThumbColor, False);
end;

procedure TLcaMarkdownView.PaintScrollbar(const P: TThemePalette);
var
  TrackR, ThumbR: TRect;
begin
  if not FShowVBar then Exit;
  TrackR := VerticalTrackRect;
  PaintScrollbarTrack(Canvas, TrackR, P);
  ThumbR := VerticalThumbRect;
  if (ThumbR.Right > ThumbR.Left) and (ThumbR.Bottom > ThumbR.Top) then
    PaintScrollbarThumb(Canvas, ThumbR, P);
end;

procedure TLcaMarkdownView.PaintCodeBlockLines(ACanvas: TCanvas; const ABlockRect: TRect;
  APad, ABodySize: Integer; const P: TThemePalette; const ACode: string);
var
  Lines: TStringList;
  I, LineY, LineH: Integer;
  ClipR: TRect;
  SavedClip: TRect;
begin
  ConfigureMonoFont(ACanvas, Self, ABodySize);
  ACanvas.Font.Color := P.Text;
  LineH := LineHeightForCanvas(ACanvas, Self);
  ClipR := Rect(ABlockRect.Left + APad, ABlockRect.Top + APad,
    ABlockRect.Right - APad, ABlockRect.Bottom - APad);
  SavedClip := ACanvas.ClipRect;
  ACanvas.ClipRect := ClipR;
  Lines := TStringList.Create;
  try
    if ACode = '' then
      Lines.Add('')
    else
      Lines.Text := ACode;
    LineY := ClipR.Top;
    for I := 0 to Lines.Count - 1 do begin
      if LineY + LineH > ClipR.Bottom then
        Break;
      ACanvas.TextOut(ClipR.Left, LineY, Lines[I]);
      LineY := LineY + LineH;
    end;
  finally
    Lines.Free;
    ACanvas.ClipRect := SavedClip;
  end;
end;

procedure TLcaMarkdownView.PaintDocument(ACanvas: TCanvas; const P: TThemePalette);
var
  I, X, Y, W, BodySize, LineH, CodePad, BulletInd: Integer;
  B: TMarkdownBlockObj;
  ViewTop, ViewBottom: Integer;
  BlockRect: TRect;
  TextColor: TColor;
  SavedClip: TRect;
begin
  if not Assigned(FBlocks) then Exit;
  BodySize := ThemedMarkdownBodyFontSize(Self);
  ConfigureBodyFont(ACanvas, Self, BodySize);
  LineH := LineHeightForCanvas(ACanvas, Self);
  CodePad := ScaledLayoutMetric(Self, LCA_MD_CODE_PAD_BASE);
  BulletInd := ScaledLayoutMetric(Self, LCA_MD_BULLET_INDENT_BASE);
  W := TextAreaWidth;
  X := ContentPad;
  ViewTop := FScrollY;
  ViewBottom := FScrollY + ClientHeight;
  SavedClip := ACanvas.ClipRect;
  ACanvas.ClipRect := ClientRect;
  PaintTextSelection(ACanvas, P);
  for I := 0 to FBlocks.Count - 1 do begin
    B := TMarkdownBlockObj(FBlocks[I]);
    if B = nil then Continue;
    if (B.LayoutTop + B.CalculatedHeight < ViewTop) or (B.LayoutTop > ViewBottom) then
      Continue;
    Y := B.LayoutTop - FScrollY;
    case B.Kind of
      mbkEmpty:
        Continue;
      mbkHRule:
        begin
          ACanvas.Pen.Color := P.Border;
          BlockRect := Rect(X, Y + B.CalculatedHeight div 2,
            X + W, Y + B.CalculatedHeight div 2 + 1);
          ACanvas.MoveTo(BlockRect.Left, BlockRect.Top);
          ACanvas.LineTo(BlockRect.Right, BlockRect.Top);
        end;
      mbkCode:
        begin
          BlockRect := Rect(X, Y, X + W, Y + B.CalculatedHeight);
          ACanvas.Brush.Color := P.SurfaceAlt;
          ACanvas.FillRect(BlockRect);
          ACanvas.Pen.Color := P.Border;
          ACanvas.Rectangle(BlockRect);
          PaintCodeBlockLines(ACanvas, BlockRect, CodePad, BodySize, P, B.CodeText);
        end;
      mbkHeading:
        begin
          TextColor := ChatLabelTextColor(P, B.ChatLabelRole);
          ACanvas.Font.Style := [fsBold];
          ACanvas.Font.Size := BodySize + Max(0, 4 - B.HeadingLevel);
          ACanvas.Font.Color := TextColor;
          DrawWrappedRuns(ACanvas, B.Runs, X, Y, W, LineHeightForCanvas(ACanvas, Self), TextColor,
            P.SurfaceAlt, False);
          ConfigureBodyFont(ACanvas, Self, BodySize);
        end;
      mbkBullet:
        begin
          TextColor := P.Text;
          ACanvas.Font.Color := TextColor;
          ACanvas.TextOut(X, Y, #8226);
          DrawWrappedRuns(ACanvas, B.Runs, X + BulletInd, Y, W - BulletInd, LineH,
            TextColor, P.SurfaceAlt, False);
        end;
      mbkThinking:
        begin
          TextColor := ChatLabelTextColor(P, B.ChatLabelRole);
          ACanvas.Font.Style := [fsItalic];
          ACanvas.Font.Color := TextColor;
          DrawWrappedRuns(ACanvas, B.Runs, X, Y, W, LineH, TextColor, P.SurfaceAlt, False);
          ConfigureBodyFont(ACanvas, Self, BodySize);
        end;
      mbkTool:
        begin
          TextColor := ChatLabelTextColor(P, B.ChatLabelRole);
          ACanvas.Font.Size := Max(8, BodySize - 1);
          ACanvas.Font.Color := TextColor;
          DrawWrappedRuns(ACanvas, B.Runs, X, Y, W, LineH, TextColor, P.SurfaceAlt, False);
          ConfigureBodyFont(ACanvas, Self, BodySize);
        end;
      mbkParagraph:
        begin
          TextColor := P.Text;
          ACanvas.Font.Color := TextColor;
          DrawWrappedRuns(ACanvas, B.Runs, X, Y, W, LineH, TextColor, P.SurfaceAlt, False);
        end;
    end;
  end;
  ACanvas.ClipRect := SavedClip;
end;

procedure TLcaMarkdownView.CreateWnd;
begin
  inherited CreateWnd;
  if FNeedsLayout or (FSource <> '') then
    RelayoutDocument;
end;

procedure TLcaMarkdownView.Loaded;
begin
  inherited Loaded;
  if FNeedsLayout or (FSource <> '') then begin
    RelayoutDocument;
    Invalidate;
  end;
end;

procedure TLcaMarkdownView.Paint;
var
  P: TThemePalette;
  T0, Elapsed: QWord;
begin
  T0 := GetTickCount64;
  P := EffectivePalette;
  PaintThemedClient(ClientRect, P);
  if LcaInDesignContext(Self) and (csDesigning in ComponentState) then begin
    Canvas.Font.Color := P.TextMuted;
    Canvas.Brush.Style := bsClear;
    Canvas.TextOut(4, 4, ClassName);
  end else begin
    if Assigned(FBlocks) and (FBlocks.Count > 0) and not FLayoutGuard then
      if FNeedsLayout or (FContentHeight <= ContentPad * 2) then
        RelayoutDocument;
    PaintDocument(Canvas, P);
    PaintScrollbar(P);
  end;
  Elapsed := GetTickCount64 - T0;
  LcaUiProfileRecordThemedPaint(Elapsed);
end;

procedure TLcaMarkdownView.Resize;
begin
  inherited Resize;
  RelayoutDocument;
  Invalidate;
end;

procedure TLcaMarkdownView.ChangeScale(M, D: Integer);
begin
  inherited ChangeScale(M, D);
  RelayoutDocument;
end;

procedure TLcaMarkdownView.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  TrackR: TRect;
  MaxS, ThumbH, RelY: Integer;
  ThumbR: TRect;
  Idx: Integer;
begin
  inherited MouseDown(Button, Shift, X, Y);
  if Button <> mbLeft then Exit;
  if HitOnVerticalThumb(X, Y) then begin
    FDragScrollActive := True;
    ThumbR := VerticalThumbRect;
    FDragThumbOffset := Y - ThumbR.Top;
    SetCapture(Self.Handle);
    Exit;
  end;
  if HitInVerticalTrack(X, Y) then begin
    TrackR := VerticalTrackRect;
    MaxS := MaxScrollY;
    ThumbH := VerticalThumbRect.Bottom - VerticalThumbRect.Top;
    RelY := Y - TrackR.Top - ThumbH div 2;
    if TrackR.Height > ThumbH then
      FScrollY := MulDiv(RelY, MaxS, TrackR.Height - ThumbH)
    else
      FScrollY := 0;
    ClampScroll;
    UpdateStickToBottomFromScroll;
    Invalidate;
    Exit;
  end;
  if not (FShowVBar and HitInVerticalTrack(X, Y)) then begin
    SetFocus;
    Idx := ClientPointToPlainIndex(X, Y);
    if ssDouble in Shift then
      SelectWordAt(Idx)
    else begin
      FSelAnchor := Idx;
      FSelCaret := Idx;
      FSelActive := True;
      FTextSelDrag := True;
      SetCapture(Handle);
      Invalidate;
    end;
  end;
end;

procedure TLcaMarkdownView.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  TrackR, ThumbR: TRect;
  MaxS, ThumbH, NewTop: Integer;
begin
  inherited MouseMove(Shift, X, Y);
  if FTextSelDrag then begin
    FSelCaret := ClientPointToPlainIndex(X, Y);
    Invalidate;
    Exit;
  end;
  if not FDragScrollActive then Exit;
  TrackR := VerticalTrackRect;
  MaxS := MaxScrollY;
  ThumbH := VerticalThumbRect.Bottom - VerticalThumbRect.Top;
  NewTop := Y - FDragThumbOffset;
  if TrackR.Height > ThumbH then begin
    if NewTop < TrackR.Top then NewTop := TrackR.Top;
    if NewTop > TrackR.Bottom - ThumbH then NewTop := TrackR.Bottom - ThumbH;
    FScrollY := MulDiv(NewTop - TrackR.Top, MaxS, TrackR.Height - ThumbH);
  end;
  ClampScroll;
  UpdateStickToBottomFromScroll;
  Invalidate;
end;

procedure TLcaMarkdownView.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
  if FTextSelDrag then begin
    FTextSelDrag := False;
    FSelCaret := ClientPointToPlainIndex(X, Y);
    if GetCapture = Handle then
      SetCapture(0);
    Invalidate;
  end;
  if FDragScrollActive then begin
    FDragScrollActive := False;
    if GetCapture = Handle then
      SetCapture(0);
  end;
end;

function TLcaMarkdownView.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer;
  MousePos: TPoint): Boolean;
var
  Step: Integer;
begin
  Step := ScaledLayoutMetric(Self, 40);
  FWheelAccumY := FWheelAccumY + MulDiv(WheelDelta, Step, 120);
  ScheduleWheelFlush;
  Result := True;
end;

end.