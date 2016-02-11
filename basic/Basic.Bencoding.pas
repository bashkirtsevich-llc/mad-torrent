(*
 * Bencode использует ASCII символы как разделители и цифры.
 *
 * Целое число записывается так: i<число в десятичной системе счисления>e.
 *  Число не должно начинаться с нуля, но число ноль записывается как i0e.
 *  Отрицательные числа записываются со знаком минуса перед числом.
 *  Число -42 будет выглядеть так «i-42e».
 *
 * Строка байт: <размер>:<содержимое>. Размер — это число в десятичной системе
 *  счисления; Содержимое — это непосредственно данные, представленные цепочкой
 *  байт. Строка «spam» в этом формате будет выглядеть так «4:spam».
 *
 * Список (массив): l<содержимое>e . Содержимое включает в себя любые Bencode
 *  типы, следующие друг за другом. Список, состоящий из строки «spam» и числа
 *  42, будет выглядеть так: «l4:spami42ee».
 *
 * Словарь: d<содержимое>e. Содержимое состоит из пар ключ-значение, которые
 *  следуют друг за другом. Ключи могут быть только строкой байт и должны быть
 *  упорядочены в лексикографическом порядке. Значение может быть любым Bencode
 *  элементом. Если сопоставить ключам «bar» и «foo» значения «spam» и 42,
 *  получится: «d3:bar4:spam3:fooi42ee». (Если добавить пробелы между
 *  элементами, будет легче понять структуру: "d 3:bar 4:spam 3:foo i42e e".)
 *)

unit Basic.Bencoding;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, Basic.UniString,
  System.Generics.Defaults, System.Hash;

type
  {$REGION 'interfaces'}
  IBencodedValue = interface
  ['{110F833C-AE01-4788-AB81-0E443FAD0B2B}']
    function Encode: TUniString;
    function GetHashCode: Integer;
    function Equals(AOther: IBencodedValue): Boolean;

    function GetValueRaw: TUniString;
    procedure SetValueRaw(const AValue: TUniString);
  end;

  IBencodedInteger = interface(IBencodedValue)
  ['{F0B56DB4-6A73-424E-8FA6-976FDF694B10}']
    function GetValue: Int64;

    property ValueStr: TUniString read GetValueRaw;
    property Value: Int64 read GetValue;
  end;

  IBencodedString = interface(IBencodedValue)
  ['{0F10913C-ECA4-42C9-B0EA-202256D95B49}']
    property Value: TUniString read GetValueRaw;
  end;

  IBencodedList = interface(IBencodedValue)
  ['{206493D9-CC33-4FF5-92F9-C30957673566}']
    function GetChilds: TList<IBencodedValue>;
    property Childs: TList<IBencodedValue> read GetChilds;

    procedure Add(AItem: IBencodedValue);
  end;

  IBencodeDictPair = interface(IBencodedValue)
  ['{C753CE08-4ED1-43CB-BD8D-1592B242CAA6}']
    function GetKey: IBencodedValue;
    function GetValue: IBencodedValue;
    function GetHasData: Boolean;

    property HasData: Boolean read GetHasData;
    property Key: IBencodedValue read GetKey;
    property Value: IBencodedValue read GetValue;
  end;


  IBencodedDictionary = interface(IBencodedList)
  ['{4ECD9A7D-6217-4591-AEAE-6E952D9CA1A7}']
    function FindValueByKey(const AKeyName: TUniString): IBencodedValue;
    function ContainsKey(const AKeyName: TUniString): Boolean;

    function TryGetValue(const AKeyName: TUniString; out AValue: IBencodedValue): Boolean;
    procedure Add(AKey: IBencodedString; AValue: IBencodedValue);

    function GetItem(const AKeyName: TUniString): IBencodedValue;
    procedure SetItem(const AKeyName: TUniString;
      const Value: IBencodedValue);

    property Items[const AKeyName: TUniString]: IBencodedValue read GetItem write SetItem; default;
  end;

  IBencodedBase = interface(IBencodedList)
  ['{492E3209-E524-442E-A1F5-A85BBE7E7CCA}']
  end;
  {$ENDREGION}

