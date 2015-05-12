unit DHT.NodeID;

interface

uses
  System.SysUtils,
  Basic.UniString, Basic.BigInteger,
  Hash;

type
  TNodeID = record
  public
    const
      NodeIDLen = 20;
  private
    FValue: TBigInteger;
  public
    function AsUniString: TUniString;
    procedure FillRandom;

    function CompareTo(AOther: TNodeID): Integer;
    function Equals(AOther: TNodeID): Boolean;
    class function New: TNodeID; static;
  public
    class operator Implicit(A: TBytes): TNodeID;
    class operator Implicit(A: Cardinal): TNodeID;
    class operator Implicit(A: TUniString): TNodeID;

    class operator Add(A, B: TNodeID): TNodeID;
    class operator Subtract(A, B: TNodeID): TNodeID;

    class operator Equal(A: TNodeID; B: TNodeID): Boolean;
    class operator NotEqual(A: TNodeID; B: TNodeID): Boolean;

    class operator GreaterThan(A, B: TNodeID): Boolean;
    class operator LessThan(A, B: TNodeID): Boolean;

    class operator GreaterThanOrEqual(A, B: TNodeID): Boolean;
    class operator LessThanOrEqual(A, B: TNodeID): Boolean;

    class operator BitwiseXor(A, B: TNodeID): TNodeID;
    class operator IntDivide(A: TNodeID; B: Integer): TNodeID;
  public
    function GetHashCode: Integer;
  end;

implementation

{ TNodeID }

class operator TNodeID.Add(A, B: TNodeID): TNodeID;
begin
  Result.FValue := A.FValue + B.FValue;
end;

function TNodeID.AsUniString: TUniString;
begin
  Result := FValue.Bytes;
  { дополняем нулями, пока длина меньше NODE_ID_LEN }
  while Result.Len < NodeIDLen do
    Result := 0 + Result;
end;

class operator TNodeID.BitwiseXor(A, B: TNodeID): TNodeID;
begin
  Result.FValue := A.FValue xor B.FValue;
end;

function TNodeID.CompareTo(AOther: TNodeID): Integer;
begin
  Result := Ord(FValue.Compare(FValue, AOther.FValue));
end;

class operator TNodeID.Implicit(A: TUniString): TNodeID;
var
  b: TBytes;
begin
  b := A;
  Result := b;
end;

class operator TNodeID.IntDivide(A: TNodeID; B: Integer): TNodeID;
begin
  Result.FValue := A.FValue div B;
end;

class operator TNodeID.Equal(A: TNodeID; B: TNodeID): Boolean;
begin
  Result := A.FValue = B.FValue;
end;

function TNodeID.Equals(AOther: TNodeID): Boolean;
begin
  Result := CompareTo(AOther) = 0;
end;

procedure TNodeID.FillRandom;
begin

end;

function TNodeID.GetHashCode: Integer;
begin
  Result := FValue.GetHashCode;
end;

class operator TNodeID.GreaterThan(A, B: TNodeID): Boolean;
begin
  Result := A.FValue > B.FValue;
end;

class operator TNodeID.GreaterThanOrEqual(A, B: TNodeID): Boolean;
begin
  Result := A.FValue >= B.FValue;
end;

class operator TNodeID.Implicit(A: Cardinal): TNodeID;
begin
  Result.FValue := TBigInteger(A);
end;

class operator TNodeID.Implicit(A: TBytes): TNodeID;
begin
  Result.FValue := A;
end;

class operator TNodeID.LessThan(A, B: TNodeID): Boolean;
begin
  Result := A.FValue < B.FValue;
end;

class operator TNodeID.LessThanOrEqual(A, B: TNodeID): Boolean;
begin
  Result := A.FValue <= B.FValue;
end;

class function TNodeID.New: TNodeID;
var
  cid: TUniString;
  buf: TBytes;
begin
  cid.Len := 500+random(500);
  cid.FillRandom;
  cid := SHA1(cid);

  SetLength(buf, cid.Len);
  Move(cid.DataPtr[0]^, buf[0], cid.Len);
//  SetLength(buf, 20);
//  HexToBin('16D4F4BC149AE82CB8067A63A016BBA27367D527', buf[0], 20);

  Result := buf;
end;

class operator TNodeID.NotEqual(A: TNodeID; B: TNodeID): Boolean;
begin
  Result := A.FValue <> B.FValue;
end;

class operator TNodeID.Subtract(A, B: TNodeID): TNodeID;
begin
  Result.FValue := A.FValue - B.FValue;
end;


end.
