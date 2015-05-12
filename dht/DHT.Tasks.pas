unit DHT.Tasks;

interface

uses
  System.SysUtils,
  Spring.Collections,
  Socket.Synsock, Socket.SynsockHelper,
  Common, Common.ThreadPool, Common.SortedList,
  Basic.UniString, Basic.Bencoding,
  DHT.Common, DHT.Engine, DHT.NodeID,
  IdGlobal;

type
  TTask = class(TInterfacedObject, ITask)
  private
    FOnCompleted: TGenList<TProc<ITaskCompleteEventArgs, IInterface>>;
    function GetOnCompleted: TGenList<TProc<ITaskCompleteEventArgs, IInterface>>; inline;
    function GetActive: Boolean; inline;
  private
    procedure Stop;
  protected
    FPool: TThreadPool;
    FActive: Boolean; // наверное можно отказаться
    procedure RaiseComplete(AEventArgs: ITaskCompleteEventArgs); virtual;
  public
    procedure Execute; virtual; abstract;
    constructor Create(APool: TThreadPool);
    destructor Destroy; override;
  end;

  TSendQueryTask = class(TTask, ISendQueryTask)
  private
    const
      // количество попыток выполниь запрос к ноде (3)
      MessageDefaultRetryCount = {$IFDEF PUBL_UTIL} 0 {$ELSE} 3 {$ENDIF};
  private
    FEngine: TDHTEngine;
    FNode: INode;
    FQuery: IQueryMessage;
    FRetries: Integer;
    FOrigRetries: Integer;

    FOnQuerySent: TFunc<ISendQueryEventArgs, Boolean>;
    function GetNode: INode; inline;
  protected
    procedure RaiseComplete(AEventArgs: ITaskCompleteEventArgs); override;
  public
    procedure Execute; override;
    property Retries: Integer read FOrigRetries;

    constructor Create(AEngine: TDHTEngine; APool: TThreadPool; AQuery: IQueryMessage; ANode: INode;
      ARetries: Integer); overload;
    constructor Create(AEngine: TDHTEngine; APool: TThreadPool; AQuery: IQueryMessage; ANode: INode); overload;
  end;

  TGetPeersTask = class(TTask, IGetPeersTask)
  private
    FInfoHash: TNodeID;
    FEngine: TDHTEngine;
    FActiveQueries: Integer;
    FClosestNodes: TSortedList<TNodeID, TNodeID>;
    FQueriedNodes: TSortedList<TNodeID, INode>;
  private
    procedure SendGetPeers(ANode: INode);
    function GetClosestActiveNodes: TSortedList<TNodeID, INode>; inline;
  protected
    procedure RaiseComplete(AEventArgs: ITaskCompleteEventArgs); override;
  public
    constructor Create(AEngine: TDHTEngine; APool: TThreadPool; AInfoHash: TNodeID);
    procedure Execute; override;
    destructor Destroy; override;
  end;

  TInitialiseTask = class(TTask, IInitialiseTask)
  private
    FActiveRequests: Integer;
    FInitialNodes: IList<INode>;
    FNodes: TSortedList<TNodeId, TNodeId>;
    FEngine: TDHTEngine;
    procedure Initialise(AEngine: TDHTEngine; ANodes: IList<INode>);
    procedure SendFindNode(ANewNodes: IList<INode>);
  protected
    procedure RaiseComplete(AEventArgs: ITaskCompleteEventArgs); override;
  public
    procedure Execute; override;

    constructor Create(AEngine: TDHTEngine; APool: TThreadPool); overload;
    constructor Create(AEngine: TDHTEngine; APool: TThreadPool; AInitialNodes: TUniString); overload;
    constructor Create(AEngine: TDHTEngine; APool: TThreadPool; AInitialNodes: IBencodedList); overload;
    constructor Create(AEngine: TDHTEngine; APool: TThreadPool; ANodes: IList<INode>); overload;
    destructor Destroy; override;
  end;

  TRefreshBucketTask = class(TTask, IRefreshBucketTask)
  private
    FEngine: TDHTEngine;
    FBucket: IBucket;
    FMsg: IFindNode;
    FNode: INode;
    procedure QueryNode(ANode: INode);
  protected
    procedure RaiseComplete(AEventArgs: ITaskCompleteEventArgs); override;
  public
    constructor Create(AEngine: TDHTEngine; APool: TThreadPool; ABucket: IBucket);
    procedure Execute; override;
  end;

  TAnnounceTask = class(TTask, IAnnounceTask)
  private
    FActiveAnnounces: Integer;
    FInfoHash: TNodeId;
    FEngine: TDHTEngine;
    FPort: TIdPort;
  protected
    procedure RaiseComplete(AEventArgs: ITaskCompleteEventArgs); override;
  public
    constructor Create(AEngine: TDHTEngine; APool: TThreadPool;
      AInfoHash: TUniString; APort: TIdPort); overload;
    constructor Create(AEngine: TDHTEngine; APool: TThreadPool;
      AInfoHash: TNodeID; APort: TIdPort); overload;
    procedure Execute; override;
  end;