type
  TBencodeException             = class(Exception);
  TBencodeParseToken            = class(TBencodeException);
  TBencodeParseIntegerException = class(TBencodeException);
  TBencodeParseStringException  = class(TBencodeException);
  TBencodeDictPairException     = class(TBencodeException);

function BencodeParse(AStream: TStream; ASorting: Boolean = True;
  AParseCallback: TFunc<{ last position   } Integer,
                        { parsed data     } IBencodedValue,
                        { continue parse? } Boolean> = nil): IBencodedBase; overload; inline;
function BencodeParse(const AData: TUniString; ASorting: Boolean = True;
  AParseCallback: TFunc<{ last position   } Integer,
                        { parsed data     } IBencodedValue,
                        { continue parse? } Boolean> = nil): IBencodedBase; overload;

function BencodeString(const AData: TUniString): IBencodedString; overload;
function BencodeString(const AData: string): IBencodedString; overload;

function BencodeInteger(const AData: Int64): IBencodedInteger; overload;
function BencodeInteger(AData: Word): IBencodedInteger; overload;
function BencodedList(ASorting: Boolean = True): IBencodedList;
function BencodedDictionary(ASorting: Boolean = True): IBencodedDictionary;

implementation

type
  TBencodedValue = class(TInterfacedObject, IBencodedValue)
  private
    FValueRaw: TUniString;
  protected
    FChilds: TList<IBencodedValue>;
    function GetChilds: TList<IBencodedValue>;

    function GetValueRaw: TUniString; virtual;
    procedure SetValueRaw(const AValue: TUniString); virtual;
    procedure BeforeAdd(AParent, AItem: IBencodedValue); virtual;
    function Equals(AOther: IBencodedValue): Boolean; reintroduce; virtual;
  public
    function Encode: TUniString; virtual; abstract;
    //function GetHashCode: Integer; virtual; abstract;

    constructor Create(AParent: IBencodedValue = nil);
    destructor Destroy; override;
  end;

  TBencodedInteger = class(TBencodedValue, IBencodedInteger)
  private
    FValue: Int64; // запользовать biginteger

    function GetValue: Int64;
  protected
    function Equals(AOther: IBencodedValue): Boolean; override;
  public
    function Encode: TUniString; override;
    function GetHashCode: Integer; override;

    property ValueStr: TUniString read GetValueRaw;
    property Value: Int64 read GetValue;

    constructor BencodeInteger(const AData: Int64); overload;
    constructor BencodeInteger(AData: Word); overload;
  end;

  TBencodedString = class(TBencodedValue, IBencodedString)
  protected
    function Equals(AOther: IBencodedValue): Boolean; override;
  public
    function Encode: TUniString; override;
    function GetHashCode: Integer; override;

    property Value: TUniString read GetValueRaw;

    constructor BencodeString(const AValue: string); overload;
    constructor BencodeString(const AValue: TUniString); overload;
  end;

  TBencodedList = class(TBencodedValue, IBencodedList)
  protected
    FSorting: Boolean;
    function EncodeChilds: TUniString;
    function Equals(AOther: IBencodedValue): Boolean; override;
    procedure Sorting; virtual;
  public
    function Encode: TUniString; override;
    function GetHashCode: Integer; override;

    procedure Add(AItem: IBencodedValue);

    constructor Create(ANeedSort: Boolean; AParent: IBencodedValue = nil); reintroduce;
  end;

  TBencodedDictionary = class(TBencodedList, IBencodedDictionary)
  private
    type
      TBencodeDictPair = class(TBencodedValue, IBencodeDictPair)
      private
        function GetKey: IBencodedValue;
        function GetValue: IBencodedValue;
        function GetHasData: Boolean;
      protected
        procedure BeforeAdd(AParent, AItem: IBencodedValue); override;
      public
        function Encode: TUniString; override;
        function GetHashCode: Integer; override;
      end;
  public
    function FindValueByKey(const AKeyName: TUniString): IBencodedValue;
    function ContainsKey(const AKeyName: TUniString): Boolean;
  protected
    procedure Sorting; override;
  public
    function Encode: TUniString; override;
    function TryGetValue(const AKeyName: TUniString; out AValue: IBencodedValue): Boolean;
    procedure Add(AKey: IBencodedString; AValue: IBencodedValue); reintroduce;
  private
    function GetItem(const AKeyName: TUniString): IBencodedValue;
    procedure SetItem(const AKeyName: TUniString;
      const Value: IBencodedValue);
  public
