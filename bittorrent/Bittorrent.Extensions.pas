unit Bittorrent.Extensions;

interface

uses
  System.Classes, System.SysUtils, System.Generics.Defaults,
  Spring.Collections,
  Bittorrent, Basic.Bencoding, Basic.UniString,
  Common.SortedList,
  IdGlobal;

type
  TExtensionClasses = class of TExtension;

  TExtension = class abstract(TInterfacedObject, IExtension)
  private
    function GetSupportName: string; inline;
    function GetSize: Integer; inline;
  protected
    FData: TUniString; // для кеширования результата
    procedure Decode(const AData: TUniString); virtual; abstract;
    function GetData: TUniString; virtual; abstract;
  public
    constructor Create(const AData: TUniString);

    class var SupportsList: TSortedList<string, TExtensionClasses>;
    class function GetClassSupportName: string; virtual; abstract;
    class procedure AddExtension(AExtensionClass: TExtensionClasses); inline;
    class constructor ClassCreate;
    class destructor ClassDestroy;
  end;

  TExtensionHandshake = class(TExtension, IExtensionHandshake)
  private
    const
      MaxRequests     = 250;
      MaxRequestKey   = 'reqq';
      PortKey         = 'p';
      SupportsKey     = 'm';
      VersionKey      = 'v';
      MetadataSizeKey = 'metadata_size';
      //yourip
      //ipv6
      //ipv4
  private
    FSupports: IDictionary<string, Byte>;
    FMessageDict: IBencodedDictionary;
    function GetClientVersion: string; inline;
    function GetPort: TIdPort; inline;
    function GetMetadataSize: Integer; inline;
    function GetSupports: IDictionary<string, Byte>;
  protected
    procedure Decode(const AData: TUniString); override;
    function GetData: TUniString; override;
  public
    constructor Create(AClientVersion: string; APort: TIdPort; AMetadataSize: Integer); overload;

    class function GetClassSupportName: string; override;
  end;

  TExtensionMetadata = class(TExtension, IExtensionMetadata)
  public
    const
      BlockSize       = $4000; // 16Kb
  private
    const
      ExtensionName   = 'ut_metadata';
      MessageTypeKey  = 'msg_type';
      PieceKey        = 'piece';
      TotalSizeKey    = 'total_size';
  private
    FMessageDict: IBencodedDictionary;
    FPieceData: TUniString;
    function GetMessageType: TMetadataMessageType; inline;
    function GetPiece: Integer; inline;
    function GetMetadata: TUniString; inline;
  protected
    procedure Decode(const AData: TUniString); override;
    function GetData: TUniString; override;
  public
    constructor Create(AMessageType: TMetadataMessageType;
      APiece: Integer; APieceData: TUniString); overload;
    constructor Create(AMessageType: TMetadataMessageType;
      APiece: Integer); overload;

    class function GetClassSupportName: string; override;
  end;

  TExtensionComment = class(TExtension, IExtensionComment)
  private
    const
      ExtensionName   = 'ut_comment';
      FilterKey       = 'filter';
      MessageTypeKey  = 'msg_type';
      NumKey          = 'num';
  private
    FMessageDict: IBencodedDictionary;
    function GetMessageType: TCommentMessageType; inline;
  protected
    procedure Decode(const AData: TUniString); override;
    function GetData: TUniString; override;
  public
    constructor Create(AMessageType: TCommentMessageType);

    class function GetClassSupportName: string; override;
  end;

implementation

uses
  Spring.Collections.Dictionaries;

{ TExtension }

class procedure TExtension.AddExtension(AExtensionClass: TExtensionClasses);
begin
  SupportsList.Add(AExtensionClass.GetClassSupportName, AExtensionClass);
end;

class constructor TExtension.ClassCreate;
begin
  SupportsList := TSortedList<string, TExtensionClasses>.Create(
    TDelegatedComparer<string>.Create(
      function (const Left, Right: string): Integer
      begin
        Result := CompareText(Left, Right);
      end) as IComparer<string>
  );
