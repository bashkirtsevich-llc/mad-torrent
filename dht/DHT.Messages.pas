unit DHT.Messages;

interface

uses
  System.SysUtils, System.Generics.Defaults,
  Basic.UniString, Basic.Bencoding,
  DHT.Engine, DHT.NodeID,
  IdGlobal;

type
  TMessage = class(TInterfacedObject, IMessage)
  protected
    const
      //EmptyString       = '';
      IDKey             = 'id';
      TransactionIdKey  = 't';
      VersionKey        = 'v';
      MessageTypeKey    = 'y';
      DHTVersion        = 'SHAR';
  protected
    FProperties: IBencodedDictionary;
    FSequenceID: UInt64;
    function GetID: TNodeID; virtual; abstract;
  private
    class var FGlobalSequenceID: UInt64;
  private
    function GetClientVersion: TUniString; inline;
    function GetMessageType: TUniString; inline;
    function GetTransactionID: IBencodedValue; inline;
    procedure SetTransactionId(const Value: IBencodedValue); inline;
    function GetSequenceID: UInt64; inline;
  public
    function Encode: TUniString; virtual;

    procedure Handle(AEngine: TDHTEngine; ANode: INode); virtual;
    function GetHashCode: Integer; override;

    constructor Create(AMessageType: IBencodedString); overload;
    constructor Create(ADictionary: IBencodedDictionary); overload;
    destructor Destroy; override;
  end;

  TQueryMessage = class(TMessage, IQueryMessage)
  public
    const
      QueryArgumentsKey = 'a';
      QueryNameKey      = 'q';
      QueryType         = 'q';
  protected
    function GetID: TNodeID; override;
  private
    FResponseCreator: TResponseCreator;
    function GetResponseCreator: TResponseCreator; inline;
    function GetParameters: IBencodedDictionary;
  public
    constructor Create(ANodeID: TNodeID; AQueryName: TUniString;
      AResponseCreator: TResponseCreator); overload;

    constructor Create(ANodeID: TNodeID; AQueryName: TUniString;
      AQueryArguments: IBencodedDictionary; AResponseCreator: TResponseCreator); overload;

    constructor Create(ADict: IBencodedDictionary; AResponseCreator: TResponseCreator); overload;
  end;

  TResponseMessage = class(TMessage, IResponseMessage)
  protected
    const
      ReturnValuesKey = 'r';
      ResponseType    = 'r';
  private
    function GetParameters: IBencodedDictionary;
    function GetQuery: IQueryMessage; inline;
  protected
    FQueryMessage: IQueryMessage;
    function GetID: TNodeID; override;
  public
    constructor Create(AID: TNodeID; ATransactionId: IBencodedValue); overload;
    constructor Create(ADict: IBencodedDictionary; AMsg: IQueryMessage); overload;
  end;

  TErrorMessage = class(TMessage, IErrorMessage)
  public
    const
      ErrorListKey  = 'e';
      ErrorType     = 'e';
  protected
    function GetID: TNodeID; override;
  private
    function GetErrorList: IBencodedList;
    function GetErrorCode: TErrorCode;
    function GetMessageText: string;
  public
    procedure Handle(AEngine: TDHTEngine; ANode: INode); override;

    constructor Create(AError: TErrorCode; AMessage: string); overload;
  end;

  TAnnouncePeerResponse = class(TResponseMessage, IAnnouncePeerResponse)
  end;

  TGetPeersResponse = class(TResponseMessage, IGetPeersResponse)
  private
    function GetToken: TUniString; inline;
    procedure SetToken(const Value: TUniString); inline;
    function GetNodes: TUniString; inline;
    procedure SetNodes(const Value: TUniString); inline;
    function GetValues: IBencodedList; inline;
    procedure SetValues(const Value: IBencodedList); inline;
  protected
    const
      NodesKey  = 'nodes';
      TokenKey  = 'token';
      ValuesKey = 'values';
  public
    procedure Handle(AEngine: TDHTEngine; ANode: INode); override;

    constructor Create(ANodeID: TNodeID; ATransactionID: IBencodedValue;
      AToken: TUniString); reintroduce; overload;
  end;

  TFindNodeResponse = class(TResponseMessage, IFindNodeResponse)
  private
    const
      NodesKey = 'nodes';
  private
    function GetNodes: IBencodedString;
    procedure SetNodes(const Value: IBencodedString);
  public
    procedure Handle(AEngine: TDHTEngine; ANode: INode); override;

    constructor Create(AID: TNodeID; AtransactionId: IBencodedValue); overload;
  end;

  TPingResponse = class(TResponseMessage, IPingResponse)
  end;

  TAnnouncePeer = class(TQueryMessage, IAnnouncePeer)
  private
    const
      InfoHashKey = 'info_hash';
      QueryName   = 'announce_peer';
      PortKey     = 'port';
      TokenKey    = 'token';
  private
    class var FResponseCreator: TResponseCreator;
    class constructor ClassCreate;
    class destructor ClassDestroy;

    function GetInfoHash: TNodeID;
    function GetPort: TIdPort;
    function GetToken: TUniString;
  public
    procedure Handle(AEngine: TDHTEngine; ANode: INode); override;

    constructor Create(AID, AInfoHash: TNodeID; APort: TIdPort; const AToken: TUniString); overload;
    constructor Create(ADict: IBencodedDictionary); overload;
  end;

  TFindNode = class(TQueryMessage, IFindNode)
  private
    const
      TargetKey = 'target';
      QueryName = 'find_node';
  private
    class var FResponseCreator: TResponseCreator;
    class constructor ClassCreate;
    class destructor ClassDestroy;

    function GetTarget: TNodeID;
  public
    procedure Handle(AEngine: TDHTEngine; ANode: INode); override;

    constructor Create(AID, ATarget: TNodeID); overload;
    constructor Create(ADict: IBencodedDictionary); overload;
  end;

  TGetPeers = class(TQueryMessage, IGetPeers)
  private
    const
      InfoHashKey = 'info_hash';
      QueryName   = 'get_peers';
  private
    class var FResponseCreator: TResponseCreator;
    class constructor ClassCreate;
    class destructor ClassDestroy;

    function GetInfoHash: TNodeID;
  public
    procedure Handle(AEngine: TDHTEngine; ANode: INode); override;

    constructor Create(AID, AInfoHash: TNodeID); overload;
    constructor Create(ADict: IBencodedDictionary); overload;
  end;

  TPing = class(TQueryMessage, IPing)
  private
    const
      QueryName = 'ping';
  private
    class var FResponseCreator: TResponseCreator;
    class constructor ClassCreate;
    class destructor ClassDestroy;
  public
    constructor Create(AID: TNodeID); overload;
    constructor Create(ADict: IBencodedDictionary); overload;
    procedure Handle(AEngine: TDHTEngine; ANode: INode); override;
  end;

