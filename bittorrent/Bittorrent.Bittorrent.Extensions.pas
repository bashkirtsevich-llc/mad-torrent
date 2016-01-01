unit Shareman.Bittorrent.Extensions;

interface

uses
  System.Classes, System.SysUtils, System.Generics.Collections, System.Generics.Defaults,
  Shareman.Bittorrent, Basic.Bencoding, Basic.UniString,
  IdGlobal;

type
  TBTExtensionClasses = class of TBTExtension;

  TBTExtension = class abstract(TInterfacedObject, IBTExtension)
  private
    function GetSupportName: string; inline;
    function GetSize: Integer; inline;
  protected
    FData: TUniString; // для кеширования результата
    procedure Decode(const AData: TUniString); virtual; abstract;
    function GetData: TUniString; virtual; abstract;
  public
    constructor Create(const AData: TUniString);

    class var SupportsList: TList<TPair<string, TBTExtensionClasses>>;
    class function GetClassSupportName: string; virtual; abstract;
    class procedure AddExtension(AExtensionClass: TBTExtensionClasses); inline;
    class constructor ClassCreate;
    class destructor ClassDestroy;
  end;

  TBTExtensionHandshake = class(TBTExtension, IBTExtensionHandshake)
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
    FSupports: TDictionary<string, Byte>;
    FMessageDict: IBencodedDictionary;
    function GetClientVersion: string; inline;
    function GetPort: TIdPort; inline;
    function GetMetadataSize: Integer; inline;
    function GetSupports: TDictionary<string, Byte>;
  protected
    procedure Decode(const AData: TUniString); override;
    function GetData: TUniString; override;
  public
    constructor Create(AClientVersion: string; APort: TIdPort; AMetadataSize: Integer); overload;
    destructor Destroy; override;

    class function GetClassSupportName: string; override;
  end;

  TBTExtensionMetadata = class(TBTExtension, IBTExtensionMetadata)
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
    function GetMessageType: TBTMetadataMessageType; inline;
    function GetPiece: Integer; inline;
    function GetMetadata: TUniString; inline;
  protected
    procedure Decode(const AData: TUniString); override;
    function GetData: TUniString; override;
  public
    constructor Create(AMessageType: TBTMetadataMessageType;
      APiece: Integer; APieceData: TUniString); overload;
    constructor Create(AMessageType: TBTMetadataMessageType;
      APiece: Integer); overload;

    class function GetClassSupportName: string; override;
  end;

implementation

{ TBTExtension }

class procedure TBTExtension.AddExtension(AExtensionClass: TBTExtensionClasses);
begin
  SupportsList.Add(TPair<string, TBTExtensionClasses>.Create(AExtensionClass.GetClassSupportName, AExtensionClass));
end;

class constructor TBTExtension.ClassCreate;
begin
  SupportsList := TList<TPair<string, TBTExtensionClasses>>.Create(
    TDelegatedComparer<TPair<string, TBTExtensionClasses>>.Create(
      function (const Left, Right: TPair<string, TBTExtensionClasses>): Integer
      begin
        Result := Left.Key.CompareTo(Right.Key);
      end
    )
  );
end;

class destructor TBTExtension.ClassDestroy;
begin
  SupportsList.Free;
end;

constructor TBTExtension.Create(const AData: TUniString);
begin
  inherited Create;

  Decode(AData);
end;

function TBTExtension.GetSize: Integer;
begin
  Result := GetData.Len;
end;

function TBTExtension.GetSupportName: string;
begin
  Result := GetClassSupportName;
end;

{ TBTExtensionHandshake }

constructor TBTExtensionHandshake.Create(AClientVersion: string;
  APort: TIdPort; AMetadataSize: Integer);
var
  i: Integer;
  supports: IBencodedDictionary;
begin
//  inherited Create;

  FSupports := TDictionary<string, Byte>.Create;

  FMessageDict  := BencodedDictionary;
  supports      := BencodedDictionary;

  for i := 0 to TBTExtension.SupportsList.Count - 1 do
    supports.Add(BencodeString(TBTExtension.SupportsList[i].Key), BencodeInteger(i + 1));

  FMessageDict.Add(BencodeString(SupportsKey)    , supports);
  FMessageDict.Add(BencodeString(VersionKey)     , BencodeString(AClientVersion));
  FMessageDict.Add(BencodeString(PortKey)        , BencodeInteger(APort));
  FMessageDict.Add(BencodeString(MaxRequestKey)  , BencodeInteger(MaxRequests));
  FMessageDict.Add(BencodeString(MetadataSizeKey), BencodeInteger(AMetadataSize));
end;

class function TBTExtensionHandshake.GetClassSupportName: string;
begin
  raise Exception.Create('Cant use TExtensionHandshake as extension');
end;

function TBTExtensionHandshake.GetClientVersion: string;
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

function TBTExtensionHandshake.GetData: TUniString;
begin
  Result := FMessageDict.Encode;
end;

function TBTExtensionHandshake.GetMetadataSize: Integer;
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

function TBTExtensionHandshake.GetPort: TIdPort;
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

function TBTExtensionHandshake.GetSupports: TDictionary<string, Byte>;
var
  val: IBencodedDictionary;
  it: IBencodedValue;
begin
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

procedure TBTExtensionHandshake.Decode(const AData: TUniString);
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

destructor TBTExtensionHandshake.Destroy;
begin
  FSupports.Free;
  inherited;
end;

{ TBTExtensionMetadata }

constructor TBTExtensionMetadata.Create(AMessageType: TBTMetadataMessageType;
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

constructor TBTExtensionMetadata.Create(AMessageType: TBTMetadataMessageType;
  APiece: Integer);
begin
  Create(AMessageType, APiece, '');
end;

procedure TBTExtensionMetadata.Decode(const AData: TUniString);
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

function TBTExtensionMetadata.GetData: TUniString;
begin
  Result := FMessageDict.Encode;
end;

function TBTExtensionMetadata.GetMessageType: TBTMetadataMessageType;
begin
  Assert(FMessageDict.ContainsKey(MessageTypeKey));
  Assert(Supports(FMessageDict[MessageTypeKey], IBencodedInteger));

  Result := TBTMetadataMessageType((FMessageDict[MessageTypeKey] as IBencodedInteger).Value);
end;

function TBTExtensionMetadata.GetMetadata: TUniString;
begin
  Result := FPieceData;
end;

function TBTExtensionMetadata.GetPiece: Integer;
begin
  Assert(FMessageDict.ContainsKey(PieceKey));
  Assert(Supports(FMessageDict[PieceKey], IBencodedInteger));

  Result := (FMessageDict[PieceKey] as IBencodedInteger).Value;
end;

class function TBTExtensionMetadata.GetClassSupportName: string;
begin
  Result := ExtensionName;
end;

end.
