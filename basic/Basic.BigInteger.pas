unit Basic.BigInteger;

interface

uses
  System.SysUtils;

type
  TBigInteger = record { сделать из него TInterfacedObject? }
  public
    type
      TSign = (sNeg = -1, sZero = 0, sPoz = 1);
  private
    const
      DEFAULT_LEN: Integer = 20;
      WouldReturnNegVal: string = 'Operation would return a negative value';
  public
    FLength: Integer;
    FData: TArray<Cardinal>;
    FSign: TSign;
  public
    class function AddSameSign(A, B: TBigInteger): TBigInteger; static;
    class function Subtract(big, small: TBigInteger): TBigInteger; static;

    procedure MinusEq(big, small: TBigInteger);
    procedure PlusEq(A, B: TBigInteger);

    class function Compare(A, B: TBigInteger): TSign; static;
    class procedure MultiByteDivide(A, B: TBigInteger; out ADivResult,
      AModResult: TBigInteger); static;

    function XorWith(other: TBigInteger): TBigInteger;
    function DwordDiv(n: TBigInteger; d: Integer): TBigInteger;
    procedure Normalize;
  private
    function GetLen: Integer;
    procedure SetLen(const Value: Integer);
    function GetBytes: TBytes;
  public
    procedure Init(ASign: TSign; ALength: Integer); overload;
    procedure Init(ABytes: TBytes); overload;

    function Copy: TBigInteger;

    function ToString(radix: Integer): string; overload;
    function ToString(radix: Integer; characterSet: string): string; overload;

    function BitCount: Integer;

    function GetHashCode: Cardinal;

    property Len: Integer read GetLen write SetLen;
    property Bytes: TBytes read GetBytes;
  public
    class operator Implicit(A: TBytes): TBigInteger;
    class operator Implicit(A: Cardinal): TBigInteger;

    class operator Add(A, B: TBigInteger): TBigInteger;
    class operator Subtract(A, B: TBigInteger): TBigInteger;

    class operator Equal(A: TBigInteger; B: Cardinal): Boolean;
    class operator NotEqual(A: TBigInteger; B: Cardinal): Boolean;

    class operator Equal(A, B: TBigInteger): Boolean;
    class operator NotEqual(A, B: TBigInteger): Boolean;

    class operator GreaterThan(A, B: TBigInteger): Boolean;
    class operator LessThan(A, B: TBigInteger): Boolean;

    class operator GreaterThanOrEqual(A, B: TBigInteger): Boolean;
    class operator LessThanOrEqual(A, B: TBigInteger): Boolean;

    class operator BitwiseXor(A, B: TBigInteger): TBigInteger;
    class operator IntDivide(A: TBigInteger; B: Integer): TBigInteger;
    class operator IntDivide(A, B: TBigInteger): TBigInteger;
    //class operator Modulus()
  end;

implementation

uses
  System.Math;

{ TBigInteger }

class operator TBigInteger.Add(A, B: TBigInteger): TBigInteger;
begin
  if A = 0 then
    Exit(B)
  else
  if B = 0 then
    Exit(A)
  else
    Result := TBigInteger.AddSameSign(A, B);
end;

class function TBigInteger.AddSameSign(A, B: TBigInteger): TBigInteger;
var
  x, y: TArray<Cardinal>;
  yMax, xMax, i: Integer;
  sum: UInt64;
  carry: Boolean;
begin
  if A.FLength < B.FLength then
  begin
    x := B.FData;
    xMax := B.FLength;
    y := A.FData;
    yMax := A.FLength;
  end else
  begin
    x := A.FData;
    xMax := A.FLength;
    y := B.FData;
    yMax := B.FLength;
  end;

  Result.Init(sPoz, xMax + 1);

  i := 0;
  sum := 0;

  repeat
    sum := UInt64(x[i])+UInt64(y[i])+sum;
    Result.FData[i] := Cardinal(sum);
    sum := sum shr 32;
    Inc(i);
  until not (i < yMax);

  carry := sum <> 0;
  if carry then
  begin
    if i < xMax then
      repeat
        Result.FData[i] := x[i] + 1;
        carry := Result.FData[i] = 0;
        Inc(i);
      until not ((i < xMax) and carry);

    if carry then
    begin
      Result.FData[i] := 1;
      Result.SetLen(i+1);
      Exit;
    end;
  end;

  if i < xMax then
    repeat
      Result.FData[i] := x[i];
      Inc(i);
    until not (i < xMax);

  Result.Normalize;