end;

class destructor TExtension.ClassDestroy;
begin
  SupportsList.Free;
end;

constructor TExtension.Create(const AData: TUniString);
begin
  inherited Create;

  Decode(AData);
end;

function TExtension.GetSize: Integer;
begin
  Result := GetData.Len;
end;

function TExtension.GetSupportName: string;
begin
  Result := GetClassSupportName;
end;

{ TExtensionHandshake }

constructor TExtensionHandshake.Create(AClientVersion: string;
  APort: TIdPort; AMetadataSize: Integer);
var
  i: Integer;
  supports: IBencodedDictionary;
begin
//  inherited Create;

  FMessageDict  := BencodedDictionary;
  supports      := BencodedDictionary;

  for i := 0 to TExtension.SupportsList.Count - 1 do
    supports.Add(BencodeString(TExtension.SupportsList[i].Key), BencodeInteger(i + 1));

  FMessageDict.Add(BencodeString(SupportsKey)    , supports);
  FMessageDict.Add(BencodeString(VersionKey)     , BencodeString(AClientVersion));
  FMessageDict.Add(BencodeString(PortKey)        , BencodeInteger(APort));
  FMessageDict.Add(BencodeString(MaxRequestKey)  , BencodeInteger(MaxRequests));
  FMessageDict.Add(BencodeString(MetadataSizeKey), BencodeInteger(AMetadataSize));
end;

class function TExtensionHandshake.GetClassSupportName: string;
begin
  raise Exception.Create('Cant use TExtensionHandshake as extension');
end;

function TExtensionHandshake.GetClientVersion: string;
var
  val: IBencodedString;
begin
  if FMessageDict.ContainsKey(VersionKey) then
  begin
    if Supports(FMessageDict[VersionKey], IBencodedString, val) then
      Result := val.Value
    else
      Assert(False);
  end else
    Result := 'unknown';
end;

function TExtensionHandshake.GetData: TUniString;
begin
  Result := FMessageDict.Encode;
end;

function TExtensionHandshake.GetMetadataSize: Integer;
var
  val: IBencodedInteger;
begin
  if FMessageDict.ContainsKey(MetadataSizeKey) then
  begin
    if Supports(FMessageDict[MetadataSizeKey], IBencodedInteger, val) then
      Result := val.Value
    else
    begin
      Assert(False);
      Result := 0;
    end;
  end else
    Result := 0;
end;

function TExtensionHandshake.GetPort: TIdPort;
var
  val: IBencodedInteger;
begin
  if FMessageDict.ContainsKey(PortKey) then
  begin
    if Supports(FMessageDict[PortKey], IBencodedInteger, val) then
      Result := val.Value
    else
    begin
      Assert(False);
      Result := 0;
    end;
  end else
    Result := 0;
end;

function TExtensionHandshake.GetSupports: IDictionary<string, Byte>;
var
  val: IBencodedDictionary;
  it: IBencodedValue;
begin
  if not Assigned(FSupports) then
    FSupports := TDictionary<string, Byte>.Create as IDictionary<string, Byte>;

  Result := FSupports;

  if (Result.Count = 0) and FMessageDict.ContainsKey(SupportsKey) then
  begin
    if Supports(FMessageDict[SupportsKey], IBencodedDictionary, val) then
    begin
      for it in val.Childs do
      begin
        Assert(Supports(it, IBencodeDictPair));
        with it as IBencodeDictPair do
        begin
          Assert(Supports(Key, IBencodedString));
          Assert(Supports(Value, IBencodedInteger));

          Result.Add((Key as IBencodedString).Value, (Value as IBencodedInteger).Value);
        end;
      end;
    end else
      Assert(False);
  end;
end;

