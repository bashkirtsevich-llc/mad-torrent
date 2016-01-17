unit DHT.Tasks;

interface

uses
  System.SysUtils, System.Generics.Collections, System.Generics.Defaults,
  Common.SortedList, Common.BusyObj,
  Basic.UniString, Basic.Bencoding,
  DHT, DHT.Common, DHT.NodeID,
  IdGlobal;

type
  TTask = class abstract(TBusy, ITask)
  strict private
    FLock: TObject;
    FCompleted: Boolean;
    FOnCompleted: TProc<ITask, ICompleteEventArgs>;
    function GetCompleted: Boolean; inline;
    function GetOnCompleted: TProc<ITask, ICompleteEventArgs>; inline;
    procedure SetOnCompleted(const Value: TProc<ITask, ICompleteEventArgs>); inline;
  strict protected
    procedure Lock; inline;
    procedure Unlock; inline;

    procedure Reset; virtual;

    procedure RaiseComplete(AEventArgs: ICompleteEventArgs = nil); inline;

    constructor Create; reintroduce;
  public
    destructor Destroy; override;
  end;

  TNetworkTask = class abstract(TTask)
  strict protected
    FInitialized: Boolean;
    FOnSendMessage: TProc<INode, IMessage, TProc<ISendQueryEventArgs>>;
    constructor Create(AOnSendMessage: TProc<INode, IMessage, TProc<ISendQueryEventArgs>>); reintroduce;
  end;

  TSendQueryTask = class(TNetworkTask, ISendQueryTask)
  private
    const
      MsgRetryCount = 1;
  private
    FTarget: INode;
    FQuery: IQueryMessage;
    FRetries: Integer;
    function GetTarget: INode; inline;
    procedure OnSent(AArgs: ISendQueryEventArgs);
  protected
    procedure DoSync; override;
  public
    constructor Create(AOnSendMessage: TProc<INode, IMessage, TProc<ISendQueryEventArgs>>;
      AQuery: IQueryMessage; ATarget: INode); reintroduce;
  end;

  TLocalIDTask = class abstract(TNetworkTask)
  strict protected
    FLocalID: TNodeID;
    function NewQueryTask(AQuery: IQueryMessage; ANode: INode;
      AOnCompleted: TProc<ITask, ICompleteEventArgs>): ITask; inline;
    constructor Create(const ALocalID: TNodeID;
      AOnSendMessage: TProc<INode, IMessage, TProc<ISendQueryEventArgs>>); reintroduce;
  end;

  TFindPeersTask = class abstract(TLocalIDTask, IFindPeersTask)
  strict private
    FInfoHash: TNodeID;
    FOnPeersFound: TProc<TArray<IPeer>>;
    function GetOnPeersFound: TProc<TArray<IPeer>>; inline;
    procedure SetOnPeersFound(const Value: TProc<TArray<IPeer>>); inline;
  protected
    procedure Reset; override;
    function GetInfoHash: TNodeID; inline;
    procedure RaisePeersFound(APeers: TArray<IPeer>);

    constructor Create(const ALocalID, AInfoHash: TNodeID;
      AOnSendMessage: TProc<INode, IMessage, TProc<ISendQueryEventArgs>>); reintroduce;
  end;

  TGetPeersTask = class(TFindPeersTask, IGetPeersTask)
  private
    FSubtasks: TList<ITask>;
    FClosestNodes: TSortedList<TNodeID, TNodeID>;
    FQueriedNodes: TSortedList<TNodeID, INode>;
    FOnGetClosest: TFunc<TNodeID, TArray<INode>>;
  private
    procedure SendGetPeers(ANode: INode);
    function GetClosestActiveNodes: TEnumerable<INode>; inline;
    function GetClosestActiveNodesCount: Integer; inline;
    function GetClosestNodes(ATarget: TNodeID): TArray<INode>; inline;
  protected
    procedure Reset; override; final;
    procedure DoSync; override;
  public
    constructor Create(ALocalID: TNodeID; AInfoHash: TNodeID;
      AOnSendMessage: TProc<INode, IMessage, TProc<ISendQueryEventArgs>>;
      AOnGetClosest: TFunc<TNodeID, TArray<INode>>); reintroduce;
    destructor Destroy; override;
  end;

  TInitialiseTask = class(TLocalIDTask, IInitialiseTask)
  private
    // для инициализации юзать эти хосты:
    // 67.215.246.10:6881
    // 82.221.103.244:6881
    FInitialNodes: TArray<INode>;
    FNodes: TSortedList<TNodeId, TNodeId>;
    FSubtasks: TList<ITask>;

    procedure SendFindNode(ANewNodes: TArray<INode>);
  protected
    procedure DoSync; override;
  public
    constructor Create(ALocalID: TNodeID; ANodes: TArray<INode>;
      AOnSendMessage: TProc<INode, IMessage, TProc<ISendQueryEventArgs>>); reintroduce;
    destructor Destroy; override;
  end;

  TRefreshBucketTask = class(TLocalIDTask, IRefreshBucketTask)
  private
    FBucket: IBucket;
    FSubTask: ITask;

    function QueryNode(ANode: INode): ITask;
  protected
    procedure DoSync; override;
  public
    constructor Create(ALocalID: TNodeID; ABucket: IBucket;
      AOnSendMessage: TProc<INode, IMessage, TProc<ISendQueryEventArgs>>); reintroduce;
  end;

  TAnnounceTask = class(TFindPeersTask, IAnnounceTask)
  private
    FSubtask: IFindPeersTask; // задача поиска ноды для анонса
    FSubtasks: TList<ITask>; // список анонсирующих задач
    FPort: TIdPort;
    FOnGetClosest: TFunc<TNodeID, TArray<INode>>;
    function GetPort: TIdPort; inline;
  protected
    procedure Reset; override; final;
    procedure DoSync; override;
  public
    constructor Create(ALocalID: TNodeID; AInfoHash: TNodeID; APort: TIdPort;
      AOnSendMessage: TProc<INode, IMessage, TProc<ISendQueryEventArgs>>;
      AOnGetClosest: TFunc<TNodeID, TArray<INode>>); reintroduce;
    destructor Destroy; override;
  end;