end;

function TBigInteger.BitCount: Integer;
var
  value, mask: Cardinal;
begin
  Normalize;

  value   := FData[GetLen - 1];
  mask    := $80000000;
  Result  := 32;

  while (Result > 0) and ((value and mask) = 0) do
  begin
    Dec(Result);
    mask := mask shr 1;
  end;

  Result := Result + ((GetLen - 1) shl 5);
end;

class operator TBigInteger.BitwiseXor(A, B: TBigInteger): TBigInteger;
begin
  Result := A.XorWith(B);
end;

class function TBigInteger.Compare(A, B: TBigInteger): TSign;
var
  l1, l2, pos: Integer;
begin
  l1 := A.GetLen;
  l2 := B.GetLen;

  while (l1 > 0) and (A.FData[l1 - 1] = 0) do Dec(l1);
  while (l2 > 0) and (B.FData[l2 - 1] = 0) do Dec(l2);

  if (l1 = 0) and (l2 = 0) then Exit(sZero);

  if l1 < l2 then
    Exit(sNeg)
  else
  if l1 > l2 then
    Exit(sPoz);

  pos := l1 - 1;
  while (pos <> 0) and (A.FData[pos] = B.FData[pos]) do
    Dec(pos);

  if A.FData[pos] < B.FData[pos] then
    Exit(sNeg)
  else
  if A.FData[pos] > B.FData[pos] then
    Exit(sPoz)
  else
    Exit(sZero);
end;

function TBigInteger.Copy: TBigInteger;
begin
  Result.SetLen(GetLen);
  Move(FData[0], Result.FData[0], GetLen);
end;

class operator TBigInteger.IntDivide(A: TBigInteger; B: Integer): TBigInteger;
begin
  if B > 0 then
    Result := A.DwordDiv(A, B)
  else
    raise EDivByZero.Create('Divizion by zero');
end;

function TBigInteger.DwordDiv(n: TBigInteger; d: Integer): TBigInteger;
var
  r: UInt64;
  i: Integer;
begin
  Result.Init(sPoz, n.Len);

  r := 0;
  i := n.Len;

  while i > 0 do
  begin
    Dec(i);

    r := r shl 32;
    r := r or n.FData[i];

    Result.FData[i] := Cardinal(r div d);
    r := r mod d;
  end;

  Result.Normalize;
end;

class operator TBigInteger.Equal(A, B: TBigInteger): Boolean;
begin
  Result := Ord(Compare(A, B)) = 0;
end;

class operator TBigInteger.Equal(A: TBigInteger; B: Cardinal): Boolean;
begin
  if A.GetLen <> 1 then
    A.Normalize;

  Result := (A.GetLen = 1) and (A.FData[0] = B);
end;

function TBigInteger.GetBytes: TBytes;
var
  i, j, numBits, numBytes, numBytesInWord, pos: Integer;
  val: Cardinal;
begin
  SetLength(Result, 0);

  if Self = 0 then
  begin
    SetLength(Result, 1);
    Exit;
  end;

  numBits := BitCount;
  numBytes := numBits shr 3;
  if numBits and $07 <> 0 then
    Inc(numBytes);

  SetLength(Result, numBytes);

  numBytesInWord := numBytes and $03;
  if numBytesInWord = 0 then
    numBytesInWord := 4;

  pos := 0;
  for i := GetLen - 1 downto 0 do
  begin
    val := FData[i];

    for j := numBytesInWord - 1 downto 0 do
    begin
      Result[pos + j] := val and $FF;
      val := val shr 8;
    end;

    Inc(pos, numBytesInWord);
    numBytesInWord := 4;
  end;
