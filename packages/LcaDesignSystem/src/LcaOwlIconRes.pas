unit LcaOwlIconRes;

{$mode objfpc}{$H+}

{ Embeds packages/LcaDesignSystem/res/owl_icon.png as OWL_ICON (lazres). }

interface

uses
  Classes, SysUtils, Graphics, LResources;

function LcaOwlIconResourceInstance: PtrUInt;
procedure LoadOwlIconInto(APicture: TPicture);

implementation

uses
  {$IFDEF WINDOWS}Windows{$ENDIF}
  {$IFDEF UNIX}ctypes, dynlibs{$ENDIF};

const
  OwlIconResourceName = 'OWL_ICON';

var
  LcaOwlIconResAnchor: Byte;

{$R ../res/owl_icon.res}

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

function TryOpenOwlIconStream(const AInstance: PtrUInt; const AResType: PChar;
  out AStream: TResourceStream): Boolean;
begin
  Result := False;
  AStream := nil;
  if AInstance = 0 then Exit;
  try
    AStream := TResourceStream.Create(AInstance, OwlIconResourceName, AResType);
    Result := True;
  except
    on E: EResNotFound do
      AStream := nil;
  end;
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

procedure LoadOwlIconInto(APicture: TPicture);
var
  RS: TResourceStream;
  Instances: array[0..7] of PtrUInt;
  InstanceCount, I, T: Integer;
  ResTypes: array[0..1] of PChar;
  {$IFDEF WINDOWS}
  BplHandle: HMODULE;
  {$ENDIF}
begin
  if not Assigned(APicture) then Exit;

  ResTypes[0] := PChar('PNG');
  {$IFDEF WINDOWS}
  ResTypes[1] := RT_RCDATA;
  {$ELSE}
  ResTypes[1] := PChar(10);
  {$ENDIF}

  InstanceCount := 0;
  AppendUniqueInstance(Instances, InstanceCount, PtrUInt(HInstance));
  AppendUniqueInstance(Instances, InstanceCount, LcaOwlIconResourceInstance);
  {$IFDEF WINDOWS}
  BplHandle := GetModuleHandle('LcaDesignSystem.bpl');
  if BplHandle <> 0 then
    AppendUniqueInstance(Instances, InstanceCount, PtrUInt(BplHandle));
  BplHandle := GetModuleHandle('lcadesignsystem.bpl');
  if BplHandle <> 0 then
    AppendUniqueInstance(Instances, InstanceCount, PtrUInt(BplHandle));
  {$ENDIF}

  for I := 0 to InstanceCount - 1 do
    for T := Low(ResTypes) to High(ResTypes) do begin
      if not TryOpenOwlIconStream(Instances[I], ResTypes[T], RS) then Continue;
      try
        APicture.LoadFromStream(RS);
        Exit;
      finally
        RS.Free;
      end;
    end;

  raise EResNotFound.Create(OwlIconResourceName);
end;

end.