implementation

uses
  DHT.Tasks.Events, DHT.Node, DHT.Bucket, DHT.Messages, DHT.Peer;

{ TTask }

constructor TTask.Create;
begin
  inherited Create;

  FLock := TObject.Create;
  FCompleted := False;
end;

destructor TTask.Destroy;
begin
  FLock.Free;

  inherited;
end;

function TTask.GetCompleted: Boolean;
begin
  Result := FCompleted;
end;

function TTask.GetOnCompleted: TProc<ITask, ICompleteEventArgs>;
begin
  Result := FOnCompleted;
end;

procedure TTask.Lock;
begin
  TMonitor.Enter(FLock);
end;

procedure TTask.RaiseComplete(AEventArgs: ICompleteEventArgs);
begin
  FCompleted := True;

  if Assigned(FOnCompleted) then
    FOnCompleted(Self, AEventArgs);
end;

procedure TTask.Reset;
begin
  FCompleted := False;
end;

procedure TTask.SetOnCompleted(const Value: TProc<ITask, ICompleteEventArgs>);
begin
  FOnCompleted := Value;
end;

procedure TTask.Unlock;
begin
  TMonitor.Exit(FLock);
end;

{ TNetworkTask }

constructor TNetworkTask.Create(
  AOnSendMessage: TProc<INode, IMessage, TProc<ISendQueryEventArgs>>);
begin
  inherited Create;

  Assert(Assigned(AOnSendMessage));
  FOnSendMessage := AOnSendMessage;
end;

{ TLocalIDTask }

constructor TLocalIDTask.Create(const ALocalID: TNodeID;
  AOnSendMessage: TProc<INode, IMessage, TProc<ISendQueryEventArgs>>);
begin
  inherited Create(AOnSendMessage);

  FLocalID := ALocalID;
end;

function TLocalIDTask.NewQueryTask(AQuery: IQueryMessage; ANode: INode;
  AOnCompleted: TProc<ITask, ICompleteEventArgs>): ITask;