implementation

uses
  DHT.Node;

{ TMessage }

constructor TMessage.Create(AMessageType: IBencodedString);
begin
  Create(BencodedDictionary);

  FProperties.Add(BencodeString(TransactionIdKey), nil);
  FProperties.Add(BencodeString(MessageTypeKey), AMessageType);
  FProperties.Add(BencodeString(VersionKey), BencodeString(DHTVersion));
end;

constructor TMessage.Create(ADictionary: IBencodedDictionary);
begin
  inherited Create;

  FProperties := ADictionary;

  FSequenceID := AtomicIncrement(FGlobalSequenceID);
end;

destructor TMessage.Destroy;
begin
  {stub}
  inherited;
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
var
  data: TUniString;
begin
  data := Encode;
  Result := BobJenkinsHash(data.DataPtr[0]^, data.Len, 0);
end;

function TMessage.GetMessageType: TUniString;
begin
  Result := (FProperties[MessageTypeKey] as IBencodedString).Value;
end;

function TMessage.GetSequenceID: UInt64;
begin
  Result := FSequenceID;
end;

function TMessage.GetTransactionID: IBencodedValue;
begin
  Result := FProperties[TransactionIdKey];
end;

procedure TMessage.Handle(AEngine: TDHTEngine; ANode: INode);
begin
  ANode.Seen;
end;

procedure TMessage.SetTransactionId(const Value: IBencodedValue);
begin
  FProperties[TransactionIdKey] := Value;
