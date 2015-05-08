{*********************************************************}
{                                                         }
{     Универсальная строка                                }
{     Данные представляет в виде массива байт             }
{     ===============================================     }
{                                                         }
{     Работа производится как с обычно строкой            }
{     Юникодная строка будет представляться как ANSI      }
{                                                         }
{     "+" - операция конкатенации двух юнистрок           }
{     foo := foo+12+34 и foo := foo+(12+34) дадут         }
{       разный результат, т.к. производится               }
{       конкатенация двух чисел, в первом случае          }
{       в массив будут помещены два числа, во втором -    }
{       результат сложения 2-х чисел                      }
{                                                         }
{*********************************************************}

unit Basic.UniString;

interface

uses
  System.SysUtils, System.Variants, System.Math, System.Generics.Collections,
  System.Generics.Defaults;

type
  TUniString = record
  private
    FData: TBytes;

    function GetDataPtr(Index: Integer): PByte; inline;

    function GetLen: Integer; inline;
    procedure SetLen(const Value: Integer); inline;

    function Get(Index: Integer): Byte; inline;
    procedure Put(Index: Integer; const Value: Byte); inline;

    function GetAsRawString: string; inline;
    procedure SetAsRawString(const Value: string); inline;
  private
    class function memcmp(ABuf1, ABuf2: PByte; ASize: Integer): Integer; static;
  public
    // надо ли их в инлайн переводить?
    class operator Add(const A, B: TUniString): TUniString;
    class operator Add(const A: TUniString; const B: string): TUniString;
    class operator Add(const A: TUniString; const B: Byte): TUniString;
    class operator Add(const A: TUniString; const B: Word): TUniString;
    class operator Add(const A: TUniString; const B: LongWord): TUniString;
    class operator Add(const A: TUniString; const B: UInt64): TUniString;
    class operator Add(const A: TUniString; const B: Integer): TUniString;

    class operator Implicit(const A: string): TUniString;
    class operator Implicit(const A: Variant): TUniString;
    class operator Implicit(const A: TUniString): AnsiString; // загнать под дефайн
    class operator Implicit(const A: TUniString): string;
    class operator Implicit(const A: TUniString): Variant;
    class operator Implicit(const A: TUniString): TBytes;

    class operator Explicit(const A: string): TUniString;
    class operator Explicit(const A: Variant): TUniString;
    class operator Explicit(const A: TUniString): AnsiString; // загнать под дефайн
    class operator Explicit(const A: TUniString): string;
    class operator Explicit(const A: TUniString): Variant;
    class operator Explicit(const A: TUniString): TBytes;

    class operator Equal(const A, B: TUniString): Boolean;
    class operator NotEqual(const A, B: TUniString): Boolean;
    class operator GreaterThan(const A, B: TUniString): Boolean;
    class operator GreaterThanOrEqual(const A, B: TUniString): Boolean;
    class operator LessThan(const A, B: TUniString): Boolean;
    class operator LessThanOrEqual(const A, B: TUniString): Boolean;
  public
    function Copy(Index, Count: Integer): TUniString; overload; inline;
    function Copy: TUniString; overload; inline;
    procedure Delete(Index, Count: Integer);
    procedure Insert(AIndex: Integer; const AData: TUniString);
    procedure Replace(const ASource: TUniString; const Index: Integer;
      const Count: Integer = 0);
  public
    procedure Assign(const ASource: TUniString); inline; { рекомендуется к использованию вместо := }
  public
    class function FromUnicode(const AData: string): TUniString; static; inline;
    class function Compare(const A, B: TUniString; ACompareLen: Boolean = True): Integer; static; inline;
  public
    function GetHashCode: Integer;
  public
    { Функции приведения к типам }
    function AsString: string; inline;
    function AsUInt64: UInt64; inline;
    function AsInteger: Integer; inline;
  public
    function ToHexString: string;
    function ToBase64String: string;

    procedure FillChar(AChar: Byte = 0); inline;

    procedure FillRandom; overload;
    procedure FillRandom(ALen: Integer); overload;
  public
    property DataPtr[Index: Integer]: PByte read GetDataPtr;
    property Len: Integer read GetLen write SetLen;
    property Data[Index: Integer]: Byte read Get write Put; default; // переименовать

    property AsRawString: string read GetAsRawString write SetAsRawString;
  end;

  // синоним
  UString = TUniString;

