unit Bittorrent.Extensions;

interface

uses
  System.Classes, System.SysUtils, System.Generics.Collections, System.Generics.Defaults,
  Basic.Bencoding, Basic.UniString,
  Bittorrent,
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

    class var SupportsList: TList<TPair<string, TExtensionClasses>>;
    class function GetClassSupportName: string; virtual; abstract;
    class procedure AddExtension(AExtensionClass: TExtensionClasses); inline;
    class constructor ClassCreate;
    class destructor ClassDestroy;
  end;

  TExtensionHandshake = class(TExtension, IExtensionHandshake)
  private
    const
      MaxRequests     = 255;
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
    constructor Create(const AData: TUniString); reintroduce; overload;
    constructor Create(AClientVersion: string; APort: TIdPort; AMetadataSize: Integer); overload;
    destructor Destroy; override;

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
    class constructor ClassCreate;
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

implementation

{ TExtension }

class procedure TExtension.AddExtension(AExtensionClass: TExtensionClasses);
begin
  SupportsList.Add(TPair<string, TExtensionClasses>.Create(AExtensionClass.GetClassSupportName, AExtensionClass));
end;

class constructor TExtension.ClassCreate;
begin
  SupportsList := TList<TPair<string, TExtensionClasses>>.Create(
    TDelegatedComparer<TPair<string, TExtensionClasses>>.Create(
      function (const Left, Right: TPair<string, TExtensionClasses>): Integer
      begin
        Result := Left.Key.CompareTo(Right.Key);
      end
    )
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
  Create(string.Empty);

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

function TExtensionHandshake.GetSupports: TDictionary<string, Byte>;
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

constructor TExtensionHandshake.Create(const AData: TUniString);
begin
  FSupports := TDictionary<string, Byte>.Create;

  inherited Create(AData);
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

destructor TExtensionHandshake.Destroy;
begin
  FSupports.Free;
  inherited;
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

class constructor TExtensionMetadata.ClassCreate;
begin
  TExtension.AddExtension(TExtensionMetadata);
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

end.