end;

{ TQueryMessage }

constructor TQueryMessage.Create(ANodeID: TNodeID; AQueryName: TUniString;
  AQueryArguments: IBencodedDictionary; AResponseCreator: TResponseCreator);
begin
  inherited Create(BencodeString(QueryType));
  FProperties.Add(BencodeString(QueryNameKey),
                  BencodeString(AQueryName));

  FProperties.Add(BencodeString(QueryArgumentsKey), AQueryArguments);

  GetParameters.Add(BencodeString(IDKey), BencodeString(ANodeID.AsUniString));
  FResponseCreator := AResponseCreator;
end;

constructor TQueryMessage.Create(ANodeID: TNodeID; AQueryName: TUniString;
  AResponseCreator: TResponseCreator);
begin
  Create(ANodeID, AQueryName, BencodedDictionary(), AResponseCreator);
end;

constructor TQueryMessage.Create(ADict: IBencodedDictionary;
  AResponseCreator: TResponseCreator);
begin
  inherited Create(ADict);

  FResponseCreator := AResponseCreator;
end;

function TQueryMessage.GetID: TNodeID;
begin
  Result := (GetParameters[IDKey] as IBencodedString).Value;
end;

function TQueryMessage.GetParameters: IBencodedDictionary;
begin
  Result := (FProperties[QueryArgumentsKey] as IBencodedDictionary);
end;

function TQueryMessage.GetResponseCreator: TResponseCreator;
begin
  Result := FResponseCreator;
end;

{ TResponseMessage }

constructor TResponseMessage.Create(AID: TNodeID; ATransactionId: IBencodedValue);
begin
  inherited Create(BencodeString(ResponseType));

  FProperties.Add(BencodeString(ReturnValuesKey), BencodedDictionary);
  GetParameters.Add(BencodeString(IDKey), BencodeString(AID.AsUniString));
  SetTransactionId(ATransactionId);
end;

constructor TResponseMessage.Create(ADict: IBencodedDictionary;
  AMsg: IQueryMessage);
begin
  inherited Create(ADict);

  FQueryMessage := AMsg;
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

constructor TErrorMessage.Create(AError: TErrorCode; AMessage: string);
var
  l: IBencodedList;
begin
  inherited Create(BencodeString(ErrorType));

  l := BencodedList;
  l.Add(BencodeInteger(Ord(AError)));
  l.Add(BencodeString(AMessage));

  FProperties.Add(BencodeString(ErrorListKey), l);
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

procedure TErrorMessage.Handle(AEngine: TDHTEngine; ANode: INode);
begin
  inherited Handle(AEngine, ANode);
  raise EErrorMessage.Create(GetMessageText);
end;

{ TGetPeersResponse }

constructor TGetPeersResponse.Create(ANodeID: TNodeID;
  ATransactionID: IBencodedValue; AToken: TUniString);
begin
  inherited Create(ANodeID, ATransactionID);
  GetParameters.Add(BencodeString(TokenKey), BencodeString(AToken));
end;

function TGetPeersResponse.GetNodes: TUniString;
begin
  if GetParameters.ContainsKey(NodesKey) then
    Result := (GetParameters[NodesKey] as IBencodedString).Value
  else
    Result := '';
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

procedure TGetPeersResponse.Handle(AEngine: TDHTEngine; ANode: INode);
begin
  inherited Handle(AEngine, ANode);
  ANode.Token := GetToken.Copy;
  if GetNodes.Len > 0 then
    AEngine.Add(TNode.FromCompactNode(GetNodes));
end;

procedure TGetPeersResponse.SetNodes(const Value: TUniString);
begin
  if GetParameters.ContainsKey(ValuesKey) then
    raise EGetPeersResponse.Create('Already contains the values key');

  if not GetParameters.ContainsKey(NodesKey) then
    GetParameters.Add(BencodeString(NodesKey), nil);

  GetParameters[NodesKey] := BencodeString(value);
end;

procedure TGetPeersResponse.SetToken(const Value: TUniString);
begin
  GetParameters[TokenKey] := BencodeString(Value);
end;

