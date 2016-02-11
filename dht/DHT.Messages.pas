unit DHT.Messages;

interface

uses
  System.SysUtils, System.Generics.Collections, System.Generics.Defaults,
  System.Hash,
  Basic.UniString, Basic.Bencoding,
  Common.Prelude,
  DHT, DHT.NodeID,
  IdGlobal, IdStack;

type
  TMessage = class abstract(TInterfacedObject, IMessage)
  protected
    const
      IDKey             = 'id';
      TransactionIdKey  = 't';
      VersionKey        = 'v';
      MessageTypeKey    = 'y';
      DHTVersion        = 'MAD!';
  private
    function GetClientVersion: TUniString; inline;
    function GetMessageType: TUniString; inline;
    function GetTransactionID: TUniString; inline;
  protected
    FProperties: IBencodedDictionary;
    function GetID: TNodeID; virtual; abstract;
    function Encode: TUniString; virtual;

    constructor Create(AMessageType: IBencodedString;
      const ATransactionID: TUniString); reintroduce;
    constructor CreateFromDict(ADict: IBencodedDictionary);
  public
    function GetHashCode: Integer; override;
  end;

  TQueryMessages = class of TQueryMessage;

  TQueryMessage = class abstract(TMessage, IQueryMessage)
  public
    const
      QueryArgumentsKey = 'a';
      QueryNameKey      = 'q';
      QueryType         = 'q';
  protected
    function GetID: TNodeID; override;
  private
    FResponseCreator: TFunc<IBencodedDictionary, IQueryMessage, IMessage>;
    function GetResponseCreator: TFunc<IBencodedDictionary, IQueryMessage, IMessage>; inline;
    function GetParameters: IBencodedDictionary; inline;
  strict private
    class var FTransManager: TDictionary<TUniString, Word>;
    class var FTransManagerLock: TObject;
    class function AcquireTransID(const AKey: TUniString): Word; inline;
    class constructor ClassCreate;
    class destructor ClassDestroy;
  public
    class function GetQueryName: string; virtual; abstract;
    constructor CreateFromDict(ADict: IBencodedDictionary); reintroduce;
  protected
    constructor Create(const ANodeID: TNodeID; const AQueryName: TUniString;
      AResponseCreator: TFunc<IBencodedDictionary, IQueryMessage, IMessage>); reintroduce;
  end;

  TResponseMessages = class of TResponseMessage;

  TResponseMessage = class abstract(TMessage, IResponseMessage)
  protected
    const
      ReturnValuesKey = 'r';
      ResponseType    = 'r';
  private
    function GetParameters: IBencodedDictionary; inline;
    function GetQuery: IQueryMessage; inline;
  protected
    FQueryMessage: IQueryMessage;
    function GetID: TNodeID; override;
  protected
    constructor Create(const AID: TNodeID;
      const ATransactionID: TUniString); reintroduce;
    constructor CreateFromDict(ADict: IBencodedDictionary;
      AQueryMessage: IQueryMessage); reintroduce;
  end;

  TErrorMessage = class(TMessage, IErrorMessage)
  public
    const
      ErrorListKey  = 'e';
      ErrorType     = 'e';
  protected
    function GetID: TNodeID; override; final;
  private
    function GetErrorList: IBencodedList; inline;
    function GetErrorCode: TErrorCode; inline;
    function GetMessageText: string; inline;
  public
    constructor Create(AError: TErrorCode; AMessage: string;
      const ATransactionID: TUniString); reintroduce;
    constructor CreateFromDict(ADict: IBencodedDictionary); reintroduce;
  end;

  TAnnouncePeerResponse = class(TResponseMessage, IAnnouncePeerResponse)
  public
    constructor Create(const AID: TNodeID;
      const ATransactionID: TUniString); reintroduce;
    constructor CreateFromDict(ADict: IBencodedDictionary;
      AQueryMessage: IQueryMessage); reintroduce;
  end;

  TGetPeersResponse = class(TResponseMessage, IGetPeersResponse)
  private
    function GetToken: TUniString; inline;
    function GetNodes: TUniString; inline;
    function GetValues: IBencodedList; inline;
  protected
    const
      NodesKey  = 'nodes';
      TokenKey  = 'token';
      ValuesKey = 'values';
  public
    constructor Create(const ANodeID: TNodeID; const ATransactionID,
      AToken: TUniString; const ANodes, AValues: TArray<TUniString>); reintroduce;
  end;

  TFindNodeResponse = class(TResponseMessage, IFindNodeResponse)
  private
    const
      NodesKey = 'nodes';
  private
    function GetNodes: TUniString; inline;
  public
    constructor Create(const AID: TNodeID; const ATransactionID: TUniString;
      const ANodes: TArray<TUniString>); reintroduce;
  end;

  TPingResponse = class(TResponseMessage, IPingResponse)
  public
    constructor Create(const AID: TNodeID;
      const ATransactionID: TUniString); reintroduce;
  end;

  TAnnouncePeer = class(TQueryMessage, IAnnouncePeer)
  private
    const
      InfoHashKey = 'info_hash';
      QueryName   = 'announce_peer';
      PortKey     = 'port';
      TokenKey    = 'token';
  private
    function GetInfoHash: TNodeID; inline;
    function GetPort: TIdPort; inline;
    function GetToken: TUniString; inline;
  public
    class function GetQueryName: string; override;

    constructor Create(const AID, AInfoHash: TNodeID; APort: TIdPort;
      const AToken: TUniString); reintroduce;
  end;

  TFindNode = class(TQueryMessage, IFindNode)
  private
    const
      TargetKey = 'target';
      QueryName = 'find_node';
  private
    function GetTarget: TNodeID; inline;
  public
    class function GetQueryName: string; override;

    constructor Create(AID, ATarget: TNodeID); reintroduce;
  end;

  TGetPeers = class(TQueryMessage, IGetPeers)
  private
    const
      InfoHashKey = 'info_hash';
      QueryName   = 'get_peers';
  private
    function GetInfoHash: TNodeID; inline;
  public
    class function GetQueryName: string; override;

    constructor Create(AID, AInfoHash: TNodeID); reintroduce;
  end;

  TPing = class(TQueryMessage, IPing)
  private
    const
      QueryName = 'ping';
  public
    class function GetQueryName: string; override;

    constructor Create(AID: TNodeID); reintroduce;
  end;

