unit DHT.Engine;

interface

uses
  System.SysUtils, System.Generics.Collections, System.Generics.Defaults,
  System.DateUtils, System.TimeSpan, System.Classes,
  Basic.BigInteger, Basic.UniString, Basic.Bencoding,
  Common.SortedList, Common.BusyObj, Common.Prelude,
  DHT, DHT.NodeID, DHT.Common,
  UDP.Server,
  IdGlobal, IdStack;

type
  TDHTEngine = class(TBusy, IDHTEngine)
  private
    FTasks: TList<ITask>;
    FBootStrap: Boolean;
    FOnBootstrapComplete: TProc<IDHTEngine>;
    FInitialNodes: TArray<INode>;
    FBucketRefreshTimeout: TTimeSpan;
    FValues: TDictionary<TNodeID, TArray<IPeer>>;
    FRoutingTable: IRoutingTable;
    FTokenManager: ITokenManager;
    FMessageLoop: IMessageLoop;

    function GetLocalId: TNodeID; inline;
    procedure AddBootstrapNode(const AHost: string; APort: TIdPort); inline;

    procedure RegisterTask(ATask: ITask; AOnComplete: TProc = nil);

    { Handle queries }
    procedure HandlePing(AMessage: IPing; ANode: INode); inline;
    procedure HandleFindNode(AMessage: IFindNode; ANode: INode);
    procedure HandleGetPeers(AMessage: IGetPeers; ANode: INode);
    procedure HandleAnnouncePeer(AMessage: IAnnouncePeer; ANode: INode); inline;
    { Handle responses }
    procedure HandleGetPeersResponse(AMessage: IGetPeersResponse; ANode: INode); inline;
    procedure HandleFindNodeResponse(AMessage: IFindNodeResponse); inline;
    procedure HandleErrorMessage(AMessage: IErrorMessage); inline;
    { HandleMessage }
    procedure HandleMessage(AMessage: IMessage; ANode: INode); inline;

    procedure OnTaskSendMessage(ATarget: INode; AMessage: IMessage;
      AOnSent: TProc<ISendQueryEventArgs>);
    function OnTaskRequestClosestNodes(ATarget: TNodeID): TArray<INode>;
    procedure OnMsgLoopRecvMessage(AHost: string; APort: TIdPort; AMessage: IMessage);

    function GetOnBootstrapComplete: TProc<IDHTEngine>; inline;
    procedure SetOnBootstrapComplete(const Value: TProc<IDHTEngine>); inline;

    procedure Add(ANodes: TArray<INode>); overload;
    procedure Add(ANode: INode); overload; // возможно там надо использовать крит. секцию

    function Announce(const AInfoHash: TUniString; APort: TIdPort): IAnnounceTask;
    function GetPeers(const AInfoHash: TUniString): IGetPeersTask;

    {function SaveNodes: IBencodedList;}
  protected
    procedure DoSync; override;
  public
    constructor Create(const ALocalID: TUniString; ALocalPort: TIdPort);
    destructor Destroy; override;
  end;

implementation

uses
  Winapi.Windows,
  DHT.RoutingTable, DHT.TokenManager, DHT.Tasks, DHT.Messages, DHT.Node,
  DHT.Peer, DHT.Messages.MessageLoop;

{ TDHTEngine }

function TDHTEngine.Announce(const AInfoHash: TUniString;
  APort: TIdPort): IAnnounceTask;
begin
  Assert(AInfoHash.Len = TNodeID.NodeIDLen);
  Result := TAnnounceTask.Create(GetLocalId, AInfoHash, APort,
    OnTaskSendMessage, OnTaskRequestClosestNodes);
end;

procedure TDHTEngine.Add(ANodes: TArray<INode>);
var
  n: INode;
begin
  for n in ANodes do
    Add(n);
end;

procedure TDHTEngine.Add(ANode: INode);
begin
  Assert(Assigned(ANode));

  if not FRoutingTable.ContainsNode(ANode.ID) then
    RegisterTask(TSendQueryTask.Create(OnTaskSendMessage,
      TPing.Create(GetLocalId), ANode));
end;

procedure TDHTEngine.AddBootstrapNode(const AHost: string; APort: TIdPort);
begin
  GStack.IncUsage;
  try
    TAppender.Append<INode>(FInitialNodes, TNode.Create(TUniString(string.Empty),
      GStack.ResolveHost(AHost), APort));
  finally
    GStack.DecUsage;
  end;
end;