implementation

uses
  DHT.Tasks.Events, DHT.Node, DHT.Bucket, DHT.Messages, DHT.Peer;

{ TTask }

constructor TTask.Create(APool: TThreadPool);
begin
  inherited Create;

  FPool := APool;
  FActive := False;
  FOnCompleted := TGenList<TProc<ITaskCompleteEventArgs, IInterface>>.Create;

  TDHTEngine.RegisterOnStop(GetHashCode, Stop);
end;

destructor TTask.Destroy;
begin
  if Assigned(FOnCompleted) then
    FOnCompleted.Free;

  TDHTEngine.UnregisterOnStop(GetHashCode);

  inherited;
end;

function TTask.GetActive: Boolean;
begin
  Result := FActive;
end;

function TTask.GetOnCompleted: TGenList<TProc<ITaskCompleteEventArgs, IInterface>>;
begin
  Result := FOnCompleted;
end;

procedure TTask.RaiseComplete(AEventArgs: ITaskCompleteEventArgs);
var
  it: TProc<ITaskCompleteEventArgs, IInterface>;
begin
  for it in FOnCompleted do
    it(AEventArgs, IInterface(Pointer(@it)^));

  //Self._Release;
end;

procedure TTask.Stop;
begin
  while Self._Release > 0 do;
end;

{ TSendQueryTask }

constructor TSendQueryTask.Create(AEngine: TDHTEngine; APool: TThreadPool; AQuery: IQueryMessage;
  ANode: INode; ARetries: Integer);
begin
  inherited Create(APool);

  Assert(Assigned(AEngine), 'AEngine not defined' );
  Assert(Assigned(AQuery) , 'AQuery not defined'  );
  Assert(Assigned(ANode)  , 'ANode not defined'   );

  FEngine       := AEngine;
  FQuery        := AQuery;
  FNode         := ANode;
  FRetries      := ARetries;
  FOrigRetries  := ARetries;
end;

constructor TSendQueryTask.Create(AEngine: TDHTEngine; APool: TThreadPool; AQuery: IQueryMessage;
  ANode: INode);
begin
  Create(AEngine, APool, AQuery, ANode, MessageDefaultRetryCount);
end;

procedure TSendQueryTask.Execute;
begin
  if FActive then
    Exit;

  Self._AddRef;

  FOnQuerySent := function (e: ISendQueryEventArgs): Boolean
  begin
    Result := False;

    // не наш запрос
    if e.Query.SequenceID <> FQuery.SequenceID then
      Exit;

    // If the message timed out and we we haven't already hit the maximum retries
    // send again. Otherwise we propagate the eventargs through the Complete event.
    if e.TimedOut then
      FNode.FailedCount := FNode.FailedCount + 1
    else
      FNode.LastSeen := UtcNow;

    if e.TimedOut then
      Dec(FRetries);

    if e.TimedOut and (FRetries > 0) then
      FEngine.MessageLoop.EnqueueSend(FQuery, FNode) { перепосылаем }
    else
    begin
      RaiseComplete(e); { всё ок, или время вышло, или не осталось попыток }
      Result := True;   { сигналим, что обработчик можно смело удалять }
    end;
  end;

  FEngine.MessageLoop.LockQuerySent;
  try
    FEngine.MessageLoop.OnQuerySent.Add(FOnQuerySent);
  finally
    FEngine.MessageLoop.UnlockQuerySent;
  end;

  FEngine.MessageLoop.EnqueueSend(FQuery, FNode);
end;

function TSendQueryTask.GetNode: INode;
begin
  Result := FNode;