type
  TUniStringEqualityComparer = class(TInterfacedObject, IEqualityComparer<TUniString>)
    function Equals(const Left, Right: TUniString): Boolean; reintroduce;
    function GetHashCode(const Value: TUniString): Integer; reintroduce;
  end;

  TUniStringComparer = class(TInterfacedObject, IComparer<TUniString>)
    function Compare(const Left, Right: TUniString): Integer;
  end;

type
  TUniStringList = class;

  TUniStringEnumerator = class
  private
    FIndex: Integer;
    FUniStrings: TUniStringList;
  public
    constructor Create(AUniStrings: TUniStringList);
    function GetCurrent: TUniString; inline;
    function MoveNext: Boolean;
    property Current: TUniString read GetCurrent;
  end;

  TUniStringList = class(TList<TUniString>)
  public
    function AddUnique(const S: TUniString): Integer;
    function GetEnumerator: TUniStringEnumerator; reintroduce;
  end;

{
  Повыдергивать часть ф-й из System.StrUtils
}

function IfThen(AValue: Boolean; const ATrue: TUniString;
  AFalse: TUniString): TUniString; overload; inline;

function Base64ToUniString(const ABase64str: string): TUniString;
function Base32ToUniString(const ABase32str: string): TUniString;
function HexToUnistring(const AHex: string): TUniString;

implementation

uses
  System.Classes;

{ TUniString }

{$REGION 'class operators'}
class operator TUniString.Add(const A, B: TUniString): TUniString;
begin
  Result.SetLen(A.GetLen + B.GetLen);

  if A.GetLen > 0 then
    Move(A.FData[0], Result.FData[0], A.GetLen);

  if B.GetLen > 0 then
    Move(B.FData[0], Result.FData[A.GetLen], B.GetLen);
end;

class operator TUniString.Add(const A: TUniString; const B: string): TUniString;
var
  i, l: Integer;
begin
  Result := A;

  l := A.GetLen;
  Result.SetLen(l + Length(B));

  for i := 1 to Length(B) do
    Result.FData[i-1+l] := Byte(B[i]);
end;

class operator TUniString.Implicit(const A: TUniString): AnsiString;
begin
  SetLength(Result, A.GetLen);
  Move(A.FData[0], Result[1], Length(Result));
end;

class operator TUniString.Implicit(const A: string): TUniString;
var
  i: Integer;
begin
  Result.SetLen(Length(A));
  for i := 1 to Length(A) do
    Result.FData[i-1] := Byte(A[i]);
end;

class operator TUniString.Equal(const A, B: TUniString): Boolean;
begin
  if A.GetLen <> B.GetLen then
    Exit(False)
  else
    Result := CompareMem(A.GetDataPtr(0), B.GetDataPtr(0), A.GetLen);
end;

class operator TUniString.Explicit(const A: string): TUniString;
begin
  Result := A;
end;

class operator TUniString.Explicit(const A: TUniString): Variant;
begin
  Result := A;
end;

class operator TUniString.Explicit(const A: TUniString): TBytes;
begin
  Result := A;
end;

class operator TUniString.Explicit(const A: Variant): TUniString;
begin
  Result := A;
end;

class operator TUniString.Explicit(const A: TUniString): string;
begin
  Result := A;
end;

class operator TUniString.Explicit(const A: TUniString): AnsiString;
begin
  Result := A;
end;

class operator TUniString.Implicit(const A: TUniString): string;
var
  i, c: Integer;