procedure TGetPeersResponse.SetValues(const Value: IBencodedList);
begin
  if GetParameters.ContainsKey(NodesKey) then
    raise EGetPeersResponse.Create('Already contains the nodes key');

  if not GetParameters.ContainsKey(ValuesKey) then
    GetParameters.Add(BencodeString(ValuesKey), Value)
  else
    GetParameters[ValuesKey] := Value;
end;

{ TFindNodeResponse }

constructor TFindNodeResponse.Create(AID: TNodeID;
  AtransactionId: IBencodedValue);
begin
  inherited Create(AID, AtransactionId);

  GetParameters.Add(BencodeString(NodesKey), BencodeString(''));
end;

function TFindNodeResponse.GetNodes: IBencodedString;
begin
  Result := (GetParameters[NodesKey] as IBencodedString);
end;

procedure TFindNodeResponse.Handle(AEngine: TDHTEngine; ANode: INode);
var
  n: IBencodedString;
begin
  inherited Handle(AEngine, ANode);
  n := GetNodes;
  //Assert(Assigned(n), 'Nodes not defined');
  if Assigned(n) then
    AEngine.Add(TNode.FromCompactNode(n.Value));
end;

procedure TFindNodeResponse.SetNodes(const Value: IBencodedString);
begin
  GetParameters[NodesKey] := Value;
end;

{ TAnnouncePeer }

class constructor TAnnouncePeer.ClassCreate;
begin
  FResponseCreator := function (d: IBencodedDictionary; m: IQueryMessage): IMessage
  begin
    Result := TAnnouncePeerResponse.Create(d, m);
  end;
end;

constructor TAnnouncePeer.Create(AID, AInfoHash: TNodeID; APort: TIdPort;
  const AToken: TUniString);
begin
  inherited Create(AID, QueryName, TAnnouncePeer.FResponseCreator);
  // неправильная работа со словарями
  GetParameters.Add(BencodeString(InfoHashKey), BencodeString(AInfoHash.AsUniString));
  GetParameters.Add(BencodeString(PortKey)    , BencodeInteger(APort));
  GetParameters.Add(BencodeString(TokenKey)   , BencodeString(AToken));
end;

class destructor TAnnouncePeer.ClassDestroy;
begin
  FResponseCreator := nil;
end;

constructor TAnnouncePeer.Create(ADict: IBencodedDictionary);
begin
  inherited Create(ADict, TAnnouncePeer.FResponseCreator);
end;

function TAnnouncePeer.GetInfoHash: TNodeID;
begin
  // пример: d1:ad2:id20:abcdefghij01234567899:info_hash20:mnopqrstuvwxyz1234564:porti6881e5:token8:aoeusnthe1:q13:announce_peer1:t2:aa1:y1:qe
  // не забыть про «implied_port»
  Result := (GetParameters[InfoHashKey] as IBencodedString).Value;
end;

function TAnnouncePeer.GetPort: TIdPort;
begin
  Result := (GetParameters[PortKey] as IBencodedInteger).Value;
end;

function TAnnouncePeer.GetToken: TUniString;
begin
  Result := (GetParameters[TokenKey] as IBencodedString).Value;
end;

procedure TAnnouncePeer.Handle(AEngine: TDHTEngine; ANode: INode);
var
  response: IMessage;
begin
  inherited Handle(AEngine, ANode);

  if not AEngine.Torrents.ContainsKey(GetInfoHash) then
    AEngine.Torrents.Add(GetInfoHash, TGenList<INode>.Create);

  if AEngine.TokenManager.VerifyToken(ANode, GetToken) then
  begin
    AEngine.Torrents[GetInfoHash].Add(ANode);

    response := TAnnouncePeerResponse.Create(AEngine.RoutingTable.LocalNode.ID, GetTransactionID);
  end else
    response := TErrorMessage.Create(ProtocolError, 'Invalid or expired token received');

  AEngine.MessageLoop.EnqueueSend(response, ANode.EndPoint);
end;

{ TFindNode }

class constructor TFindNode.ClassCreate;
begin
  FResponseCreator := function (d: IBencodedDictionary; m: IQueryMessage): IMessage
  begin
    Result := TFindNodeResponse.Create(d, m);
  end;
end;