end;

procedure TSendQueryTask.RaiseComplete(AEventArgs: ITaskCompleteEventArgs);
begin
  FOnQuerySent := nil;
  AEventArgs.Task := Self as ITask;
  inherited RaiseComplete(AEventArgs);
  AEventArgs.Task := nil; { спасёт ли это от AV? }
  Self._Release;
end;

{ TGetPeersTask }

constructor TGetPeersTask.Create(AEngine: TDHTEngine; APool: TThreadPool; AInfoHash: TNodeID);
begin
  inherited Create(APool);

  FEngine := AEngine;
  FInfoHash := AInfoHash;

  FClosestNodes := TSortedList<TNodeId, TNodeId>.Create(NodeIDSorter);
  FQueriedNodes := TSortedList<TNodeId, INode>.Create(NodeIDSorter);
end;

destructor TGetPeersTask.Destroy;
begin
  FClosestNodes.Free;
  FQueriedNodes.Free;
  inherited;
end;

procedure TGetPeersTask.Execute;
begin
  if FActive then
    Exit;

  FActive := True;
  Self._AddRef;

  FPool.Exec(Integer(TGetPeersTask), function : Boolean
  var
    newNodes: IList<INode>;
    n: INode;
  begin
    Result := False;

    FEngine.Lock;
    try
      newNodes := FEngine.RoutingTable.GetClosest(FInfoHash);
      for n in TNode.CloserNodes(FInfoHash, FClosestNodes, newNodes, TBucket.MaxCapacity) do
        SendGetPeers(n);
    finally
      FEngine.Unlock;
    end;
  end);
end;

function TGetPeersTask.GetClosestActiveNodes: TSortedList<TNodeID, INode>;
begin
  Result := FQueriedNodes;
end;

procedure TGetPeersTask.RaiseComplete(AEventArgs: ITaskCompleteEventArgs);
begin
  if not FActive then
    Exit;

  FActive := False;
  inherited RaiseComplete(AEventArgs);
  Self._Release;
end;

procedure TGetPeersTask.SendGetPeers(ANode: INode);
var
  distance: TNodeID;
begin
  distance := ANode.ID xor FInfoHash;
  FQueriedNodes.Add(distance, ANode);

  Inc(FActiveQueries);

  with TSendQueryTask.Create(FEngine, FPool,
         TGetPeers.Create(FEngine.LocalId, FInfoHash),
         ANode) as ISendQueryTask do
  begin
    OnCompleted.Add(procedure (e: ITaskCompleteEventArgs; ACaller: IInterface)
    var
      args: ISendQueryEventArgs;
      target_: INode;
      index: Integer;
      response: IGetPeersResponse;
      newNodes: IList<INode>;
      n: INode;
    begin
      Dec(FActiveQueries);
      try
        e.Task.OnCompleted.Remove(TProc<ITaskCompleteEventArgs, IInterface>(ACaller));

        args := e as ISendQueryEventArgs;
        // We want to keep a list of the top (K) closest nodes which have responded
        target_ := (args.Task as ISendQueryTask).Target;
        index := FQueriedNodes.Values.IndexOf(target_);
        if (index >= TBucket.MaxCapacity) or args.TimedOut then
          FQueriedNodes.Delete(index);

        if args.TimedOut then
          Exit;

        response := args.Response as IGetPeersResponse;

        // Ensure that the local Node object has the token. There may/may not be
        // an additional copy in the routing table depending on whether or not
        // it was able to fit into the table.
        target_.Token := response.Token;
        if Assigned(response.Values) then
          FEngine.RaisePeersFound(FInfoHash, TPeer.Decode(response.Values)); // We have actual peers!

        if response.Nodes.Len > 0 then
        begin
          if not FActive then
            Exit;

          // We got a list of nodes which are closer
          newNodes := TNode.FromCompactNode(response.Nodes);
          for n in TNode.CloserNodes(FInfoHash, FClosestNodes, newNodes, TBucket.MaxCapacity) do
            SendGetPeers(n);
        end;
      finally
        if FActiveQueries = 0 then
          RaiseComplete(TTaskCompleteEventArgs.Create(Self as ITask));
      end;
    end);

    Execute;
  end;
end;

{ TInitialiseTask }