end;

function TBigInteger.GetHashCode: Cardinal;
var
  i: Integer;
begin
  Result := 0;

  for i := 0 to GetLen - 1 do
    Result := Result xor FData[i];
end;

function TBigInteger.GetLen: Integer;
begin
  Result := Length(FData);
end;

class operator TBigInteger.GreaterThan(A, B: TBigInteger): Boolean;
begin
  Result := Ord(Compare(A, B)) > 0;
end;

class operator TBigInteger.GreaterThanOrEqual(A, B: TBigInteger): Boolean;
begin
  Result := Ord(Compare(A, B)) >= 0;
end;

class operator TBigInteger.Implicit(A: TBytes): TBigInteger;
begin
  Result.Init(A);
end;

class operator TBigInteger.Implicit(A: Cardinal): TBigInteger;
begin
  Result.Init(sPoz, 1);
  Result.FData[0] := A;
end;

procedure TBigInteger.Init(ABytes: TBytes);
var
  i, j, leftOver: Integer;
begin
  if Length(ABytes) = 0 then
    SetLength(ABytes, 1);

  SetLen(Length(ABytes) shr 2);
  leftOver := Length(ABytes) and $03;

  if leftOver <> 0 then
    SetLen(GetLen + 1);

  i := Length(ABytes) - 1;
  j := 0;

  while i >= 3 do
  begin
    FData[j] := Cardinal(
      (ABytes[i-3] shl (3 * 8)) or
      (ABytes[i-2] shl (2 * 8)) or
      (ABytes[i-1] shl (1 * 8)) or
      (ABytes[i])
    );

    Dec(i, 4);
    Inc(j);
  end;

  case leftOver of
    1: FData[GetLen - 1] := Cardinal( ABytes[0]);
    2: FData[GetLen - 1] := Cardinal((ABytes[0] shl 8 ) or  ABytes[1]);
    3: FData[GetLen - 1] := Cardinal((ABytes[0] shl 16) or (ABytes[1] shl 8) or (ABytes[2]));
  end;

  Normalize;
end;

class operator TBigInteger.IntDivide(A, B: TBigInteger): TBigInteger;
begin

end;

class operator TBigInteger.LessThan(A, B: TBigInteger): Boolean;
begin
  Result := Ord(Compare(A, B)) < 0;
end;

class operator TBigInteger.LessThanOrEqual(A, B: TBigInteger): Boolean;
begin
  Result := Ord(Compare(A, B)) <= 0;
end;

procedure TBigInteger.Init(ASign: TSign; ALength: Integer);
begin
  FSign := ASign;
  SetLen(ALength);
end;

procedure TBigInteger.MinusEq(big, small: TBigInteger);
var
  i: Integer;
  c, x: Cardinal;
label
  fixup;
begin
  i := 0;
  c := 0;

  repeat
    x := small.FData[i];

    x := x + c;
    big.FData[i] := big.FData[i] - x;

    if (x < c) or (big.FData[i] > (0-x-1)) then
      c := 1
    else
      c := 0;

    Inc(i);
  until not (i < small.GetLen);

  if i = big.GetLen then
    goto fixup;

  if c = 0 then
    repeat
      big.FData[i] := big.FData[i] - 1;
      Inc(i);
    until not ((big.FData[i-1] = 0) and (i < big.GetLen));

fixup:;
  while (big.GetLen > 0) and (big.FData[big.GetLen - 1] = 0) do
    big.SetLen(big.GetLen - 1);

  if big.GetLen = 0 then
    big.SetLen(big.GetLen + 1);
end;

class procedure TBigInteger.MultiByteDivide(A, B: TBigInteger; out ADivResult,
  AModResult: TBigInteger);
//var
//  remainderLen: Cardinal;
//  divisorLen: Integer;
begin
  if Compare(A, B) = sNeg then
  begin
    ADivResult := 0;
    AModResult := A;
  end;

  A.Normalize; B.Normalize;

  if B.Len = 1 then
  begin
