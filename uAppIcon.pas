unit uAppIcon;

{$mode objfpc}{$H+}

{ Taskbar / form icon from OWL PNG (LcaDesignSystem). EXE file icon uses windres ICON group. }

interface

procedure ApplyOwlApplicationIcon;

implementation

uses
  Classes, SysUtils, Graphics, Forms, LcaOwlIconRes;

procedure ApplyOwlApplicationIcon;
var
  Pic: TPicture;
begin
  if not Assigned(Application) then Exit;
  Pic := TPicture.Create;
  try
    if TryLoadOwlIconInto(Pic) then
      Application.Icon.Assign(Pic.Bitmap);
  finally
    Pic.Free;
  end;
end;

end.
