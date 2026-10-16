unit LcaOwlIconRes;

{$mode objfpc}{$H+}

{ OWL_ICON is embedded in lazycodingagent.exe (owl_icon.bmp via lazres in lazycodingagent.lpr). }

interface

uses
  Classes, SysUtils, Graphics, LResources;

function LcaOwlIconResourceInstance: PtrUInt;
function TryLoadOwlIconInto(APicture: TPicture): Boolean;
procedure LoadOwlIconInto(APicture: TPicture);

implementation

uses
  LCLType,
  {$IFDEF WINDOWS}Windows{$ENDIF}
  {$IFDEF UNIX}ctypes, dynlibs{$ENDIF};

const
  OwlIconResourceName = 'OWL_ICON';

var
  LcaOwlIconResAnchor: Byte;

function ModuleFromAddress(const AAddr: Pointer): PtrUInt;
{$IFDEF WINDOWS}
var
  MemInfo: TMemoryBasicInformation;
{$ENDIF}
{$IFDEF UNIX}
var
  Info: Dl_info;
{$ENDIF}
begin
{$IFDEF WINDOWS}
  FillChar(MemInfo, SizeOf(MemInfo), 0);
  if VirtualQuery(AAddr, MemInfo, SizeOf(MemInfo)) = SizeOf(MemInfo) then
    Result := PtrUInt(MemInfo.AllocationBase)
  else
    Result := 0;
{$ELSE}
  FillChar(Info, SizeOf(Info), 0);
  if dladdr(AAddr, @Info) <> 0 then
    Result := PtrUInt(Info.dli_fbase)
  else
    Result := 0;
{$ENDIF}
end;

function LcaOwlIconResourceInstance: PtrUInt;
begin
  Result := ModuleFromAddress(@LcaOwlIconResAnchor);
  if Result = 0 then
    Result := PtrUInt(HInstance);
end;

procedure AppendUniqueInstance(var AInstances: array of PtrUInt; var ACount: Integer;
  const AValue: PtrUInt);
var
  J: Integer;
begin
  if AValue = 0 then Exit;
  for J := 0 to ACount - 1 do
    if AInstances[J] = AValue then Exit;
  AInstances[ACount] := AValue;
  Inc(ACount);
end;

function TryLoadOwlIconFromInstance(const AInstance: PtrUInt; APicture: TPicture): Boolean;
begin
  Result := False;
  if (AInstance = 0) or not Assigned(APicture) then Exit;
  try
    APicture.Bitmap.LoadFromResourceName(TLCLHandle(AInstance), OwlIconResourceName);
    Result := (APicture.Bitmap.Width > 0) and (APicture.Bitmap.Height > 0);
  except
    on E: Exception do
      Result := False;
  end;
end;

function TryLoadOwlIconFromStream(const AInstance: PtrUInt; const AResType: PChar;
  APicture: TPicture): Boolean;
var
  RS: TResourceStream;
begin
  Result := False;
  if (AInstance = 0) or not Assigned(APicture) then Exit;
  try
    RS := TResourceStream.Create(AInstance, OwlIconResourceName, AResType);
  except
    on E: EResNotFound do
      Exit;
  end;
  try
    if AResType = RT_BITMAP then
      APicture.Bitmap.LoadFromStream(RS, RS.Size)
    else
      APicture.LoadFromStream(RS);
    Result := (APicture.Width > 0) and (APicture.Height > 0);
  finally
    RS.Free;
  end;
end;

function TryLoadOwlIconInto(APicture: TPicture): Boolean;
var
  Instances: array[0..7] of PtrUInt;
  ResTypes: array[0..2] of PChar;
  InstanceCount, I, T: Integer;
  {$IFDEF WINDOWS}
  ModHandle: HMODULE;
  {$ENDIF}
begin
  Result := False;
  if not Assigned(APicture) then Exit;

  APicture.Graphic := nil;

  InstanceCount := 0;
  {$IFDEF WINDOWS}
  ModHandle := GetModuleHandle(nil);
  if ModHandle <> 0 then
    AppendUniqueInstance(Instances, InstanceCount, PtrUInt(ModHandle));
  {$ENDIF}
  AppendUniqueInstance(Instances, InstanceCount, PtrUInt(HInstance));
  AppendUniqueInstance(Instances, InstanceCount, LcaOwlIconResourceInstance);
  {$IFDEF WINDOWS}
  ModHandle := GetModuleHandle('LcaDesignSystem.bpl');
  if ModHandle <> 0 then
    AppendUniqueInstance(Instances, InstanceCount, PtrUInt(ModHandle));
  ModHandle := GetModuleHandle('lcadesignsystem.bpl');
  if ModHandle <> 0 then
    AppendUniqueInstance(Instances, InstanceCount, PtrUInt(ModHandle));
  {$ENDIF}

  for I := 0 to InstanceCount - 1 do
    if TryLoadOwlIconFromInstance(Instances[I], APicture) then
      Exit(True);

  ResTypes[0] := RT_BITMAP;
  ResTypes[1] := PChar('PNG');
  {$IFDEF WINDOWS}
  ResTypes[2] := RT_RCDATA;
  {$ELSE}
  ResTypes[2] := PChar(10);
  {$ENDIF}

  for I := 0 to InstanceCount - 1 do
    for T := Low(ResTypes) to High(ResTypes) do
      if TryLoadOwlIconFromStream(Instances[I], ResTypes[T], APicture) then
        Exit(True);
end;

procedure LoadOwlIconInto(APicture: TPicture);
begin
  if not TryLoadOwlIconInto(APicture) then
    raise EResNotFound.Create(OwlIconResourceName);
end;

end.