//    DwordDivMod(A, B.FData[0], ADivResult, AModResult);
    Exit;
  end;

//  remainderLen := A.GetLen + 1;
//  int divisorLen = (int)bi2.length + 1;
//
//  uint mask = 0x80000000;
//  uint val = bi2.data[bi2.length - 1];
//  int shift = 0;
//  int resultPos = (int)bi1.length - (int)bi2.length;
//
//  while (mask != 0 && (val & mask) == 0)
//  {
//      shift++; mask >>= 1;
//  }
//
//  BigInteger quot = new BigInteger(Sign.Positive, bi1.length - bi2.length + 1);
//  BigInteger rem = (bi1 << shift);
//
//  uint[] remainder = rem.data;
//
//  bi2 = bi2 << shift;
//
//  int j = (int)(remainderLen - bi2.length);
//  int pos = (int)remainderLen - 1;
//
//  uint firstDivisorByte = bi2.data[bi2.length - 1];
//  ulong secondDivisorByte = bi2.data[bi2.length - 2];
//
//  while (j > 0)
//  {
//      ulong dividend = ((ulong)remainder[pos] << 32) + (ulong)remainder[pos - 1];
//
//      ulong q_hat = dividend / (ulong)firstDivisorByte;
//      ulong r_hat = dividend % (ulong)firstDivisorByte;
//
//      do
//      {
//
//          if (q_hat == 0x100000000 ||
//              (q_hat * secondDivisorByte) > ((r_hat << 32) + remainder[pos - 2]))
//          {
//              q_hat--;
//              r_hat += (ulong)firstDivisorByte;
//
//              if (r_hat < 0x100000000)
//                  continue;
//          }
//          break;
//      } while (true);
//
//      //
//      // At this point, q_hat is either exact, or one too large
//      // (more likely to be exact) so, we attempt to multiply the
//      // divisor by q_hat, if we get a borrow, we just subtract
//      // one from q_hat and add the divisor back.
//      //
//
//      uint t;
//      uint dPos = 0;
//      int nPos = pos - divisorLen + 1;
//      ulong mc = 0;
//      uint uint_q_hat = (uint)q_hat;
//      do
//      {
//          mc += (ulong)bi2.data[dPos] * (ulong)uint_q_hat;
//          t = remainder[nPos];
//          remainder[nPos] -= (uint)mc;
//          mc >>= 32;
//          if (remainder[nPos] > t) mc++;
//          dPos++; nPos++;
//      } while (dPos < divisorLen);
//
//      nPos = pos - divisorLen + 1;
//      dPos = 0;
//
//      // Overestimate
//      if (mc != 0)
//      {
//          uint_q_hat--;
//          ulong sum = 0;
//
//          do
//          {
//              sum = ((ulong)remainder[nPos]) + ((ulong)bi2.data[dPos]) + sum;
//              remainder[nPos] = (uint)sum;
//              sum >>= 32;
//              dPos++; nPos++;
//          } while (dPos < divisorLen);
//
//      }
//
//      quot.data[resultPos--] = (uint)uint_q_hat;
//
//      pos--;
//      j--;
//  }
//
//  quot.Normalize();
//  rem.Normalize();
//  BigInteger[] ret = new BigInteger[2] { quot, rem };
//
//  if (shift != 0)
//      ret[1] >>= shift;
//
//  return ret;
end;

procedure TBigInteger.Normalize;
begin
  while (GetLen > 0) and (FData[GetLen - 1] = 0) do
    SetLen(GetLen - 1);

  // Check for zero
  if GetLen = 0 then
    SetLen(1);
end;

class operator TBigInteger.NotEqual(A, B: TBigInteger): Boolean;
begin
  Result := Compare(A, B) <> sZero;
end;

class operator TBigInteger.NotEqual(A: TBigInteger; B: Cardinal): Boolean;
begin
  if A.GetLen <> 1 then
    A.Normalize;

  Result := not ((A.GetLen = 1) and (A.FData[0] = B));
end;