begin
  Result := TSendQueryTask.Create(FOnSendMessage, AQuery, ANode);
  Result.OnCompleted := AOnCompleted;
end;

{ TSendQueryTask }

constructor TSendQueryTask.Create(AOnSendMessage: TProc<INode, IMessage, TProc<ISendQueryEventArgs>>;
  AQuery: IQueryMessage; ATarget: INode);
begin
  inherited Create(AOnSendMessage);

  FQuery    := AQuery;
  FTarget   := ATarget;
  FRetries  := 0;
end;

procedure TSendQueryTask.DoSync;
begin
  Enter;
  FOnSendMessage(FTarget, FQuery, OnSent);
end;

function TSendQueryTask.GetTarget: INode;
begin
  Result := FTarget;
end;

procedure TSendQueryTask.OnSent(AArgs: ISendQueryEventArgs);
begin
  // If the message timed out and we we haven't already hit the maximum retries
  // send again. Otherwise we propagate the eventargs through the Complete event.
  if AArgs.TimedOut then
    FTarget.FailedCount := FTarget.FailedCount + 1
  else
    FTarget.LastSeen := Now;

  if AArgs.TimedOut and (FRetries <= MsgRetryCount) then
    Inc(FRetries)
  else
    RaiseComplete(AArgs); { всё ок, или время вышло, или не осталось попыток }

  Leave;
end;

{ TFindPeersTask }

constructor TFindPeersTask.Create(const ALocalID, AInfoHash: TNodeID;
  AOnSendMessage: TProc<INode, IMessage, TProc<ISendQueryEventArgs>>);
begin
  inherited Create(ALocalID, AOnSendMessage);

  FInfoHash := AInfoHash;
end;

function TFindPeersTask.GetInfoHash: TNodeID;
begin
  Result := FInfoHash;
end;

function TFindPeersTask.GetOnPeersFound: TProc<TArray<IPeer>>;
begin
  Result := FOnPeersFound;
end;

procedure TFindPeersTask.RaisePeersFound(APeers: TArray<IPeer>);
begin
  if Assigned(FOnPeersFound) then
    FOnPeersFound(APeers);
end;

procedure TFindPeersTask.Reset;
begin
  inherited Reset;

  FInitialized := False;
end;

procedure TFindPeersTask.SetOnPeersFound(const Value: TProc<TArray<IPeer>>);
begin
  FOnPeersFound := Value;
end;

{ TGetPeersTask }

constructor TGetPeersTask.Create(ALocalID: TNodeID; AInfoHash: TNodeID;
  AOnSendMessage: TProc<INode, IMessage, TProc<ISendQueryEventArgs>>;
  AOnGetClosest: TFunc<TNodeID, TArray<INode>>);
begin
  inherited Create(ALocalID, AInfoHash, AOnSendMessage);

  Assert(Assigned(AOnGetClosest));
  FOnGetClosest := AOnGetClosest;

  FSubtasks     := TList<ITask>.Create;
  FClosestNodes := TSortedList<TNodeId, TNodeId>.Create(NodeIDSorter);
  FQueriedNodes := TSortedList<TNodeId, INode>.Create(NodeIDSorter);
end;

destructor TGetPeersTask.Destroy;
begin
  FSubtasks.Free;
  FClosestNodes.Free;
  FQueriedNodes.Free;
  inherited;
end;

procedure TGetPeersTask.DoSync;
var
  n: INode;
  it: ITask;
begin
  Lock;
  try
    for n in TNode.CloserNodes(GetInfoHash, FClosestNodes, GetClosestNodes(GetInfoHash),
      TBucket.MaxCapacity) do
      SendGetPeers(n);

    if FInitialized and (FSubtasks.Count = 0) then
      RaiseComplete
    else
    for it in FSubtasks do
      if not it.Busy then
        it.Sync;

    if not FInitialized then
      FInitialized := True;
  finally
    Unlock;
  end;
end;

function TGetPeersTask.GetClosestNodes(ATarget: TNodeID): TArray<INode>;
begin
  Result := FOnGetClosest(ATarget);
