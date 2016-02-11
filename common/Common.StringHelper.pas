unit Common.StringHelper;

interface

uses
  System.SysUtils, System.StrUtils;

function Join(const Separator: string; const Values: array of string;
  const AMap: TFunc<string, string> = nil): string;

implementation

{ TStringHelperEx }

function Join(const Separator: string;
  const Values: array of string; const AMap: TFunc<string, string>): string;
var
  s: string;
  b: Boolean;
begin
  Result := '';
  b := False;

  for s in Values do
  begin
    if Assigned(AMap) then
      Result := Result + IfThen(b, Separator) + AMap(s)
    else
      Result := Result + IfThen(b, Separator) + s;

    b := True;
  end;
end;

end.