begin
  c := A.GetLen;
  SetLength(Result, c);

  for i := 0 to c-1 do
    Result[i+1] := Char(a[i]);
end;

class operator TUniString.NotEqual(const A, B: TUniString): Boolean;
begin
  if A.GetLen <> B.GetLen then
    Exit(True)
  else
    Result := not CompareMem(A.GetDataPtr(0), B.GetDataPtr(0), A.GetLen);
end;

class operator TUniString.Add(const A: TUniString; const B: Byte): TUniString;
var
  l: Integer;
begin
  Result := A;

  l := Result.GetLen;
  Result.SetLen(l+SizeOf(Byte));
  Result.Put(l, B);
end;

class operator TUniString.Add(const A: TUniString; const B: Word): TUniString;
var
  l: Integer;
begin
  Result := A;

  l := Result.GetLen;
  Result.SetLen(l+SizeOf(Word));
  Move(B, Result.FData[l], SizeOf(Word));
end;

class operator TUniString.Add(const A: TUniString;
  const B: LongWord): TUniString;
var
  l: Integer;
begin
  Result := A;

  l := Result.GetLen;
  Result.SetLen(l+SizeOf(LongWord));
  Move(B, Result.FData[l], SizeOf(LongWord));
end;

class operator TUniString.Add(const A: TUniString; const B: UInt64): TUniString;
var
  l: Integer;
begin
  Result := A;

  l := Result.GetLen;
  Result.SetLen(l+SizeOf(UInt64));
  Move(B, Result.FData[l], SizeOf(UInt64));
end;

class operator TUniString.Add(const A: TUniString; const B: Integer): TUniString;
var
  l: Integer;
begin
  Result := A;

  l := Result.GetLen;
  Result.SetLen(l+SizeOf(Integer));
  Move(B, Result.FData[l], SizeOf(Integer));
end;

class operator TUniString.Implicit(const A: TUniString): Variant;
begin
  Result := A.FData;
end;

class operator TUniString.Implicit(const A: TUniString): TBytes;
begin
  Result := A.FData;
end;

class operator TUniString.LessThan(const A, B: TUniString): Boolean;
begin
  if A.Len < B.Len then
    Result := True
  else
  if A.Len > B.Len then
    Result := False
  else
    Result := memcmp(A.GetDataPtr(0), B.GetDataPtr(0), A.Len) < 0;
end;

class operator TUniString.LessThanOrEqual(const A, B: TUniString): Boolean;
begin
  if A.Len < B.Len then
    Result := True
  else
  if A.Len > B.Len then
    Result := False
  else
    Result := memcmp(A.GetDataPtr(0), B.GetDataPtr(0), A.Len) <= 0;
end;

class operator TUniString.GreaterThan(const A, B: TUniString): Boolean;
begin
  if A.Len > B.Len then
    Result := True
  else
  if A.Len < B.Len then
    Result := False
  else
    Result := memcmp(A.GetDataPtr(0), B.GetDataPtr(0), A.Len) > 0;
end;

class operator TUniString.GreaterThanOrEqual(const A, B: TUniString): Boolean;
begin
  if A.Len > B.Len then
    Result := True
  else
  if A.Len < B.Len then
    Result := False
  else
    Result := memcmp(A.GetDataPtr(0), B.GetDataPtr(0), A.Len) >= 0;
end;

class operator TUniString.Implicit(const A: Variant): TUniString;
var
  v: TVarType;
  valInt: Integer;
  w: Word;
  i64: Int64;
begin
  // добавить все возможные типы для Variant
  v := VarType(A);
  case v of
    varByte:
      begin
        Result.SetLen(SizeOf(Byte));
        Result.FData[0] := Byte(A);
      end;

    varWord:
      begin
        w := Word(A);
        Result.SetLen(SizeOf(Word));
        Move(w, Result.DataPtr[0]^, SizeOf(Word));
      end;

    varArray or varByte:
      Result.FData := A;

    varString, varUString:
      Result := string(A);

    varInteger, varLongWord:
      begin
        valInt := Integer(A);
        Result.SetLen(SizeOf(Integer));
        Move(valInt, Result.DataPtr[0]^, SizeOf(Integer));
      end;

    varInt64, varUInt64:
      begin
        i64 := Int64(A);
        Result.SetLen(SizeOf(Int64));
        Move(i64, Result.DataPtr[0]^, SizeOf(Int64));
      end;
  else
    raise Exception.CreateFmt('Unsupported variant type (%d)', [v]);
  end;