//    property Items[const AKeyName: TUniString]: TBencodedValue read GetItem write SetItem; default;
  end;

  TBencodedBase = class(TBencodedList, IBencodedBase)
  public
    function Encode: TUniString; override;
    function FindDictValueByKey(const AKeyName: TUniString): IBencodedValue;
  end;

{ TBencodeBasePersistent }

procedure TBencodedValue.BeforeAdd(AParent, AItem: IBencodedValue);
begin
end;

constructor TBencodedValue.Create(
  AParent: IBencodedValue = nil);
begin
  if AParent <> nil then
  begin
    BeforeAdd(AParent, Self);
    (AParent as TBencodedValue).FChilds.Add(Self);
  end;

  FChilds := TList<IBencodedValue>.Create;
end;

destructor TBencodedValue.Destroy;
begin
  FChilds.Free;
  inherited;
end;

function TBencodedValue.Equals(AOther: IBencodedValue): Boolean;
begin
  raise Exception.Create('"Equals" not supported on abstract object');
end;

function TBencodedValue.GetChilds: TList<IBencodedValue>;
begin
  Result := FChilds;
end;

function TBencodedValue.GetValueRaw: TUniString;
begin
  Result := FValueRaw;
end;

procedure TBencodedValue.SetValueRaw(const AValue: TUniString);
begin
  FValueRaw := AValue;
end;

{ TBencodeInteger }

constructor TBencodedInteger.BencodeInteger(const AData: Int64);
begin
  Create;

  FValueRaw := AData.ToString;
  FValue := AData;
end;

constructor TBencodedInteger.BencodeInteger(AData: Word);
begin
  Create;

  FValueRaw := AData.ToString;
  FValue := AData;
end;

function TBencodedInteger.Encode: TUniString;
begin
  Result := Format('i%se', [string(FValueRaw)]);
end;

function TBencodedInteger.Equals(AOther: IBencodedValue): Boolean;
begin
  if not Assigned(AOther) then
    Exit(False);

  Result := (AOther as TBencodedInteger).FValue = FValue;
end;

function TBencodedInteger.GetHashCode: Integer;
begin
  Result := THashBobJenkins.GetHashValue(FValue, SizeOf(Int64));
end;

function TBencodedInteger.GetValue: Int64;
begin
  Result := FValue;
end;

{ TBencodeString }

constructor TBencodedString.BencodeString(const AValue: string);
begin
  Create;

  FValueRaw := AValue;
end;

constructor TBencodedString.BencodeString(const AValue: TUniString);
begin
  Create;

  FValueRaw := AValue;
end;

function TBencodedString.Encode: TUniString;
begin
  Result := Format('%d:%s', [FValueRaw.Len, string(FValueRaw)]);
end;

function TBencodedString.Equals(AOther: IBencodedValue): Boolean;
begin
  if not Assigned(AOther) then
    Exit(False);
  Result := AOther.GetValueRaw = FValueRaw;
end;

function TBencodedString.GetHashCode: Integer;
begin
  Result := FValueRaw.GetHashCode;
end;

{ TBencodeArray }

procedure TBencodedList.Add(AItem: IBencodedValue);
begin
  FChilds.Add(AItem);
  if FSorting then
    Sorting;
end;

constructor TBencodedList.Create(ANeedSort: Boolean;
  AParent: IBencodedValue = nil);
begin
  inherited Create(AParent);
  FSorting := ANeedSort;
end;

function TBencodedList.Encode: TUniString;
begin
  if FSorting then
    Sorting;

  Result := 'l'+EncodeChilds+'e';
end;

function TBencodedList.EncodeChilds: TUniString;
var
  it: IBencodedValue;
begin
  Result := '';

  for it in FChilds do
    Result := Result + it.Encode;
end;

function TBencodedList.Equals(AOther: IBencodedValue): Boolean;
var
  i: Integer;