constructor TFindNode.Create(AID, ATarget: TNodeID);
begin
  inherited Create(AID, QueryName, TFindNode.FResponseCreator);
  GetParameters.Add(BencodeString(TargetKey), BencodeString(ATarget.AsUniString));
end;

class destructor TFindNode.ClassDestroy;
begin
  FResponseCreator := nil;
end;

constructor TFindNode.Create(ADict: IBencodedDictionary);
begin
  inherited Create(ADict, TFindNode.FResponseCreator);
end;

function TFindNode.GetTarget: TNodeID;
begin
  Result := (GetParameters[TargetKey] as IBencodedString).Value;
end;

procedure TFindNode.Handle(AEngine: TDHTEngine; ANode: INode);
var
  response: IFindNodeResponse;
  targetNode: INode;
begin
  inherited Handle(AEngine, ANode);

  response := TFindNodeResponse.Create(AEngine.RoutingTable.LocalNode.ID, GetTransactionID);

  targetNode := AEngine.RoutingTable.FindNode(GetTarget);
  if Assigned(targetNode) then
    response.Nodes := BencodeString(targetNode.CompactNode)
  else
    response.Nodes := BencodeString(TNode.CompactNode(AEngine.RoutingTable.GetClosest(GetTarget)));

  AEngine.MessageLoop.EnqueueSend(response, ANode.EndPoint);
end;

{ TGetPeers }

class constructor TGetPeers.ClassCreate;
begin
  FResponseCreator := function (d: IBencodedDictionary; m: IQueryMessage): IMessage
  begin
    Result := TGetPeersResponse.Create(d, m);
  end;
end;

constructor TGetPeers.Create(AID, AInfoHash: TNodeID);
begin
  inherited Create(AID, QueryName, TGetPeers.FResponseCreator);

  GetParameters.Add(BencodeString(InfoHashKey), BencodeString(AInfoHash.AsUniString));
end;

class destructor TGetPeers.ClassDestroy;
begin
  FResponseCreator := nil;
end;

constructor TGetPeers.Create(ADict: IBencodedDictionary);
begin
  inherited Create(ADict, TGetPeers.FResponseCreator);
end;

function TGetPeers.GetInfoHash: TNodeID;
begin
  Result := (GetParameters[InfoHashKey] as IBencodedString).Value;
end;

procedure TGetPeers.Handle(AEngine: TDHTEngine; ANode: INode);
var
  token: TUniString;
  response: IGetPeersResponse;
  list: IBencodedList;
  n: INode;
begin
  inherited Handle(AEngine, ANode);

  token := AEngine.TokenManager.GenerateToken(ANode);
  response := TGetPeersResponse.Create(AEngine.RoutingTable.LocalNode.Id, GetTransactionID, token);

  if AEngine.Torrents.ContainsKey(GetInfoHash) then
  begin
    list := BencodedList;

    for n in AEngine.Torrents[GetInfoHash] do
      list.Add(BencodeString(n.CompactPort));

    response.Values := list;
  end else
    response.Nodes := TNode.CompactNode(AEngine.RoutingTable.GetClosest(GetInfoHash));

  AEngine.MessageLoop.EnqueueSend(response, ANode.EndPoint);
end;

{ TPing }

class constructor TPing.ClassCreate;
begin
  FResponseCreator := function (d: IBencodedDictionary; m: IQueryMessage): IMessage
  begin
    Result := TPingResponse.Create(d, m);
  end;
end;

constructor TPing.Create(AID: TNodeID);
begin
  inherited Create(aid, QueryName, TPing.FResponseCreator);
end;

class destructor TPing.ClassDestroy;
begin
  FResponseCreator := nil;
end;

constructor TPing.Create(ADict: IBencodedDictionary);
begin
  inherited Create(adict, TPing.FResponseCreator);
end;

procedure TPing.Handle(AEngine: TDHTEngine; ANode: INode);
var
  m: TPingResponse;
begin
  inherited Handle(AEngine, ANode);

  m := TPingResponse.Create(aengine.RoutingTable.LocalNode.Id, GetTransactionID);
  aengine.MessageLoop.EnqueueSend(m, anode.EndPoint);
end;

end.