end;
{$ENDREGION}

function TUniString.AsInteger: Integer;
begin
  Result := 0;
  Move(FData[0], Result, Min(GetLen, SizeOf(Integer)));
end;

procedure TUniString.Assign(const ASource: TUniString);
begin
  SetLen(ASource.GetLen);
  Move(ASource.FData[0], FData[0], ASource.GetLen);
end;

function TUniString.AsString: string;
begin
  Result := Self;
end;

function TUniString.AsUInt64: UInt64;
begin
  Result := 0;
  Move(FData[0], Result, Min(GetLen, SizeOf(UInt64)));
end;

class function TUniString.memcmp(ABuf1, ABuf2: PByte; ASize: Integer): Integer;
begin
  if ASize <> 0 then
  repeat
    if (ABuf1^ <> ABuf2^) then
      Exit(ABuf1^ - ABuf2^);

    inc(ABuf1);
    inc(ABuf2);

    dec(ASize);
  until (ASize <= 0);

	Result := 0;
end;

procedure TUniString.FillChar(AChar: Byte = 0);
begin
  System.FillChar(FData[0], GetLen, AChar);
end;

procedure TUniString.FillRandom;
var
  i: Integer;
begin
  for i := 0 to GetLen - 1 do
    Put(i, Random($100));
end;

procedure TUniString.FillRandom(ALen: Integer);
begin
  SetLen(ALen);
  FillRandom;
end;

procedure TUniString.Put(Index: Integer; const Value: Byte);
begin
  if Index < GetLen then
    FData[Index] := Value;
end;

procedure TUniString.Replace(const ASource: TUniString; const Index,
  Count: Integer);
var
  cnt: Integer;
begin
  cnt := IfThen(Count = 0, ASource.GetLen, Count);
  if Index + cnt > GetLen then
    raise Exception.Create('Count is too large');

  Move(ASource.GetDataPtr(0)^, GetDataPtr(0)^, cnt);
end;

function TUniString.Copy(Index, Count: Integer): TUniString;
begin
  Result.FData := System.Copy(Self.FData, Index, Count);
end;

class function TUniString.Compare(const A, B: TUniString;
  ACompareLen: Boolean): Integer;
var
  len, lenDiff: Integer;
begin
  len := A.Len;
  lenDiff := len - B.Len;

  if B.Len < len then
    len := B.Len;

  Result := BinaryCompare(A.DataPtr[0], B.DataPtr[0], len);

  if (Result = 0) and ACompareLen then
    Result := lenDiff;
end;

function TUniString.Copy: TUniString;
begin
  Result := Copy(0, GetLen);
end;

procedure TUniString.Delete(Index, Count: Integer);
var
  len, tailLen, cnt: Integer;
begin
  len := GetLen;
  cnt := Count;

  if (Index >= 0) and (Index <= Len) and (cnt > 0) then
  begin
    tailLen := Len - Index;
    if cnt > tailLen then
      cnt := tailLen;

    Move(Self.FData[Index+cnt], Self.FData[Index], tailLen - cnt);
    SetLen(Len - cnt);
  end;
end;

procedure TUniString.Insert(AIndex: Integer; const AData: TUniString);
begin
  if GetLen < AData.GetLen + AIndex then
    SetLen(AData.GetLen + AIndex);

  Move(AData.GetDataPtr(0)^, GetDataPtr(AIndex)^, AData.GetLen);
end;