procedure TBigInteger.PlusEq(A, B: TBigInteger);
var
  x, y, r: TArray<Cardinal>;
  yMax, xMax, i: Integer;
  flag, carry: Boolean;
  sum: UInt64;
begin
  if A.GetLen < B.GetLen then
  begin
    flag := True;
    x := B.FData;
    xMax := B.GetLen;
    y := A.FData;
    yMax := A.GetLen;
  end else
  begin
    flag := False;
    x := A.FData;
    xMax := A.GetLen;
    y := B.FData;
    yMax := B.GetLen;
  end;

  r := A.FData;

  sum := 0;
  i := 0;

  repeat
    sum := sum + UInt64(x[i]) + UInt64(y[i]);
    r[i] := Cardinal(sum);
    sum := sum shr 32;
    Inc(i);
  until not (i < yMax);

  carry := sum <> 0;
  if carry then
  begin
    if i < xMax then
      repeat
        r[i] := x[i] + 1;
        carry := r[i] = 0;
        Inc(i);
      until not ((i < xMax) and carry);

    if carry then
    begin
      r[i] := 1;
      Inc(i);
      A.SetLen(i);
    end;
  end;

  if flag and (i < xMax - 1) then
    repeat
      r[i] := x[i];
      Inc(i);
    until not (i < xMax);

  A.SetLen(xMax + 1);
  A.Normalize;
end;

procedure TBigInteger.SetLen(const Value: Integer);
begin
  SetLength(FData, Value);
  FLength := Value;
end;

class operator TBigInteger.Subtract(A, B: TBigInteger): TBigInteger;
begin
  if B = 0 then
    Exit(A);

  if A = 0 then
    raise Exception.Create(WouldReturnNegVal);

  case Compare(A, B) of
    sZero:
      Result := 0;

    sPoz:
      Result := TBigInteger.Subtract(A, B);

    sNeg:
      raise Exception.Create(WouldReturnNegVal);

  else
    raise Exception.Create('');
  end;
end;

function TBigInteger.ToString(radix: Integer; characterSet: string): string;
var
  a: TBigInteger;
//  rem: Cardinal;
begin
  Result := '';

  if characterSet.Length < radix then
    raise Exception.Create('charSet length less than radix');

  if radix = 1 then
    raise Exception.Create('There is no such thing as radix one notation');

  if Self = 0 then
    Exit('0');

  if Self = 1 then
    Exit('1');

  a := Self.Copy;
  while a <> 0 do
  begin
//    rem := SingleByteDivideInPlace(a, radix);
//    Result := characterSet[Integer(rem)+1] + Result;
  end;
end;

function TBigInteger.ToString(radix: Integer): string;
begin
  Result := ToString(radix, '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ');
end;

class function TBigInteger.Subtract(big, small: TBigInteger): TBigInteger;
var
  i: Integer;
  x, c: Cardinal;
label
  fixup;
begin
  Result.Init(sPoz, big.GetLen);

  i := 0;
  c := 0;
  repeat
    x := small.FData[i];

    Inc(x, c);
    Result.FData[i] := big.FData[i] - x;
    if (x < c) or (Result.FData[i] > (0-x-1)) then
      c := 1
    else
      c := 0;

    Inc(i);
  until not (i < small.GetLen);

  if i = big.GetLen then
    goto fixup;

  if c = 1 then
  begin
    repeat
      Result.FData[i] := big.FData[i] - 1;
      Inc(i);
    until not ((big.FData[i] = 0) and (i < big.GetLen));

    if i = big.GetLen then
      goto fixup;
  end;

  repeat
    Result.FData[i] := big.FData[i];
    Inc(i);
  until not (i < big.GetLen);

fixup:;
  Result.Normalize;
end;

function TBigInteger.XorWith(other: TBigInteger): TBigInteger;
var
  i, l: Integer;
begin
  l := Min(GetLen, other.GetLen);
  Result.Init(sZero, l);

  for i := 0 to l - 1 do
    Result.FData[i] := FData[i] xor other.FData[i];
end;

end.