constructor TInitialiseTask.Create(AEngine: TDHTEngine; APool: TThreadPool);
begin
  inherited Create(APool);

  Initialise(AEngine, nil);
end;

constructor TInitialiseTask.Create(AEngine: TDHTEngine; APool: TThreadPool;
  AInitialNodes: TUniString);
begin
  inherited Create(APool);

  Initialise(AEngine, TNode.FromCompactNode(AInitialNodes));
end;

constructor TInitialiseTask.Create(AEngine: TDHTEngine; APool: TThreadPool;
  ANodes: IList<INode>);
begin
  inherited Create(APool);

  Initialise(AEngine, ANodes);
end;

destructor TInitialiseTask.Destroy;
begin
  FNodes.Free;
  inherited;
end;

constructor TInitialiseTask.Create(AEngine: TDHTEngine; APool: TThreadPool;
  AInitialNodes: IBencodedList);
begin
  inherited Create(APool);

  Initialise(AEngine, TNode.FromBencodedNode(AInitialNodes));
end;

procedure TInitialiseTask.Execute;
var
  bootList: IList<INode>;
begin
  if FActive then
    Exit;

  FActive := true;

  Self._AddRef;

  // If we were given a list of nodes to load at the start, use them
  if FInitialNodes.Count > 0 then
  begin
    FEngine.Add(FInitialNodes);
    SendFindNode(FInitialNodes);
  end else
  try
    bootList := TSprList<INode>.Create;
    bootList.Add(TNode.Create(TNodeID.New, StrToVarSin('67.215.246.10:6881' {82.221.103.244:6881})) as INode);

    SendFindNode(bootList);
  except
    RaiseComplete(TTaskCompleteEventArgs.Create(Self as ITask));
  end
end;

procedure TInitialiseTask.Initialise(AEngine: TDHTEngine; ANodes: IList<INode>);
var
  n: INode;
begin
  FActiveRequests := 0;
  FNodes := TSortedList<TNodeId, TNodeId>.Create(NodeIDSorter);

  FEngine := AEngine;
  FInitialNodes := TSprList<INode>.Create;

  if Assigned(ANodes) then
    for n in ANodes do
      FInitialNodes.Add(n);
end;

procedure TInitialiseTask.RaiseComplete(AEventArgs: ITaskCompleteEventArgs);
begin
  if not FActive then
    Exit;

  // If we were given a list of initial nodes and they were all dead,
  // initialise again except use the utorrent router.
  if (FInitialNodes.Count > 0) and (FEngine.RoutingTable.CountNodes < 10) then
  begin
    FEngine.RegisterRequest;

    with TInitialiseTask.Create(FEngine, FPool) as IInitialiseTask do
      Execute;
  end else
    FEngine.UnregisterRequest;

  FActive := False;
  inherited RaiseComplete(AEventArgs);
  Self._Release; { обработчик мы сняли, декрементим счетчик ссылок }
end;

procedure TInitialiseTask.SendFindNode(ANewNodes: IList<INode>);
var
  n: INode;
begin
  for n in TNode.CloserNodes(FEngine.LocalId, FNodes, ANewNodes, TBucket.MaxCapacity) do
  begin
    Inc(FActiveRequests);

    with TSendQueryTask.Create(FEngine, FPool,
           TFindNode.Create(FEngine.LocalId, FEngine.LocalId),
           n) as ISendQueryTask do
    begin
      OnCompleted.Add(procedure (e: ITaskCompleteEventArgs; ACaller: IInterface)
      var
        args: ISendQueryEventArgs;
        response: IFindNodeResponse;
      begin
        e.Task.OnCompleted.Remove(TProc<ITaskCompleteEventArgs, IInterface>(ACaller));

        Dec(factiveRequests);

        args := e as ISendQueryEventArgs;
        if not args.TimedOut then
        begin
          response := args.Response as IFindNodeResponse;

          if response.Nodes <> nil then
            SendFindNode(TNode.FromCompactNode(response.Nodes.Value));
        end;

        if factiveRequests = 0 then
          RaiseComplete(TTaskCompleteEventArgs.Create(Self as ITask));
      end);

      Execute;
    end;
  end;
end;

{ TRefreshBucketTask }

constructor TRefreshBucketTask.Create(AEngine: TDHTEngine; APool: TThreadPool;
  ABucket: IBucket);