function TUniString.Get(Index: Integer): Byte;
begin
  if Index < GetLen then
    Result := FData[Index]
  else
    Result := 0;
end;

function TUniString.GetAsRawString: string;
begin
  SetLength(Result, GetLen div 2);
  Move(FData[0], Result[1], GetLen);
end;

function TUniString.GetDataPtr(Index: Integer): PByte;
begin
  Result := @FData[Index];
end;

function TUniString.GetHashCode: Integer;
begin
  Result := BobJenkinsHash(FData[0], GetLen, 0);
end;

function TUniString.GetLen: Integer;
begin
  Result := Length(FData);
end;

procedure TUniString.SetAsRawString(const Value: string);
begin
  SetLen(Value.Length * 2);
  Move(Value[1], FData[0], GetLen);
end;

procedure TUniString.SetLen(const Value: Integer);
begin
  SetLength(FData, Value);
end;

function TUniString.ToBase64String: string;

  function Encode_Byte(b: Byte): char;
  const
    Base64Code: string =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  begin
    Result := Base64Code[(b and $3F)+1];
  end;

var
  i: Integer;
begin
  i := 0;
  Result := '';

  while i < GetLen do
  begin
    Result := Result + Encode_Byte(Get(i) shr 2);
    Result := Result + Encode_Byte((Get(i) shl 4) or (Get(i+1) shr 4));

    if i+1 < GetLen then
      Result := Result + Encode_Byte((Get(i+1) shl 2) or (Get(i+2) shr 6))
    else
      Result := Result + '=';

    if i+2 < GetLen then
      Result := Result + Encode_Byte(Get(i+2))
    else
      Result := Result + '=';

    Inc(i, 3);
  end;
end;

function TUniString.ToHexString: string;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to GetLen-1 do
    Result := Result + Get(i).ToHexString(2);
end;

class function TUniString.FromUnicode(const AData: string): TUniString;
begin
  Result.SetAsRawString(AData);
end;

function IfThen(AValue: Boolean; const ATrue: TUniString;
  AFalse: TUniString): TUniString;
begin
  if AValue then
    Result := ATrue
  else
    Result := AFalse;
end;

function Base64ToUniString(const ABase64str: string): TUniString;
const
  RESULT_ERROR = -2;
var
  inLineIndex: Integer;
  c: Char;
  x: SmallInt;
  c4: Word;
  StoredC4: array[0..3] of SmallInt;
  InLineLength: Integer;
begin
  Result.Len := 0;
  inLineIndex := 1;
  c4 := 0;

  InLineLength := Length(ABase64str);

  while inLineIndex <= InLineLength do
  begin
    while (inLineIndex <= InLineLength) and (c4 < 4) do
    begin
      c := ABase64str[inLineIndex];

      case c of
        '+'     : x := 62;
        '/'     : x := 63;
        '0'..'9': x := Ord(c) - (Ord('0')-52);
        '='     : x := -1;
        'A'..'Z': x := Ord(c) - Ord('A');
        'a'..'z': x := Ord(c) - (Ord('a')-26);
      else
        x := RESULT_ERROR;
      end;

      if x <> RESULT_ERROR then
      begin
        StoredC4[c4] := x;
        Inc(c4);
      end;

      Inc(inLineIndex);
    end;

    if c4 = 4 then
    begin
      c4 := 0;
      Result := Result + Byte( (StoredC4[0] shl 2) or (StoredC4[1] shr 4) );

      if StoredC4[2] = -1 then
        Exit;

      Result := Result + Byte( (StoredC4[1] shl 4) or (StoredC4[2] shr 2) );

      if StoredC4[3] = -1 then
        Exit;

      Result := Result + Byte( (StoredC4[2] shl 6) or (StoredC4[3]) );
    end;
  end;
end;