begin
  if not Assigned(AOther) then
    Exit(False);

  Result := ((AOther as TBencodedList).FChilds.Count = FChilds.Count);

  if Result then
    for i := 0 to FChilds.Count - 1 do
      Result := Result and (FChilds[i] as TBencodedValue).Equals(((AOther as TBencodedList).FChilds[i] as TBencodedValue));
end;

function TBencodedList.GetHashCode: Integer;
var
  it: IBencodedValue;
begin
  Result := 0;
  for it in FChilds do
    Result := Result xor it.GetHashCode;
end;

procedure TBencodedList.Sorting;
begin
  FChilds.Sort(TDelegatedComparer<IBencodedValue>.Create(
    function (const Left, Right: IBencodedValue): Integer
    var
      l, r: IBencodedValue;
    begin
      l := Left  as IBencodedValue;
      r := Right as IBencodedValue;

      Result := TUniString.Compare(l.GetValueRaw, r.GetValueRaw, False);
    end) as IComparer<IBencodedValue>
  );
end;

{ TBencodeBase }

function TBencodedBase.Encode: TUniString;
begin
  if FSorting then
    Sorting;

  Result := EncodeChilds;
end;

function TBencodedBase.FindDictValueByKey(
  const AKeyName: TUniString): IBencodedValue;
var
  it: IBencodedValue;
begin
  for it in FChilds do
    if Supports(it, IBencodedDictionary) then
    begin
      Result := (it as IBencodedDictionary).FindValueByKey(AKeyName);

      if Assigned(Result) then
        Exit;
    end;

  Result := nil;
end;

{ TBencodeDictitionary.TBencodeDictPair }

procedure TBencodedDictionary.TBencodeDictPair.BeforeAdd(AParent, AItem: IBencodedValue);
begin
  inherited;

  if AParent is TBencodeDictPair then
  begin
    if ((AParent as TBencodedValue).FChilds.Count = 0) and (not Supports(AItem, IBencodedString)) then
      raise TBencodeDictPairException.Create('Ключом может являться только строка');

    if (AParent as TBencodedValue).FChilds.Count = 2 then
      raise TBencodeDictPairException.Create('Нельзя использовать более 2-х элементов в одной паре');
  end;
end;

function TBencodedDictionary.TBencodeDictPair.Encode: TUniString;
var
  k, v: IBencodedValue;
begin
  k := GetKey;
  v := GetValue;

  Result := k.Encode; // + v.Encode;
  if Assigned(v) then
    Result := Result + v.Encode
  else
    Result := Result + '0:';
end;

function TBencodedDictionary.TBencodeDictPair.GetHasData: Boolean;
begin
  Result := FChilds.Count = 2;
end;

function TBencodedDictionary.TBencodeDictPair.GetHashCode: Integer;
var
  v: IBencodedValue;
begin
  Result := GetKey.GetHashCode;

  v := GetValue;
  if Assigned(v) then
    Result := Result xor v.GetHashCode;
end;

function TBencodedDictionary.TBencodeDictPair.GetKey: IBencodedValue;
begin
  if FChilds.Count > 0 then
    Result := FChilds[0]
  else
    Result := nil;
end;

function TBencodedDictionary.TBencodeDictPair.GetValue: IBencodedValue;
begin
  if FChilds.Count > 1 then
    Result := FChilds[1]
  else
    Result := nil;
end;

{ TBencodeDictitionary }

procedure TBencodedDictionary.Add(AKey: IBencodedString;
  AValue: IBencodedValue);
var
  it: IBencodedValue;
begin
  it := TBencodeDictPair.Create; //(Self);

  (it as TBencodedValue).FChilds.Add(AKey);
  (it as TBencodedValue).FChilds.Add(AValue);

  FChilds.Add(it);

  if FSorting then
    Sorting;
end;

function TBencodedDictionary.ContainsKey(const AKeyName: TUniString): Boolean;
var
  it, key: IBencodedValue;
begin
  for it in FChilds do
  begin
    Assert(it is TBencodeDictPair);
    key := TBencodeDictPair(it).GetKey;
    Assert(Supports(key, IBencodedString));

    if (key as IBencodedString).Value = AKeyName then
      Exit(True);
  end;

  Result := False;
end;

