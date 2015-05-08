unit bitfield;

interface

uses
  System.SysUtils, System.Math, Basic.UniString;

type
  TBitField = record
  private
    FBuffer: TArray<Integer>;
    FLen: Integer;
    FCheckedCount: Integer;

    procedure CheckIndex(Index: Integer); inline;

    procedure Validate;
    procedure ZeroUnusedBits;
    function GetAllTrue: Boolean; inline;
    function GetAllFalse: Boolean; inline;
    function GetAsUniString: TUniString;
    function GetBit(Index: Integer): Boolean; inline;
    procedure SetBit(Index: Integer; const Value: Boolean);

    function GetLen: Integer; inline;
    function GetCheckedCount: Integer; inline;
    function GetLengthInBytes: Integer; inline;
  public
    class operator BitwiseXor(const A, B: TBitField): TBitField;
    class operator BitwiseAnd(const A, B: TBitField): TBitField;
    class operator LogicalNot(const A: TBitField): TBitField;
  public
    property Len: Integer read GetLen; { количество бит }
    property LengthInBytes: Integer read GetLengthInBytes;
    property AllTrue: Boolean read GetAllTrue;
    property AllFalse: Boolean read GetAllFalse;
    property CheckedCount: Integer read GetCheckedCount;
    property AsUniString: TUniString read GetAsUniString;
    property Bits[Index: Integer]: Boolean read GetBit write SetBit; default;

    function FirstTrue: Integer; overload; inline;
    function FirstTrue(AStartIndex, AEndIndex: Integer): Integer; overload;

    function FirstFalse: Integer; overload; inline;
    function FirstFalse(AStartIndex, AEndIndex: Integer): Integer; overload;

    constructor FromUniString(const AData: TUniString);
    constructor Create(ALength: Integer);
  private
    class procedure Check(const A, B: TBitField); static; inline;
  end;

  EBitFieldException = class(Exception);
  EBitFieldDifferentLengthException = class(EBitFieldException);

  TBitSum = record
  private
    FSum: TArray<Byte>;
  public
    class operator Add(const A, B: TBitSum): TBitSum;
    class operator Add(const A: TBitSum; B: TBitField): TBitSum;
    class operator Add(const A: TBitField; B: TBitSum): TBitSum;
  private
    function GetLen: Integer; inline;
  private
    function GetSums(Index: Integer): Byte;
  public
    constructor Create(ALength: Integer); overload;
    constructor Create(ABitField: TBitField); overload;

    procedure Inc(AIndex: Integer); inline;

    function GetBestPieces(AMaxCount: Integer;
      AExcludeMask: TBitField): TArray<Integer>; overload;
    function GetBestPieces(AMaxCount: Integer): TArray<Integer>; overload;

    property Len: Integer read GetLen;
    property Sums[Index: Integer]: Byte read GetSums; default;
  private
    class procedure Check(const A, B: TBitSum); static; inline;
  end;

  EBitSumException = class(Exception);
  EBitSumDifferentLengthException = class(EBitSumException);

implementation

uses
  System.Generics.Collections, System.Generics.Defaults;

{ TBitField }

class operator TBitField.BitwiseAnd(const A, B: TBitField): TBitField;
var
  i: Integer;
begin
  Check(A, B);

  Result := TBitField.Create(A.Len);

  for i := 0 to Length(Result.FBuffer) - 1 do
    Result.FBuffer[i] := A.FBuffer[i] and B.FBuffer[i];

  Result.Validate;
end;

class operator TBitField.BitwiseXor(const A, B: TBitField): TBitField;
var
  i: Integer;
begin
  Check(A, B);

  Result := TBitField.Create(A.Len);

  for i := 0 to Length(Result.FBuffer) - 1 do
    Result.FBuffer[i] := A.FBuffer[i] xor B.FBuffer[i];

  Result.Validate;
end;

class procedure TBitField.Check(const A, B: TBitField);
begin
  if Length(A.FBuffer) <> Length(B.FBuffer) then
    raise EBitFieldDifferentLengthException.Create('BitFields are of different lengths');
end;

procedure TBitField.CheckIndex(Index: Integer);
begin
  if (Index < 0) or (Index >= FLen) then
    raise EArgumentOutOfRangeException.CreateFmt('Index out of bounds (%d)', [Index]);
end;

constructor TBitField.Create(ALength: Integer);
begin
  Assert(ALength > 0);

  FLen := ALength;
  SetLength(FBuffer, (ALength + 31) div 32);
end;

function TBitField.FirstTrue: Integer;
begin
  Result := FirstTrue(0, GetLen);
end;

function TBitField.FirstFalse: Integer;
begin
  Result := FirstFalse(0, GetLen);
end;

function TBitField.FirstFalse(AStartIndex, AEndIndex: Integer): Integer;
var
  i, j, start, fin, loopEnd: Integer;