function Base32ToUniString(const ABase32str: string): TUniString;
const
  base32Lookup: array[0..79] of Byte = (
    $FF, $FF, $1A, $1B, $1C, $1D, $1E, $1F, (* '0', '1', '2', '3', '4', '5', '6', '7' *)
    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, (* '8', '9', ':', ';', '<', '=', '>', '?' *)
    $FF, $00, $01, $02, $03, $04, $05, $06, (* '@', 'A', 'B', 'C', 'D', 'E', 'F', 'G' *)
    $07, $08, $09, $0A, $0B, $0C, $0D, $0E, (* 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O' *)
    $0F, $10, $11, $12, $13, $14, $15, $16, (* 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W' *)
    $17, $18, $19, $FF, $FF, $FF, $FF, $FF, (* 'X', 'Y', 'Z', '[', '\', ']', '^', '_' *)
    $FF, $00, $01, $02, $03, $04, $05, $06, (* '`', 'a', 'b', 'c', 'd', 'e', 'f', 'g' *)
    $07, $08, $09, $0A, $0B, $0C, $0D, $0E, (* 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o' *)
    $0F, $10, $11, $12, $13, $14, $15, $16, (* 'p', 'q', 'r', 's', 't', 'u', 'v', 'w' *)
    $17, $18, $19, $FF, $FF, $FF, $FF, $FF  (* 'x', 'y', 'z', '{', '|', '}', '~', 'DEL' *)
  );
var
  i, index, offset, digit, lookup: Integer;
begin
  Result.Len := ABase32str.Length;

  index := 0;
  offset := 0;

  for i := 1 to ABase32Str.Length do
  begin
    lookup := Byte(ABase32Str[i]) - Byte('0');

    { Skip chars outside the lookup table }
    if (lookup < 0) or (lookup >= Length(base32Lookup)) then
      Continue;

    { If this digit is not in the table, ignore it }
    digit := base32Lookup[lookup];
    if digit = $FF then
      Continue;

    if index <= 3 then
    begin
      index := (index + 5) mod 8;

      if index = 0 then
      begin
        Result[offset] := Result[offset] or digit;
        Inc(offset);
      end else
        Result[offset] := Result[offset] or (digit shl (8 - index));
    end else
    begin
      index := (index + 5) mod 8;
      Result[offset] := Result[offset] or (digit shr index);
      Inc(offset);
      Result[offset] := Result[offset] or (digit shl (8 - index));
    end;
  end;

  Result.Len := offset{ + 1};
end;

function HexToUnistring(const AHex: string): TUniString;
begin
  Assert(Length(AHex) mod 2 = 0, 'invalid string length');

  Result.Len := 0; { для очистки памяти, на всякий случай }
  Result.Len := Length(AHex) div 2;
  HexToBin(PChar(AHex), Result.DataPtr[0]^, Result.Len);
end;

{ TUniStringList }

function TUniStringList.AddUnique(const S: TUniString): Integer;
begin
  Result := IndexOf(S);

  if Result = -1 then
    Result := Add(S);
end;

function TUniStringList.GetEnumerator: TUniStringEnumerator;
begin
  Result := TUniStringEnumerator.Create(Self);
end;

{ TUniStringComparer }

function TUniStringEqualityComparer.Equals(const Left, Right: TUniString): Boolean;
begin
  Result := Left = Right;
end;

function TUniStringEqualityComparer.GetHashCode(const Value: TUniString): Integer;
begin
  Result := Value.GetHashCode;
end;

{ TUniStringComparer }

function TUniStringComparer.Compare(const Left, Right: TUniString): Integer;
begin
  Result := TUniString.Compare(Left, Right);
end;

{ TUniStringEnumerator }

constructor TUniStringEnumerator.Create(AUniStrings: TUniStringList);
begin
  inherited Create;
  FIndex := -1;
  FUniStrings := AUniStrings;
end;

function TUniStringEnumerator.GetCurrent: TUniString;
begin
  Result := FUniStrings[FIndex];
end;

function TUniStringEnumerator.MoveNext: Boolean;
begin
  Result := FIndex < FUniStrings.Count - 1;
  if Result then
    Inc(FIndex);
end;

end.