function TBencodedDictionary.Encode: TUniString;
begin
  if FSorting then
    Sorting;

  Result := 'd'+EncodeChilds+'e';
end;

function TBencodedDictionary.FindValueByKey(
  const AKeyName: TUniString): IBencodedValue;
var
  it, key: IBencodedValue;
begin
  for it in FChilds do
  begin
    Assert(Supports(it, IBencodeDictPair));
    key := (it as IBencodeDictPair).Key;
    Assert(Supports(key, IBencodedString));

    { зачем была приписка ".Copy(0, AKeyName.Len)"? в dht какая-то специфика? }
    if (key as IBencodedString).Value {.Copy(0, AKeyName.Len)} = AKeyName then
      Exit((it as IBencodeDictPair).Value);
  end;

  Result := nil;
end;

function TBencodedDictionary.GetItem(
  const AKeyName: TUniString): IBencodedValue;
begin
  Result := FindValueByKey(AKeyName);

//  if not Assigned(Result) then
//    raise Exception.Create('invalid key');
end;

procedure TBencodedDictionary.SetItem(const AKeyName: TUniString;
  const Value: IBencodedValue);
var
  it, key: IBencodedValue;
begin
  for it in FChilds do
  begin
    Assert(it is TBencodeDictPair);
    key := TBencodeDictPair(it).GetKey;
    Assert(Supports(key, IBencodedString));

    if (key as IBencodedString).Value = AKeyName then
    begin
      // изменяем
      TBencodeDictPair(it).FChilds[1] := Value;
      Exit;
    end;
  end;

  // добавляем
end;

procedure TBencodedDictionary.Sorting;
begin
  FChilds.Sort(TDelegatedComparer<IBencodedValue>.Create(
    function (const Left, Right: IBencodedValue): Integer
    var
      l, r: IBencodedString;
    begin
      Assert(Supports((Left  as IBencodeDictPair).Key, IBencodedString), 'key is not bencoded string');
      Assert(Supports((Right as IBencodeDictPair).Key, IBencodedString), 'key is not bencoded string');

      l := (Left   as IBencodeDictPair).Key as IBencodedString;
      r := (Right  as IBencodeDictPair).Key as IBencodedString;

      Result := TUniString.Compare(l.Value, r.Value, False);
    end) as IComparer<IBencodedValue>
  );
end;

function TBencodedDictionary.TryGetValue(const AKeyName: TUniString;
  out AValue: IBencodedValue): Boolean;
begin
  AValue := FindValueByKey(AKeyName);
  Result := Assigned(AValue);
end;

{ TBencode }

function BencodeParse(AStream: TStream; ASorting: Boolean = True;
  AParseCallback: TFunc<Integer, IBencodedValue, Boolean> = nil): IBencodedBase;
var
  data: TUniString;
begin
  data.Len := AStream.Size;
  AStream.Position := 0;

  AStream.Read(data.DataPtr[0]^, AStream.Size);

  Result := BencodeParse(data, ASorting, AParseCallback);
end;