begin
  Result := -1;

  loopEnd := Min(AEndIndex div 32, Length(FBuffer) - 1);
  for i := (AStartIndex div 32) to loopEnd do
  begin
    if FBuffer[i] = -1 then
      Continue;

    start := i     * 32;
    fin   := start + 32;

    start := IfThen(start < AStartIndex , AStartIndex , start);
    fin   := IfThen(fin   > GetLen      , GetLen      , fin);
    fin   := IfThen(fin   > AEndIndex   , AEndIndex   , fin);

    if (fin = GetLen) and (fin > 0) then
      Dec(fin);

    for j := start to fin do
      if not GetBit(j) then
        Exit(j);
  end;
end;

function TBitField.FirstTrue(AStartIndex, AEndIndex: Integer): Integer;
var
  i, j, start, fin, loopEnd: Integer;
begin
  Result := -1;

  loopEnd := Min(AEndIndex div 32, Length(FBuffer) - 1);
  for i := (AStartIndex div 32) to loopEnd do
  begin
    if FBuffer[i] = 0 then
      Continue;

    start := i     * 32;
    fin   := start + 32;

    start := IfThen(start < AStartIndex , AStartIndex , start);
    fin   := IfThen(fin   > GetLen      , GetLen      , fin);
    fin   := IfThen(fin   > AEndIndex   , AEndIndex   , fin);

    if (fin = GetLen) and (fin > 0) then
      Dec(fin);

    for j := start to fin do
      if GetBit(j) then
        Exit(j);
  end;
end;

constructor TBitField.FromUniString(const AData: TUniString);
var
  i, j, shift: Integer;
begin
  Create(AData.Len * 8);

  j := 0;
  for i := 0 to FLen div 32 - 1 do
  begin
    FBuffer[i] := (AData[j+0] shl 24) or
                  (AData[j+1] shl 16) or
                  (AData[j+2] shl 8 ) or
                  (AData[j+3] shl 0 );
    Inc(j, 4);
  end;

  shift := 24;
  i := (FLen div 32) * 32;
  while i < FLen do
  begin
    FBuffer[Length(FBuffer) - 1] := FBuffer[Length(FBuffer) - 1] or (AData[j] shl shift);

    Inc(j);
    Dec(shift, 8);
    Inc(i, 8);
  end;

  Validate;
end;

function TBitField.GetAllFalse: Boolean;
begin
  Result := FCheckedCount = 0;
end;

function TBitField.GetAllTrue: Boolean;
begin
  Result := FCheckedCount = FLen;
end;

function TBitField.GetAsUniString: TUniString;
var
  i, _end, shift: Integer;
begin
  Result.Len := 0;

  ZeroUnusedBits;

  _end := FLen div 32;
  for i := 0 to _end - 1 do
  begin
    Result := Result + Byte(FBuffer[i] shr 24);
    Result := Result + Byte(FBuffer[i] shr 16);
    Result := Result + Byte(FBuffer[i] shr 8 );
    Result := Result + Byte(FBuffer[i] shr 0 );
  end;

  shift := 24;
  i := _end * 32;
  while i < FLen do
  begin
    Result := Result + Byte(FBuffer[Length(FBuffer) - 1] shr shift);

    Dec(shift, 8);
    Inc(i, 8);
  end;
end;

function TBitField.GetBit(Index: Integer): Boolean;
begin
  CheckIndex(Index);
  Result := FBuffer[Index shr 5] and (1 shl (31 - (Index and 31))) <> 0;
end;

function TBitField.GetCheckedCount: Integer;
begin
  Result := FCheckedCount;
end;

function TBitField.GetLen: Integer;
begin
  Result := FLen;
end;

function TBitField.GetLengthInBytes: Integer;
begin
  Result := (FLen + 7) div 8; // 8 bits in a byte.
end;

class operator TBitField.LogicalNot(const A: TBitField): TBitField;
var
  i: Integer;
begin
  Result := TBitField.Create(A.Len);

  for i := 0 to Length(Result.FBuffer) - 1 do
    Result.FBuffer[i] := not A.FBuffer[i];

  Result.Validate;
end;

procedure TBitField.SetBit(Index: Integer; const Value: Boolean);
begin
  CheckIndex(Index);
  if Value then
  begin
    // If it's not already true
    if (FBuffer[Index shr 5] and (1 shl (31 - (index and 31)))) = 0 then
      Inc(FCheckedCount); // Increase true count

    FBuffer[Index shr 5] := FBuffer[Index shr 5] or (1 shl (31 - index and 31));
  end else
  begin
    // If it's not already false
    if (FBuffer[Index shr 5] and (1 shl (31 - (Index and 31)))) <> 0 then
      Dec(FCheckedCount); // Decrease true count

    FBuffer[Index shr 5] := FBuffer[Index shr 5] and not(1 shl (31 - (Index and 31)));
  end;
end;

procedure TBitField.Validate;
var
  count, v: Cardinal;
  i: Integer;
begin
  ZeroUnusedBits;

  count := 0;
  for i := 0 to Length(FBuffer) - 1 do
  begin
    v := FBuffer[i];
    v := v - ((v shr 1) and $55555555);
    v := (v and $33333333) + ((v shr 2) and $33333333);
    count := count + (((v + (v shr 4) and $F0F0F0F) * $1010101)) shr 24;
  end;

  FCheckedCount := count;