end;

procedure TGetPeersTask.Reset;
begin
  inherited Reset;

  FSubtasks.Clear;
  FClosestNodes.Clear;
  FQueriedNodes.Clear;
end;

function TGetPeersTask.GetClosestActiveNodes: TEnumerable<INode>;
begin
  Result := FQueriedNodes.Values;
end;

function TGetPeersTask.GetClosestActiveNodesCount: Integer;
begin
  Result := FQueriedNodes.Count;
end;

procedure TGetPeersTask.SendGetPeers(ANode: INode);
var
  distance: TNodeID;
begin
  Lock;
  try
    distance := ANode.ID xor GetInfoHash;
    FQueriedNodes.Add(distance, ANode);

    FSubtasks.Add(NewQueryTask(TGetPeers.Create(FLocalId, GetInfoHash), ANode,
      procedure (t: ITask; e: ICompleteEventArgs)
      var
        args: ISendQueryEventArgs;
        target: INode;
        index: Integer;
        response: IGetPeersResponse;
        n: INode;
      begin
        Lock;
        try
          FSubtasks.Remove(t);
        finally
          Unlock;
        end;

        // We want to keep a list of the top (K) closest nodes which have responded
        target := (t as ISendQueryTask).Target;
        index := FQueriedNodes.Values.IndexOf(target);
        args := e as ISendQueryEventArgs;
        if (index >= TBucket.MaxCapacity) or args.TimedOut then
          FQueriedNodes.Delete(index);

        if not args.TimedOut then
        begin
          response := args.Response as IGetPeersResponse;

          // Ensure that the local Node object has the token. There may/may not be
          // an additional copy in the routing table depending on whether or not
          // it was able to fit into the table.
          target.Token := response.Token;
          if Assigned(response.Values) then
            RaisePeersFound(TPeer.Decode(response.Values)); // We have actual peers!

          if response.Nodes.Len > 0 then
          begin
            // We got a list of nodes which are closer
            for n in TNode.CloserNodes(GetInfoHash, FClosestNodes,
              TNode.FromCompactNode(response.Nodes), TBucket.MaxCapacity) do
              SendGetPeers(n);
          end;
        end;
      end)
    );
  finally
    Unlock;
  end;
end;

{ TInitialiseTask }

constructor TInitialiseTask.Create(ALocalID: TNodeID; ANodes: TArray<INode>;
  AOnSendMessage: TProc<INode, IMessage, TProc<ISendQueryEventArgs>>);
begin
  inherited Create(ALocalID, AOnSendMessage);

  FInitialNodes := ANodes;
  FNodes := TSortedList<TNodeId, TNodeId>.Create(NodeIDSorter);
  FSubtasks := TList<ITask>.Create;
end;

destructor TInitialiseTask.Destroy;
begin
  FSubtasks.Free;
  FNodes.Free;
  inherited;
end;

procedure TInitialiseTask.DoSync;
var
  it: ITask;
begin
  Lock;
  try
    if not FInitialized then
    begin
      FInitialized := True;

      SendFindNode(FInitialNodes);
    end else
    begin
      for it in FSubtasks do
        if not it.Busy then
          it.Sync;

      if FSubtasks.Count = 0 then
        RaiseComplete;
    end;
  finally
    Unlock;
  end;
end;

procedure TInitialiseTask.SendFindNode(ANewNodes: TArray<INode>);
var
  n: INode;
begin
  Lock;
  try
    for n in TNode.CloserNodes(FLocalId, FNodes, ANewNodes, TBucket.MaxCapacity) do
    begin
      FSubtasks.Add(NewQueryTask(TFindNode.Create(FLocalId, FLocalId), n,
        procedure (t: ITask; e: ICompleteEventArgs)
        var
          args: ISendQueryEventArgs;
          response: IFindNodeResponse;
        begin
          Lock;
          try
            FSubtasks.Remove(t);
          finally
            Unlock;
          end;

          if Supports(e, ISendQueryEventArgs, args) and not args.TimedOut and
             Supports(args.Response, IFindNodeResponse, response) then
            SendFindNode(TNode.FromCompactNode(response.Nodes));
        end)
      );
    end;
  finally
    Unlock;
  end;