implementation

uses
  DHT.Node;

{ TMessage }

constructor TMessage.Create(AMessageType: IBencodedString;
  const ATransactionID: TUniString);
begin
  inherited Create;

  FProperties := BencodedDictionary;
  with FProperties do
  begin
    Add(BencodeString(TransactionIdKey) , BencodeString(ATransactionID));
    Add(BencodeString(MessageTypeKey)   , AMessageType);
    Add(BencodeString(VersionKey)       , BencodeString(DHTVersion));
  end;
end;

constructor TMessage.CreateFromDict(ADict: IBencodedDictionary);
begin
  inherited Create;

  FProperties := ADict;
end;

function TMessage.Encode: TUniString;
begin
  Result := FProperties.Encode;
end;

function TMessage.GetClientVersion: TUniString;
var
  ver: IBencodedValue;
begin
  if FProperties.TryGetValue(VersionKey, ver) then
    Result := (ver as IBencodedString).Value;
end;

function TMessage.GetHashCode: Integer;
begin
  with Encode do
    Result := THashBobJenkins.GetHashValue(DataPtr[0]^, Len);
end;

function TMessage.GetMessageType: TUniString;
begin
  Result := (FProperties[MessageTypeKey] as IBencodedString).Value;
end;

function TMessage.GetTransactionID: TUniString;
begin
  if FProperties.ContainsKey(TransactionIdKey) then
    Result := (FProperties[TransactionIdKey] as IBencodedString).Value
  else
    Result := string.Empty;
end;

{ TQueryMessage }

class function TQueryMessage.AcquireTransID(const AKey: TUniString): Word;
begin
  TMonitor.Enter(FTransManagerLock);
  try
    with FTransManager do
    begin
      TryGetValue(AKey, Result);
      AddOrSetValue(AKey, Result + 1);
    end;
  finally
    TMonitor.Exit(FTransManagerLock);
  end;
end;

class constructor TQueryMessage.ClassCreate;
begin
  FTransManager := TDictionary<TUniString, Word>.Create(
    TUniStringEqualityComparer.Create
  );

  FTransManagerLock := TObject.Create;
end;

class destructor TQueryMessage.ClassDestroy;
begin
  FTransManager.Free;
  FTransManagerLock.Free;
end;

constructor TQueryMessage.Create(const ANodeID: TNodeID;
  const AQueryName: TUniString;
  AResponseCreator: TFunc<IBencodedDictionary, IQueryMessage, IMessage>);