constructor TDHTEngine.Create(const ALocalID: TUniString; ALocalPort: TIdPort);
begin
  inherited Create;

  FTasks := TList<ITask>.Create;
  FBootStrap := True;
  FBucketRefreshTimeout := TTimeSpan.FromMinutes(15);
  FValues := TDictionary<TNodeID, TArray<IPeer>>.Create;

  if ALocalID.Len > 0 then
    FRoutingTable := TRoutingTable.Create(TNode.Create(TNodeID(ALocalID),
      string.Empty, 0))
  else
    FRoutingTable := TRoutingTable.Create;

  FMessageLoop  := TMessageLoop.Create(ALocalPort, TTimeSpan.FromSeconds(10),
    OnMsgLoopRecvMessage);
  FMessageLoop.OnError := procedure (AMsgLoop: IMessageLoop;
    AHost: string; APort: TIdPort; AException: Exception)
  begin
    // отправлять ноду в черный список
  end;
  FMessageLoop.Start;

  FTokenManager := TTokenManager.Create;
end;

destructor TDHTEngine.Destroy;
begin
  FValues.Free;
  FMessageLoop.Stop;
  FTasks.Free;
  inherited;
end;

procedure TDHTEngine.DoSync;
var
  it: ITask;
  b: IBucket;
  t: TDateTime;
begin
  if FBootStrap then
  begin
    RegisterTask(TInitialiseTask.Create(GetLocalId, FInitialNodes,
      OnTaskSendMessage), procedure
      begin
        if Assigned(FOnBootstrapComplete) then
          FOnBootstrapComplete(Self);
      end
    );

    FBootStrap := False;
  end;

  t := Now;
  // выполнять не чаще раза в 5 секунд
  for b in FRoutingTable.Buckets do
    if TTimeSpan.Subtract(t, b.LastChanged) > FBucketRefreshTimeout then
    begin
      b.LastChanged := t;

      RegisterTask(TRefreshBucketTask.Create(GetLocalId, b, OnTaskSendMessage));
    end;

  for it in FTasks do
    if not it.Busy then
      it.Sync; // имеет смысл выполнять задачи в отдельных потоках?

  FMessageLoop.Sync;
end;

function TDHTEngine.GetLocalId: TNodeID;
begin
  Result := FRoutingTable.LocalNode.ID;
end;

function TDHTEngine.GetOnBootstrapComplete: TProc<IDHTEngine>;
begin
  Result := FOnBootstrapComplete;
end;

function TDHTEngine.GetPeers(const AInfoHash: TUniString): IGetPeersTask;
begin
  Assert(AInfoHash.Len = TNodeID.NodeIDLen);
  Result := TGetPeersTask.Create(GetLocalId, AInfoHash,
    OnTaskSendMessage, OnTaskRequestClosestNodes);
end;

procedure TDHTEngine.HandleAnnouncePeer(AMessage: IAnnouncePeer; ANode: INode);
var
  msg: IMessage;
  val: TArray<IPeer>;
begin
  Assert(Assigned(ANode));

  if FTokenManager.VerifyToken(ANode, AMessage.Token) then
  begin
    msg := TAnnouncePeerResponse.Create(GetLocalId, AMessage.TransactionID);
    with FValues do
    begin
      TryGetValue(AMessage.InfoHash, val);
      // желательно бы контролировать уникальность
      TAppender.Append<IPeer>(val, TPeer.Create(ANode.Host, AMessage.Port));
      AddOrSetValue(AMessage.InfoHash, val);
    end;
  end else
    msg := TErrorMessage.Create(ecProtocolError, 'Invalid or expired token received',
      AMessage.TransactionID);

  FMessageLoop.EnqueueSend(ANode, msg);
end;

procedure TDHTEngine.HandleErrorMessage(AMessage: IErrorMessage);
begin
  raise EErrorMessage.Create(AMessage.MessageText);
end;

procedure TDHTEngine.HandleFindNode(AMessage: IFindNode; ANode: INode);
var
  n: INode;
  nodes: TArray<TUniString>;
begin
  Assert(Assigned(ANode));

  n := FRoutingTable.FindNode(AMessage.Target);
  if Assigned(n) then
    TAppender.Append<TUniString>(nodes, n.Compact)
  else
    nodes := TPrelude.Map<INode, TUniString>(FRoutingTable.Closest[AMessage.Target],
      function (X: INode): TUniString
      begin
        Result := X.Compact;
      end
    );

  FMessageLoop.EnqueueSend(ANode, TFindNodeResponse.Create(GetLocalId,
    AMessage.TransactionID, nodes));
end;

procedure TDHTEngine.HandleFindNodeResponse(AMessage: IFindNodeResponse);
begin
  Add(TNode.FromCompactNode(AMessage.Nodes));
end;

procedure TDHTEngine.HandleGetPeers(AMessage: IGetPeers; ANode: INode);
var
  nodes: TArray<INode>;
  values: TArray<IPeer>;