function BencodeParse(const AData: TUniString; ASorting: Boolean = True;
  AParseCallback: TFunc<Integer, IBencodedValue, Boolean> = nil): IBencodedBase;

  function IsDigits(AChar: Byte; AUseMinus: Boolean = True): Boolean;
  begin
    if AUseMinus then
      Result := AChar in [{'-'}$2d, {'0'..'9'}$30..$39]
    else
      Result := AChar in [{'0'..'9'}$30..$39]
  end;

  procedure Parse(const AData: TUniString; var I: Integer;
    const AParent: IBencodedValue); forward;

  procedure ParseInteger(const AData: TUniString; var I: Integer;
    const AParent: IBencodedValue);
  var
    buff: TUniString;
    reslt: IBencodedInteger;
  begin
    buff.Len := 0;

    Inc(I);
    while Byte(AData[I]) <> $65 {'e'} do
    begin
      // проверки
      if IsDigits(AData[I], buff.Len = 0) then
        buff := buff + AData[I]
      else
        raise TBencodeParseIntegerException.CreateFmt('Invalid number format "%s"',
          [ string(buff + AData[I]) ]);

      Inc(I);
    end;
    Inc(I); //???

    if (buff.Len > 1) and (buff[0] = {'0'}$30) then
      raise TBencodeParseIntegerException.Create('Number can not be start from zero');

    reslt := TBencodedInteger.Create(AParent);
    (reslt as TBencodedInteger).FValueRaw := buff;
    (reslt as TBencodedInteger).FValue := StrToInt64Def(buff, 0);
  end;

  procedure ParseArray(const AData: TUniString; var I: Integer;
    const AParent: IBencodedValue);
  var
    reslt: IBencodedList;
  begin
    reslt := TBencodedList.Create(ASorting, AParent);

    Inc(I);
    while AData[I] <> {'e'}$65 do
      Parse(AData, I, reslt);

    Inc(I);
  end;

  procedure ParseString(const AData: TUniString; var I: Integer;
    const AParent: IBencodedValue);
  var
    reslt: IBencodedString;
    buff: TUniString;
  len: Integer;
  begin
    buff.Len := 0;

    while AData[I] <> {':'}$3a do
    begin
      // проверки
      if IsDigits(AData[I], buff.Len = 0) then
        buff := buff + AData[I]
      else
        raise TBencodeParseIntegerException.CreateFmt('Invalid number format "%s"',
          [string(buff + AData[I])]);
      Inc(I);
    end;

    Inc(I);

    len := StrToIntDef(buff, 0);
    reslt := TBencodedString.Create(AParent);

    buff.Len := 0;

    while len <> 0 do
    begin
      buff := buff + AData[I];

      Inc(I); Dec(len);
    end;

    reslt.SetValueRaw(buff);
  end;

  procedure ParseDict(const AData: TUniString; var I: Integer;
    const AParent: IBencodedValue);
  var
    reslt: IBencodedDictionary;
    pair: IBencodeDictPair;
  begin
    reslt := TBencodedDictionary.Create(ASorting, AParent);

    Inc(I);
    while AData[I] <> {'e'}$65 do
    begin
      pair := TBencodedDictionary.TBencodeDictPair.Create(reslt);

      while not pair.HasData do
        Parse(AData, I, pair);
    end;

    Inc(I);
  end;

  procedure Parse(const AData: TUniString; var I: Integer;
    const AParent: IBencodedValue);
  begin
    case Char(AData[i]) of
      'i'     : ParseInteger (AData, I, AParent);
      'l'     : ParseArray   (AData, I, AParent);
      'd'     : ParseDict    (AData, I, AParent);
      '0'..'9': ParseString  (AData, I, AParent);
//      $69     : ParseInteger (AData, I, AParent);
//      $6c     : ParseArray   (AData, I, AParent);
//      $64     : ParseDict    (AData, I, AParent);
//      $30..$39: ParseString  (AData, I, AParent);
    else
      raise TBencodeParseToken.CreateFmt('Unknown token "%s"', [Char(AData[i])]);
    end;
  end;

var
  i: Integer;
begin
  if AData.Len = 0 then
    Exit(nil);

  Result := TBencodedBase.Create(ASorting);

  i := 0;
  while i < AData.Len do
  begin
    Parse(AData, i, Result);

    Assert(Result.Childs.Count > 0);
    if Assigned(AParseCallback) and not AParseCallback(i, Result.Childs.Last) then
      Break;
  end;
end;

function BencodeString(const AData: TUniString): IBencodedString; overload;
begin
  Result := TBencodedString.BencodeString(AData);
end;

function BencodeString(const AData: string): IBencodedString; overload;
begin
  Result := TBencodedString.BencodeString(AData);
end;

function BencodeInteger(const AData: Int64): IBencodedInteger;
begin
  Result := TBencodedInteger.BencodeInteger(AData);
end;

function BencodeInteger(AData: Word): IBencodedInteger; overload;
begin
  Result := TBencodedInteger.BencodeInteger(AData);
end;

function BencodedList(ASorting: Boolean = True): IBencodedList;
begin
  Result := TBencodedList.Create(ASorting) as IBencodedList;
end;

function BencodedDictionary(ASorting: Boolean = True): IBencodedDictionary;
begin
  Result := TBencodedDictionary.Create(ASorting) as IBencodedDictionary;
end;

end.