end;

procedure TBitField.ZeroUnusedBits;
var
  shift: Integer;
begin
  if Length(FBuffer) = 0 then
      Exit;

  // Zero the unused bits
  shift := 32 - FLen mod 32;
  if shift <> 0 then
    FBuffer[Length(FBuffer) - 1] := FBuffer[Length(FBuffer) - 1] and ((-1) shl shift);
end;

{ TBitSum }

constructor TBitSum.Create(ALength: Integer);
begin
  SetLength(FSum, ALength);
end;

class operator TBitSum.Add(const A, B: TBitSum): TBitSum;
var
  i: Integer;
begin
  Check(A, B);

  Result := TBitSum.Create(Max(A.Len, B.Len));

  for i := 0 to Result.Len - 1 do
  with Result do
  begin
    FSum[i] := 0;

    if i < A.Len then
      System.Inc(FSum[i], A.FSum[i]);

    if i < B.Len then
      System.Inc(FSum[i], B.FSum[i]);
  end;
end;

class operator TBitSum.Add(const A: TBitSum; B: TBitField): TBitSum;
var
  i: Integer;
begin
  //Check(A, B);
  Result := TBitSum.Create(Max(A.Len, B.Len));

  for i := 0 to Result.Len - 1 do
  with Result do
  begin
    FSum[i] := 0;

    if i < A.Len then
      System.Inc(FSum[i], A.FSum[i]);

    if i < B.Len then
      System.Inc(FSum[i], System.Math.IfThen(B[i], 1, 0));
  end;
end;

class operator TBitSum.Add(const A: TBitField; B: TBitSum): TBitSum;
var
  i: Integer;
begin
  //Check(A, B);
  Result := TBitSum.Create(Max(A.Len, B.Len));

  for i := 0 to Result.Len - 1 do
  with Result do
  begin
    FSum[i] := 0;

    if i < A.Len then
      System.Inc(FSum[i], System.Math.IfThen(A[i], 1, 0));

    if i < B.Len then
      System.Inc(FSum[i], B.FSum[i]);
  end;
end;

class procedure TBitSum.Check(const A, B: TBitSum);
begin
  if Length(A.FSum) <> Length(B.FSum) then
    raise EBitSumDifferentLengthException.Create('BitSums are of different lengths');
end;

constructor TBitSum.Create(ABitField: TBitField);
var
  i: Integer;
begin
  SetLength(FSum, ABitField.Len);
  for i := 0 to ABitField.Len - 1 do
    FSum[i] := System.Math.IfThen(ABitField[i], 1, 0)
end;

function TBitSum.GetBestPieces(AMaxCount: Integer;
  AExcludeMask: TBitField): TArray<Integer>;
const
  RandLim = 2;
var
  tmp: TList<TPair<Integer, Byte>>;
  b: Byte;
  i, j: Integer;
begin
  Assert(AExcludeMask.Len = GetLen);
  Assert(AMaxCount < GetLen);

  tmp := TList<TPair<Integer, Byte>>.Create(TDelegatedComparer<TPair<Integer, Byte>>.Create(
  function (const Left, Right: TPair<Integer, Byte>): Integer
  begin
    Result := Left.Value - Right.Value;
  end) as IComparer<TPair<Integer, Byte>>);

  try
    i := 0;
    for b in FSum do
    begin
      { проставляем только те, которые есть минимум у одного пира }
      if (not AExcludeMask[i]) and (b > 0) then
        tmp.Add(TPair<Integer, Byte>.Create(i, b));

      System.Inc(i);
    end;

    tmp.Sort;
    { выбираем рандомно }
    SetLength(Result, AMaxCount);
    FillChar(Result[0], AMaxCount, -1);

    { при первом проходе берется кусок с наименьшей суммой, т.е. самый редкий }
    i := 0;
    while (i < AMaxCount) and (tmp.Count > 0) do
    begin
      j := 0;

      while (i < AMaxCount) and (j < tmp.Count) do
      begin
        if (i = 0) or (j = 0) or (Random(RandLim) = 0) then
        begin
          Result[i] := tmp[j].Key;
          tmp.Delete(j);

          System.Inc(i);
        end else
          System.Inc(j);
      end;
    end;

    SetLength(Result, i);
  finally
    tmp.Free;
  end;
end;

function TBitSum.GetBestPieces(AMaxCount: Integer): TArray<Integer>;
var
  tmp: TBitField;
begin
  tmp := TBitField.Create(GetLen);
  //tmp.AllFalse := True;
  Result := GetBestPieces(AMaxCount, tmp);
end;

function TBitSum.GetLen: Integer;
begin
  Result := Length(FSum);
end;

function TBitSum.GetSums(Index: Integer): Byte;
begin
  Result := FSum[Index];
end;

procedure TBitSum.Inc(AIndex: Integer);
begin
  if FSum[AIndex] < 255 then
    System.Inc(FSum[AIndex]);
end;

end.