begin
  Assert(Assigned(ANode));

  with AMessage do
  begin
    if not FValues.TryGetValue(InfoHash, values) then
      nodes := FRoutingTable.Closest[InfoHash];

    FMessageLoop.EnqueueSend(ANode, TGetPeersResponse.Create(GetLocalId,
      TransactionID, FTokenManager.GenerateToken(ANode),
      TPrelude.Map<INode, TUniString>(nodes, function (X: INode): TUniString
      begin
        Result := X.Compact;
      end),
      TPrelude.Map<IPeer, TUniString>(values, function (X: IPeer): TUniString
      begin
        Result := X.CompactAddress;
      end))
    );
  end;
end;

procedure TDHTEngine.HandleGetPeersResponse(AMessage: IGetPeersResponse;
  ANode: INode);
begin
  Assert(Assigned(ANode));

  ANode.Token := AMessage.Token.Copy;

  Add(TNode.FromCompactNode(AMessage.Nodes));
end;

procedure TDHTEngine.HandleMessage(AMessage: IMessage; ANode: INode);
begin
  if Supports(AMessage, IPing) then
    HandlePing(AMessage as IPing, ANode)
  else
  if Supports(AMessage, IFindNode) then
    HandleFindNode(AMessage as IFindNode, ANode)
  else
  if Supports(AMessage, IGetPeers) then
    HandleGetPeers(AMessage as IGetPeers, ANode)
  else
  if Supports(AMessage, IAnnouncePeer) then
    HandleAnnouncePeer(AMessage as IAnnouncePeer, ANode)
  else
  if Supports(AMessage, IGetPeersResponse) then
    HandleGetPeersResponse(AMessage as IGetPeersResponse, ANode)
  else
  if Supports(AMessage, IFindNodeResponse) then
    HandleFindNodeResponse(AMessage as IFindNodeResponse)
  else
  if Supports(AMessage, IErrorMessage) then
    HandleErrorMessage(AMessage as IErrorMessage);
end;

procedure TDHTEngine.HandlePing(AMessage: IPing; ANode: INode);
begin
  Assert(Assigned(ANode));

  FMessageLoop.EnqueueSend(ANode, TPingResponse.Create(GetLocalId,
    AMessage.TransactionID));
end;

procedure TDHTEngine.OnMsgLoopRecvMessage(AHost: string; APort: TIdPort;
  AMessage: IMessage);
var
  node: INode;
begin
  if not Supports(AMessage, IErrorMessage) then
  begin
    node := FRoutingTable.FindNode(AMessage.ID);

    if not Assigned(node) then
    begin
      { добавляем новую ноду }
      node := TNode.Create(AMessage.ID, AHost, APort);
      FRoutingTable.Add(node);
    end;

    node.Seen;
  end else
    node := nil;

  HandleMessage(AMessage, node);
end;

function TDHTEngine.OnTaskRequestClosestNodes(ATarget: TNodeID): TArray<INode>;
begin
  Result := FRoutingTable.Closest[ATarget];
end;

procedure TDHTEngine.OnTaskSendMessage(ATarget: INode; AMessage: IMessage;
  AOnSent: TProc<ISendQueryEventArgs>);
begin
  FMessageLoop.EnqueueSend(ATarget, AMessage, AOnSent);
end;

procedure TDHTEngine.RegisterTask(ATask: ITask; AOnComplete: TProc);
begin
  ATask.OnCompleted := procedure (t: ITask; e: ICompleteEventArgs)
  begin
    FTasks.Remove(t);

    if Assigned(AOnComplete) then
      AOnComplete;
  end;

  FTasks.Add(ATask);
end;

(*function TDHTEngine.SaveNodes: IBencodedList;
var
  result_: IBencodedList;
  w: Boolean;
begin
  result_ := BencodedList;

  w := True;
  FPool.Exec(function : Boolean
  var
    b: IBucket;
    n: INode;
  begin
    Lock;
    try
      for b in FRoutingTable.Buckets do
      begin
        for n in b.Nodes do
          result_.Add(n.BencodeNode {BencodeString(n.CompactNode)});

        if Assigned(b.Replacement) and (b.Replacement.State <> nsBad) then
          result_.Add(b.Replacement.BencodeNode {BencodeString(b.Replacement.CompactNode)});
      end;

      w := False;
      Result := False;
    finally
      Unlock;
    end;
  end);

  while w do
    Sleep(1);

  Result := result_;
end;*)

procedure TDHTEngine.SetOnBootstrapComplete(const Value: TProc<IDHTEngine>);
begin
  FOnBootstrapComplete := Value;
end;

end.
