unit Common.SHA1;

interface

uses
  System.Classes, System.SysUtils, System.Generics.Collections, System.Hash,
  Basic.UniString;

const
  SHA1HashLen = 20;

function SHA1(AData: Pointer; ALength: Integer): TUniString; overload; inline;
function SHA1(const Value: TUniString): TUniString; overload; inline;

implementation

function SHA1(AData: Pointer; ALength: Integer): TUniString;
var
  ctx: THashSHA1;
begin
  ctx := THashSHA1.Create;
  ctx.Update(AData, ALength);

  Result := ctx.HashAsBytes;
end;

function SHA1(const Value: TUniString): TUniString;
begin
  Result := SHA1(Value.DataPtr[0], Value.Len);
end;

end.