procedure TExtensionHandshake.Decode(const AData: TUniString);
begin
  BencodeParse(AData, False,
    function (ALen: Integer; AValue: IBencodedValue): Boolean
    begin
      Assert(Supports(AValue, IBencodedDictionary));
      Assert((AValue as IBencodedDictionary).Childs.Count > 0);

      FMessageDict := AValue as IBencodedDictionary;

      Result := False; { stop parse }
    end);
end;

{ TExtensionMetadata }

constructor TExtensionMetadata.Create(AMessageType: TMetadataMessageType;
  APiece: Integer; APieceData: TUniString);
begin
//  inherited Create;

  FMessageDict  := BencodedDictionary;

  FPieceData.Assign(APieceData);

  FMessageDict.Add(BencodeString(MessageTypeKey), BencodeInteger(Ord(AMessageType)));
  FMessageDict.Add(BencodeString(PieceKey)      , BencodeInteger(APiece));

  if AMessageType = mmtData then
    FMessageDict.Add(BencodeString(TotalSizeKey), BencodeInteger(APieceData.Len));
end;

constructor TExtensionMetadata.Create(AMessageType: TMetadataMessageType;
  APiece: Integer);
begin
  Create(AMessageType, APiece, '');
end;

procedure TExtensionMetadata.Decode(const AData: TUniString);
begin
  BencodeParse(AData, False,
    function (ALen: Integer; AValue: IBencodedValue): Boolean
    begin
      Assert(Supports(AValue, IBencodedDictionary));
      Assert((AValue as IBencodedDictionary).Childs.Count > 0);

      FMessageDict := AValue as IBencodedDictionary;
      FPieceData := AData.Copy(ALen, AData.Len - ALen);

      Assert(FMessageDict.ContainsKey(TotalSizeKey));
      Assert(Supports(FMessageDict[TotalSizeKey], IBencodedInteger));

      Result := False; { stop parse }
    end);
end;

function TExtensionMetadata.GetData: TUniString;
begin
  Result := FMessageDict.Encode;
end;

function TExtensionMetadata.GetMessageType: TMetadataMessageType;
begin
  Assert(FMessageDict.ContainsKey(MessageTypeKey));
  Assert(Supports(FMessageDict[MessageTypeKey], IBencodedInteger));

  Result := TMetadataMessageType((FMessageDict[MessageTypeKey] as IBencodedInteger).Value);
end;

function TExtensionMetadata.GetMetadata: TUniString;
begin
  Result := FPieceData;
end;

function TExtensionMetadata.GetPiece: Integer;
begin
  Assert(FMessageDict.ContainsKey(PieceKey));
  Assert(Supports(FMessageDict[PieceKey], IBencodedInteger));

  Result := (FMessageDict[PieceKey] as IBencodedInteger).Value;
end;

class function TExtensionMetadata.GetClassSupportName: string;
begin
  Result := ExtensionName;
end;

{ TExtensionComment }

constructor TExtensionComment.Create(AMessageType: TCommentMessageType);
begin
  FMessageDict  := BencodedDictionary;
  FMessageDict.Add(BencodeString(FilterKey), BencodeString(''));
  FMessageDict.Add(BencodeString(MessageTypeKey), BencodeInteger(Ord(AMessageType)));
  FMessageDict.Add(BencodeString(NumKey), BencodeInteger(20));
end;

procedure TExtensionComment.Decode(const AData: TUniString);
begin
  Sleep(0);
end;

class function TExtensionComment.GetClassSupportName: string;
begin
  Result := ExtensionName;
end;

function TExtensionComment.GetData: TUniString;
begin
  Result := FMessageDict.Encode;
end;

function TExtensionComment.GetMessageType: TCommentMessageType;
begin
  Assert(FMessageDict.ContainsKey(MessageTypeKey));
  Assert(Supports(FMessageDict[MessageTypeKey], IBencodedInteger));

  Result := TCommentMessageType((FMessageDict[MessageTypeKey] as IBencodedInteger).Value);
end;

end.