begin
  inherited Create(APool);

  FEngine := AEngine;
  FBucket := ABucket;
end;

procedure TRefreshBucketTask.Execute;
begin
  Self._AddRef;

  if FBucket.Nodes.Count = 0 then
    RaiseComplete(TTaskCompleteEventArgs.Create(Self as ITask))
  else
  begin
    FBucket.SortBySeen;
    QueryNode(FBucket.Nodes[0]);
  end;
end;

procedure TRefreshBucketTask.QueryNode(ANode: INode);
begin
  FNode := ANode;
  FMsg := TFindNode.Create(FEngine.LocalId, ANode.ID);

  Self._AddRef;

  with TSendQueryTask.Create(FEngine, FPool, FMsg, fnode) as ISendQueryTask do
  begin
    OnCompleted.Add(procedure (e: ITaskCompleteEventArgs; ACaller: IInterface)
    var
      args: ISendQueryEventArgs;
      index: Integer;
    begin
      Self._Release;

      Assert((Self.FRefCount > 0) and (Self.FRefCount < 10000), 'wtf?');

      e.Task.OnCompleted.Remove(TProc<ITaskCompleteEventArgs, IInterface>(ACaller));

      args := e as ISendQueryEventArgs;
      if args.TimedOut then
      begin
        fbucket.SortBySeen;
        index := fbucket.Nodes.IndexOf(fnode);

        if (index = -1) or (index + 1 < fbucket.Nodes.Count) then
          QueryNode(fbucket.Nodes[0])
        else
          RaiseComplete(TTaskCompleteEventArgs.Create(Self as ITask));
      end else
        RaiseComplete(TTaskCompleteEventArgs.Create(Self as ITask));
    end);

    Execute;
  end;
end;

procedure TRefreshBucketTask.RaiseComplete(AEventArgs: ITaskCompleteEventArgs);
begin
  inherited RaiseComplete(AEventArgs);
  Self._Release;
end;

{ TAnnounceTask }

constructor TAnnounceTask.Create(AEngine: TDHTEngine; APool: TThreadPool;
  AInfoHash: TUniString; APort: TIdPort);
begin
  Create(AEngine, APool, TNodeID(AInfoHash), APort);
end;

constructor TAnnounceTask.Create(AEngine: TDHTEngine; APool: TThreadPool;
  AInfoHash: TNodeID; APort: TIdPort);
begin
  inherited Create(APool);

  FEngine := AEngine;
  FInfoHash := AInfoHash;
  FPort := APort;
end;

procedure TAnnounceTask.Execute;
begin
  Self._AddRef;

  with TGetPeersTask.Create(FEngine, FPool, FInfoHash) as IGetPeersTask do
  begin
    OnCompleted.Add(procedure (e1: ITaskCompleteEventArgs; ACaller1: IInterface)
    var
      getpeers: IGetPeersTask;
      n: INode;
    begin
      Assert(Supports(Self, IAnnounceTask));

      e1.Task.OnCompleted.Remove(TProc<ITaskCompleteEventArgs, IInterface>(ACaller1));

      getpeers := e1.Task as IGetPeersTask;
      for n in getpeers.ClosestActiveNodes.Values do
      begin
        if n.Token.Len = 0 then
          Continue;

        with TSendQueryTask.Create(FEngine, FPool,
               TAnnouncePeer.Create(FEngine.LocalId, FInfoHash, FPort, n.Token),
               n) as ISendQueryTask do
        begin
          OnCompleted.Add(procedure (e2: ITaskCompleteEventArgs; ACaller2: IInterface)
          begin
            Assert(Supports(Self, IAnnounceTask));

            e2.Task.OnCompleted.Remove(TProc<ITaskCompleteEventArgs, IInterface>(ACaller2));

            Dec(FActiveAnnounces);

            if FActiveAnnounces = 0 then
              RaiseComplete(TTaskCompleteEventArgs.Create(Self as ITask));
          end);

          Inc(FActiveAnnounces);
          Execute;
        end;
      end;

      if FActiveAnnounces = 0 then
        RaiseComplete(TTaskCompleteEventArgs.Create(Self as ITask));
    end);

    Execute;
  end;
end;

procedure TAnnounceTask.RaiseComplete(AEventArgs: ITaskCompleteEventArgs);
begin
  inherited;
  Self._Release;
end;

end.