end;

{ TRefreshBucketTask }

constructor TRefreshBucketTask.Create(ALocalID: TNodeID; ABucket: IBucket;
  AOnSendMessage: TProc<INode, IMessage, TProc<ISendQueryEventArgs>>);
begin
  inherited Create(ALocalID, AOnSendMessage);

  FBucket := ABucket;
end;

procedure TRefreshBucketTask.DoSync;
begin
  Lock;
  try
    if not FInitialized then
    begin
      FInitialized := True;

      if FBucket.NodesCount = 0 then
        RaiseComplete
      else
      begin
        FBucket.SortBySeen;
        FSubTask := QueryNode(FBucket.Nodes.ToArray[0]);
      end;
    end else
    begin
      Assert(Assigned(FSubTask));

      if not FSubTask.Busy then
        FSubTask.Sync;
    end;
  finally
    Unlock;
  end;
end;

function TRefreshBucketTask.QueryNode(ANode: INode): ITask;
begin
  Result := NewQueryTask(TFindNode.Create(FLocalId, ANode.ID), ANode,
    procedure (t: ITask; e: ICompleteEventArgs)
    var
      args: ISendQueryEventArgs;
      index: Integer;
    begin
      if Supports(e, ISendQueryEventArgs, args) and args.TimedOut then
      begin
        FBucket.SortBySeen;
        index := FBucket.IndexOfNode(ANode);

        // непонятный код.
        if (index = -1) or (index + 1 < FBucket.NodesCount) then
          FSubTask := QueryNode(FBucket.Nodes.ToArray[0])
        else
          RaiseComplete;
      end else
        RaiseComplete;
    end
  );
end;

{ TAnnounceTask }

constructor TAnnounceTask.Create(ALocalID: TNodeID; AInfoHash: TNodeID;
  APort: TIdPort;
  AOnSendMessage: TProc<INode, IMessage, TProc<ISendQueryEventArgs>>;
  AOnGetClosest: TFunc<TNodeID, TArray<INode>>);
begin
  inherited Create(ALocalID, AInfoHash, AOnSendMessage);

  FOnGetClosest := AOnGetClosest;
  FPort         := APort;

  FSubtasks     := TList<ITask>.Create;
end;

destructor TAnnounceTask.Destroy;
begin
  FSubtasks.Free;
  inherited;
end;

procedure TAnnounceTask.DoSync;
var
  it: ITask;
begin
  Lock;
  try
    if not FInitialized then
    begin
      FInitialized := True;

      FSubtask := TGetPeersTask.Create(FLocalID, GetInfoHash, FOnSendMessage,
        FOnGetClosest);
      FSubtask.OnPeersFound := RaisePeersFound;
      FSubtask.OnCompleted := procedure (t1: ITask; e1: ICompleteEventArgs)
      var
        n: INode;
      begin
        Lock;
        try
          for n in (t1 as IGetPeersTask).ClosestActiveNodes do
            if not n.Token.Empty then
              FSubtasks.Add(NewQueryTask(TAnnouncePeer.Create(FLocalId, GetInfoHash,
                FPort, n.Token), n, procedure (t2: ITask; e2: ICompleteEventArgs)
                begin
                  FSubtasks.Remove(t2);
                end)
              );

          FSubtask := nil;
        finally
          Unlock;
        end;
      end;
    end else
    begin
      if Assigned(FSubtask) and not FSubtask.Busy then
        FSubtask.Sync;

      for it in FSubtasks do
        if not it.Busy then
          it.Sync;

      // если нода найдена и задачи анонсирования завешились
      if not Assigned(FSubtask) and (FSubtasks.Count = 0) then
        RaiseComplete;
    end;
  finally
    Unlock;
  end;
end;

function TAnnounceTask.GetPort: TIdPort;
begin
  Result := FPort;
end;

procedure TAnnounceTask.Reset;
begin
  inherited Reset;

  FSubtask := nil;
  FSubtasks.Clear;
end;

end.
