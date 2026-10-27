unit uRepositoryInterfaces;

{$mode ObjFPC}{$H+}

interface

type
  IAppSettingsRepository = interface
    ['{A4B8C2E1-7F3D-4A91-9E2B-1C0D5E6F7081}']
    function TryGet(const AKey: string; out AValue: string): Boolean;
    procedure SetString(const AKey, AValue: string);
  end;

implementation

end.