begin
  GStack.IncUsage;
  try
    inherited Create(BencodeString(QueryType), GStack.HostToNetwork(
      AcquireTransID(ANodeID.AsUniString)));
  finally
    GStack.DecUsage;
  end;

  with FProperties do
  begin
    Add(BencodeString(QueryNameKey), BencodeString(AQueryName));
    Add(BencodeString(QueryArgumentsKey), BencodedDictionary);
  end;

  GetParameters.Add(BencodeString(IDKey), BencodeString(ANodeID.AsUniString));
  FResponseCreator := AResponseCreator;
end;

constructor TQueryMessage.CreateFromDict(ADict: IBencodedDictionary);
begin
  inherited CreateFromDict(ADict);
end;

function TQueryMessage.GetID: TNodeID;
begin
  Result := (GetParameters[IDKey] as IBencodedString).Value;
end;

function TQueryMessage.GetParameters: IBencodedDictionary;
begin
  Result := (FProperties[QueryArgumentsKey] as IBencodedDictionary);
end;

function TQueryMessage.GetResponseCreator: TFunc<IBencodedDictionary,
  IQueryMessage, IMessage>;
begin
  Result := FResponseCreator;
end;

{ TResponseMessage }

constructor TResponseMessage.Create(const AID: TNodeID;
  const ATransactionID: TUniString);
begin
  inherited Create(BencodeString(ResponseType), ATransactionID);

  FProperties.Add(BencodeString(ReturnValuesKey), BencodedDictionary);
  GetParameters.Add(BencodeString(IDKey), BencodeString(AID.AsUniString));
end;

constructor TResponseMessage.CreateFromDict(ADict: IBencodedDictionary;
  AQueryMessage: IQueryMessage);
begin
  inherited CreateFromDict(ADict);

  FQueryMessage := AQueryMessage;
end;

function TResponseMessage.GetID: TNodeID;
begin
  Result := TNodeID((GetParameters[IDKey] as IBencodedString).Value);
end;

function TResponseMessage.GetParameters: IBencodedDictionary;
begin
  Result := (FProperties[ReturnValuesKey] as IBencodedDictionary);
end;

function TResponseMessage.GetQuery: IQueryMessage;
begin
  Result := FQueryMessage;
end;

{ TErrorMessage }

constructor TErrorMessage.Create(AError: TErrorCode; AMessage: string;
  const ATransactionID: TUniString);
var
  l: IBencodedList;
begin
  inherited Create(BencodeString(ErrorType), ATransactionID);

  l := BencodedList;
  l.Add(BencodeInteger(Ord(AError)));
  l.Add(BencodeString(AMessage));

  FProperties.Add(BencodeString(ErrorListKey), l);
end;

constructor TErrorMessage.CreateFromDict(ADict: IBencodedDictionary);
begin
  inherited CreateFromDict(ADict);
end;

function TErrorMessage.GetErrorCode: TErrorCode;
begin
  Result := TErrorCode((GetErrorList.Childs[0] as IBencodedInteger).Value);
end;

function TErrorMessage.GetErrorList: IBencodedList;
begin
  Result := (FProperties[ErrorListKey] as IBencodedList);
end;

function TErrorMessage.GetID: TNodeID;
begin
  Result := TNodeID(TUniString(''));
end;

function TErrorMessage.GetMessageText: string;
begin
  Result := (GetErrorList.Childs[1] as IBencodedString).Value.AsString;
end;

{ TGetPeersResponse }

constructor TGetPeersResponse.Create(const ANodeID: TNodeID;
  const ATransactionID, AToken: TUniString;
  const ANodes, AValues: TArray<TUniString>);
begin
  inherited Create(ANodeID, ATransactionID);
  with GetParameters do
  begin
    Add(BencodeString(TokenKey), BencodeString(AToken));

    Assert((Length(ANodes) = 0) xor (Length(AValues) = 0));

    Add(BencodeString(NodesKey), BencodeString(
      TPrelude.Fold<TUniString>(ANodes, string.Empty,
        ConcatUniStringList())
      )
    );

    Add(BencodeString(ValuesKey), TPrelude.Fold<TUniString, IBencodedList>(
      AValues, BencodedList(False),
        function (X: IBencodedList; Y: TUniString): IBencodedList
        begin
          Result := X;
          Result.Add(BencodeString(Y));
        end
      )
    );
  end;
end;

function TGetPeersResponse.GetNodes: TUniString;
begin
  if GetParameters.ContainsKey(NodesKey) then
    Result := (GetParameters[NodesKey] as IBencodedString).Value
  else
    Result.Len := 0;
end;

function TGetPeersResponse.GetToken: TUniString;
var
  s: IBencodedString;
begin
  s := (GetParameters[TokenKey] as IBencodedString);
  if s = nil then
    Result := ''
  else
    Result := s.Value;
end;

function TGetPeersResponse.GetValues: IBencodedList;
begin
  if GetParameters.ContainsKey(ValuesKey) then
    Result := (GetParameters[ValuesKey] as IBencodedList)
  else
    Result := nil;
end;

{ TFindNodeResponse }

constructor TFindNodeResponse.Create(const AID: TNodeID;
  const ATransactionID: TUniString; const ANodes: TArray<TUniString>);
begin
  inherited Create(AID, ATransactionID);

  GetParameters.Add(BencodeString(NodesKey), BencodeString(
    TPrelude.Fold<TUniString>(ANodes, string.Empty,
      function (X, Y: TUniString): TUniString
      begin
        Result := X +Y;
      end)
    )
  );
end;

function TFindNodeResponse.GetNodes: TUniString;
begin
  if GetParameters.ContainsKey(NodesKey) then
    Result := (GetParameters[NodesKey] as IBencodedString).Value
  else
    Result.Len := 0;
end;

{ TAnnouncePeer }

constructor TAnnouncePeer.Create(const AID, AInfoHash: TNodeID; APort: TIdPort;
  const AToken: TUniString);
begin
  inherited Create(AID, QueryName,
    function (d: IBencodedDictionary; m: IQueryMessage): IMessage
    begin
      Result := TAnnouncePeerResponse.CreateFromDict(d, m);
    end);

  with GetParameters do // неправильная работа со словарями// бля, почему?
  begin
    Add(BencodeString(InfoHashKey), BencodeString(AInfoHash.AsUniString));
    Add(BencodeString(PortKey)    , BencodeInteger(APort));
    Add(BencodeString(TokenKey)   , BencodeString(AToken));
  end;
end;

function TAnnouncePeer.GetInfoHash: TNodeID;
begin
  Result := (GetParameters[InfoHashKey] as IBencodedString).Value;
end;

function TAnnouncePeer.GetPort: TIdPort;
begin
  Result := (GetParameters[PortKey] as IBencodedInteger).Value;
end;

class function TAnnouncePeer.GetQueryName: string;
begin
  Result := QueryName;
end;

function TAnnouncePeer.GetToken: TUniString;
begin
  Result := (GetParameters[TokenKey] as IBencodedString).Value;
end;

{ TFindNode }

constructor TFindNode.Create(AID, ATarget: TNodeID);
begin
  inherited Create(AID, QueryName,
    function (d: IBencodedDictionary; m: IQueryMessage): IMessage
    begin
      Result := TFindNodeResponse.CreateFromDict(d, m);
    end);

  GetParameters.Add(BencodeString(TargetKey), BencodeString(ATarget.AsUniString));
end;

class function TFindNode.GetQueryName: string;
begin
  Result := QueryName;
end;

function TFindNode.GetTarget: TNodeID;
begin
  Result := (GetParameters[TargetKey] as IBencodedString).Value;
end;

{ TGetPeers }

constructor TGetPeers.Create(AID, AInfoHash: TNodeID);
begin
  inherited Create(AID, QueryName,
    function (d: IBencodedDictionary; m: IQueryMessage): IMessage
    begin
      Result := TGetPeersResponse.CreateFromDict(d, m);
    end);

  GetParameters.Add(BencodeString(InfoHashKey), BencodeString(AInfoHash.AsUniString));
end;

function TGetPeers.GetInfoHash: TNodeID;
begin
  Result := (GetParameters[InfoHashKey] as IBencodedString).Value;
end;

class function TGetPeers.GetQueryName: string;
begin
  Result := QueryName;
end;

{ TPing }

constructor TPing.Create(AID: TNodeID);
begin
  inherited Create(aid, QueryName,
    function (d: IBencodedDictionary; m: IQueryMessage): IMessage
    begin
      Result := TPingResponse.CreateFromDict(d, m);
    end);
end;

class function TPing.GetQueryName: string;
begin
  Result := QueryName;
end;

{ TAnnouncePeerResponse }

constructor TAnnouncePeerResponse.Create(const AID: TNodeID;
  const ATransactionID: TUniString);
begin
  inherited Create(AID, ATransactionID);
end;

constructor TAnnouncePeerResponse.CreateFromDict(ADict: IBencodedDictionary;
  AQueryMessage: IQueryMessage);
begin
  inherited CreateFromDict(ADict, AQueryMessage);
end;

{ TPingResponse }

constructor TPingResponse.Create(const AID: TNodeID;
  const ATransactionID: TUniString);
begin
  inherited Create(AID, ATransactionID);
end;

end.
