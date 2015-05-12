unit DHT.Engine;

interface

uses
  System.SysUtils, System.Generics.Collections, System.Generics.Defaults,
  System.DateUtils, System.TimeSpan, System.Classes,

  Spring.Collections, Spring.Collections.Lists, Spring.Collections.Dictionaries,
  Spring.Collections.Queues,

  Basic.BigInteger, Basic.UniString, Basic.Bencoding,
  Socket.Synsock, Socket.SynsockHelper,
  Common, Common.SortedList, Common.ThreadPool, Common.AccurateTimer,
  DHT.NodeID, DHT.Listener,
  UDP.Server,
  Hash,
  IdGlobal;

{$REGION 'синонимы коллекций, для сокращения и избежания коллизий дженериков со спрингом'}
type
  TSprList<T> = class(Spring.Collections.Lists.TList<T>);
  TGenList<T> = class(System.Generics.Collections.TList<T>);

  TSprObjectList<T: class>            = class(Spring.Collections.Lists.TObjectList<T>);
  TGenObjectList<T: class>            = class(System.Generics.Collections.TObjectList<T>);
  TGenDictionary<TKey, TValue>        = class(System.Generics.Collections.TDictionary<TKey, TValue>);
  TGenObjectDictionary<TKey, TValue>  = class(System.Generics.Collections.TObjectDictionary<TKey, TValue>);
{$ENDREGION}

type
  TErrorCode = (
    GenericError  = 201,
    ServerError   = 202,
    ProtocolError = 203,  // malformed packet, invalid arguments, or bad token
    MethodUnknown = 204   // Method Unknown
  );

  TNodeState = (nsUnknown, nsGood, nsQuestionable, nsBad);

  TDHTEngine = class;

  INode = interface
  ['{F0BB514B-E674-4AFA-BCA5-077E84DC646D}']
    {$REGION 'селекторы/модификаторы'}
    function GetState: TNodeState;
    function GetToken: TUniString;
    procedure SetToken(const Value: TUniString);
    function GetLastSeen: TDateTime;
    procedure SetLastSeen(const Value: TDateTime);
    function GetID: TNodeID;
    function GetFailedCount: Integer;
    procedure SetFailedCount(const Value: Integer);
    function GetEndPoint: TVarSin;
    {$ENDREGION}

    procedure Seen;

    function GetHashCode: Integer;
    function CompareTo(AOther: INode): Integer;
    function Equals(AOther: INode): Boolean;

    function CompactPort: TUniString;
    function CompactNode: TUniString;
    function BencodeNode: IBencodedDictionary;

    property EndPoint: TVarSin read GetEndPoint;
    property FailedCount: Integer read GetFailedCount write SetFailedCount;
    property ID: TNodeID read GetID;
    property LastSeen: TDateTime read GetLastSeen write SetLastSeen;
    property State: TNodeState read GetState;
    property Token: TUniString read GetToken write SetToken;
  end;

  IBucket = interface
  ['{083360ED-C773-478F-9B76-8F2A0D442B83}']
  {$REGION 'селекторы/модификаторы'}
    function GetLastChanged: TDateTime;
    procedure SetLastChanged(const Value: TDateTime);
    function GetMax: TNodeID;
    function GetMin: TNodeID;
    function GetNodes: TGenList<INode>;
    function GetReplacement: INode;
    procedure SetReplacement(const Value: INode);
  {$ENDREGION}

    function Add(ANode: INode): Boolean;
    procedure SortBySeen;

    function CanContain(ANode: INode): Boolean; overload;
    function CanContain(ANodeID: TNodeID): Boolean; overload;

    function CompareTo(AOther: IBucket): Integer;

    function Equals(AOther: IBucket): Boolean;
    function GetHashCode: Integer;
    function ToString: string;

    property LastChanged: TDateTime read GetLastChanged write SetLastChanged;
    property Max: TNodeID read GetMax;
    property Min: TNodeID read GetMin;
    property Nodes: TGenList<INode> read GetNodes;
    property Replacement: INode read GetReplacement write SetReplacement;
  end;

  IPeer = interface
  ['{5C5769BE-5359-48FC-B632-A56C59E1AB46}']
    {$REGION 'селекторы/модификаторы'}
    function GetConnectionUri: TVarSin;
    function GetCleanedUpCount: Integer;
    procedure SetCleanedUpCount(const Value: Integer);
    function GetTotalHashFails: Integer;
    procedure SetTotalHashFails(const Value: Integer);
    function GetPeerId: string;
    procedure SetPeerId(const Value: string);
    function GetIsSeeder: Boolean;
    procedure SetIsSeeder(const Value: Boolean);
    function GetFailedConnectionAttempts: Integer;
    procedure SetFailedConnectionAttempts(const Value: Integer);
    function GetLocalPort: TIdPort;
    procedure SetLocalPort(const Value: TIdPort);
    function GetLastConnectionAttempt: TDateTime;
    procedure SetLastConnectionAttempt(const Value: TDateTime);
    function GetRepeatedHashFails: Integer;
    {$ENDREGION}

    function CompactPeer: TUniString;
    procedure HashedPiece(ASucceeded: Boolean);

    property ConnectionUri: TVarSin read GetConnectionUri;
    property CleanedUpCount: Integer read GetCleanedUpCount write SetCleanedUpCount;
    property TotalHashFails: Integer read GetTotalHashFails write SetTotalHashFails;
    property PeerId: string read GetPeerId write SetPeerId;
    property IsSeeder: Boolean read GetIsSeeder write SetIsSeeder;
    property FailedConnectionAttempts: Integer read GetFailedConnectionAttempts write SetFailedConnectionAttempts;
    property LocalPort: TIdPort read GetLocalPort write SetLocalPort;
    property LastConnectionAttempt: TDateTime read GetLastConnectionAttempt write SetLastConnectionAttempt;
    property RepeatedHashFails: Integer read GetRepeatedHashFails;

    function Equals(AOther: IPeer): Boolean;
    function GetHashCode: Integer;
    function ToString: string;
  end;

{$REGION 'messages'}
  IMessage      = interface;
  IQueryMessage = interface;

  TCreator = TFunc<IBencodedDictionary, IMessage>;
  TResponseCreator = TFunc<IBencodedDictionary, IQueryMessage, IMessage>;

  IMessage              = interface
  ['{F2C3D311-94DC-4B49-AAFC-384E76ADBC48}']
    function GetID: TNodeID;
    function GetClientVersion: TUniString;
    function GetMessageType: TUniString;
    function GetTransactionID: IBencodedValue;
    procedure SetTransactionId(const Value: IBencodedValue);

    function GetSequenceID: UInt64;

    property ClientVersion: TUniString read GetClientVersion;
    property MessageType: TUniString read GetMessageType;
    property TransactionId: IBencodedValue read GetTransactionID write SetTransactionId;
    property ID: TNodeID read GetID;

    property SequenceID: UInt64 read GetSequenceID;

    function Encode: TUniString;

    procedure Handle(AEngine: TDHTEngine; ANode: INode);
  end;

  IQueryMessage         = interface(IMessage)
  ['{3EA9BF45-3CB8-427C-80BD-83CB297CE6B9}']
    function GetResponseCreator: TResponseCreator;
    function GetParameters: IBencodedDictionary;

    property ResponseCreator: TResponseCreator read GetResponseCreator;
    property Parameters: IBencodedDictionary read GetParameters;
  end;

  IResponseMessage      = interface(IMessage)
  ['{AF76945A-6958-4113-A99F-85DB4668768C}']
    function GetParameters: IBencodedDictionary;
    function GetQuery: IQueryMessage;

    property Parameters: IBencodedDictionary read GetParameters;
    property Query: IQueryMessage read GetQuery;
  end;

  IErrorMessage         = interface(IMessage)
  ['{6539F74B-F562-48FA-9495-1D9DA33547F4}']
    function GetErrorList: IBencodedList;
    function GetErrorCode: TErrorCode;
    function GetMessageText: string;

    property ErrorList: IBencodedList read GetErrorList;
    property ErrorCode: TErrorCode read GetErrorCode;
    property MessageText: string read GetMessageText;
  end;

  IAnnouncePeerResponse = interface(IResponseMessage)
  ['{04563A9E-F22A-4842-934F-6839C741FD66}']
  end;

  IGetPeersResponse     = interface(IResponseMessage)
  ['{F1A2D60D-E51D-4F4D-A1AC-4979CF29589E}']
    function GetToken: TUniString;
    procedure SetToken(const Value: TUniString);
    function GetNodes: TUniString;
    procedure SetNodes(const Value: TUniString);
    function GetValues: IBencodedList;
    procedure SetValues(const Value: IBencodedList);

    property Token: TUniString read GetToken write SetToken;
    property Nodes: TUniString read GetNodes write SetNodes;
    property Values: IBencodedList read GetValues write SetValues;
  end;

  IFindNodeResponse     = interface(IResponseMessage)
  ['{8E5EAE5F-A926-4435-819C-448046C42A8D}']
    function GetNodes: IBencodedString;
    procedure SetNodes(const Value: IBencodedString);

    property Nodes: IBencodedString read GetNodes write SetNodes;
  end;

  IPingResponse         = interface(IResponseMessage)
  ['{955569DD-BF73-4242-8B8D-E27D9A1F46D3}']
  end;

  IAnnouncePeer         = interface(IQueryMessage)
  ['{B623BC5A-5AC3-4A12-8E4A-227FFCC84A5A}']
    function GetInfoHash: TNodeID;
    function GetPort: TIdPort;
    function GetToken: TUniString;

    property InfoHash: TNodeID read GetInfoHash;
    property Port: TIdPort read GetPort;
    property Token: TUniString read GetToken;
  end;

  IFindNode             = interface(IQueryMessage)
  ['{DEDEA1AB-5225-4295-A329-0CA912B70494}']
    function GetTarget: TNodeID;

    property Target: TNodeID read GetTarget;
  end;

  IGetPeers             = interface(IQueryMessage)
  ['{798F3829-5D8A-4CEE-A24D-0EE8BD1F419F}']
    function GetInfoHash: TNodeID;

    property InfoHash: TNodeID read GetInfoHash;
  end;

  IPing                 = interface(IQueryMessage)
  ['{0730B787-F457-4A38-AC90-239821DBEAD2}']
  end;
{$ENDREGION}

{$REGION 'Tasks'}
  ITask                   = interface;

  ITaskCompleteEventArgs  = interface
  ['{CED233A8-7E65-4F32-B536-02109341A701}']
    function GetTask: ITask;
    procedure SetTask(Value: ITask);
    property Task: ITask read GetTask write SetTask;
  end;

  ITask                   = interface
  ['{7ACFDA3B-1E67-4955-A0E2-02C6C9816E0D}']
    procedure Execute;
    function GetOnCompleted: TGenList<TProc<ITaskCompleteEventArgs, IInterface>>;
    function GetActive: Boolean;

    property OnCompleted: TGenList<TProc<ITaskCompleteEventArgs, IInterface>> read GetOnCompleted;
    property Active: Boolean read GetActive;
  end;

  ISendQueryTask          = interface(ITask)
  ['{3BB84873-DAAB-425B-84E3-147EA4BF3232}']
    function GetNode: INode;

    property Target: INode read GetNode;
  end;

  IGetPeersTask           = interface(ITask)
  ['{C832DC19-7BF0-4B61-8582-7FAABFD51F5D}']
    function GetClosestActiveNodes: TSortedList<TNodeID, INode>;

    property ClosestActiveNodes: TSortedList<TNodeID, INode> read GetClosestActiveNodes;
  end;

  IInitialiseTask         = interface(ITask)
  ['{95E7679F-F296-44B9-8AA7-CEA12F0EB90C}']
  end;

  IRefreshBucketTask      = interface(ITask)
  ['{44FEBB0E-0DB4-4795-8F4A-EF9A9C592FF5}']
  end;

  IAnnounceTask           = interface(ITask)
  ['{6C586445-1D21-43C7-B41E-5F357E1793E5}']
  end;

  ISendQueryEventArgs     = interface(ITaskCompleteEventArgs)
  ['{3228A7BA-C521-481F-98FF-FE089E67065B}']
    function GetTimedOut: Boolean;
    function GetEndPoint: TVarSin;
    function GetQuery: IQueryMessage;
    function GetResponse: IResponseMessage;

    property EndPoint: TVarSin read GetEndPoint;
    property Query: IQueryMessage read GetQuery;
    property Response: IResponseMessage read GetResponse;
    property TimedOut: Boolean read GetTimedOut;
  end;
{$ENDREGION}

  IRoutingTable = interface
  ['{F3DE6C68-2BD3-4485-B6EC-BC1E841FC9DC}']
    function GetBuckets: TGenList<IBucket>;
    function GetLocalNode: INode;
    function GetOnAddNode: TProc<INode>;
    procedure SetOnAddNode(Value: TProc<INode>);

    function Add(ANode: INode): Boolean;
    procedure Clear;
    function CountNodes: Integer;
    function GetClosest(ATarget: TNodeID): IList<INode>;
    function FindNode(ANodeID: TNodeID): INode;

    property Buckets: TGenList<IBucket> read GetBuckets;
    property LocalNode: INode read GetLocalNode;

    property OnAddNode: TProc<INode> read GetOnAddNode write SetOnAddNode;
  end;

  ITokenManager = interface
  ['{3D057F6A-548B-465E-A91D-DA13B117480F}']
    function GetTimeout: TDateTime;
    procedure SetTimeout(Value: TDateTime);

    property Timeout: TDateTime read GetTimeout write SetTimeout;

    function GenerateToken(ANode: INode): TUniString;
    function VerifyToken(ANode: INode; AToken: TUniString): Boolean;
  end;

  IMessageLoop = interface
  ['{2C78F069-4FF2-485E-9D0C-1B6B7208F70E}']
    function GetOnQuerySent: TGenList<TFunc<ISendQueryEventArgs, Boolean>>;

    procedure LockQuerySent;
    procedure UnlockQuerySent;

    procedure Start;
    procedure Stop;

    procedure EnqueueSend(AMessage: IMessage; AEndPoint: TVarSin); overload;
    procedure EnqueueSend(AMessage: IMessage; ANode: INode); overload;

    property OnQuerySent: TGenList<TFunc<ISendQueryEventArgs, Boolean>> read GetOnQuerySent;
  end;

  TDHTEngine = class // -> interface
  public
    type
      TDHTState = (sNotReady, sBusy, sReady, sStop);
  private
    FPool: TThreadPool;
    FLock: TObject;
    FBootStrap: Boolean;
    FBucketRefreshTimeout: TTimeSpan;
    FDisposed: Boolean;
    FState: TDHTState;
    FRoutingTable: IRoutingTable;
    FTimeout: TTimeSpan;
    FTorrents: TGenObjectDictionary<TNodeID, TGenList<INode>>;
    FTokenManager: ITokenManager;
    FMessageLoop: IMessageLoop;
    FActiveTasks: Integer;
  private
    FOnPeersFound: TProc<TUniString, IList<IPeer>>;
    FOnStateChanged: TProc<TDHTState>;

    function GetLocalId: TNodeID;
  public
    class procedure RegisterOnStop(AHashCode: Integer; AOnStop: TProc); static;
    class procedure UnregisterOnStop(AHashCode: Integer); static;
  private
    class var FOnStop: TGenList<TPair<Integer, TProc>>;
    class var FOnStopLock: TObject;
    class constructor ClassCreate;
    class destructor ClassDestroy;
  public
    property BootStrap: Boolean read FBootStrap write FBootStrap;
    property BucketRefreshTimeout: TTimeSpan read FBucketRefreshTimeout write FBucketRefreshTimeout;
    property Disposed: Boolean read FDisposed;
    property LocalId: TNodeID read GetLocalId;
    property MessageLoop: IMessageLoop read FMessageLoop;
    property RoutingTable: IRoutingTable read FRoutingTable;
    property State: TDHTState read FState;
    property TimeOut: TTimeSpan read FTimeOut write FTimeOut;
    property TokenManager: ITokenManager read FTokenManager;
    property Torrents: TGenObjectDictionary<TNodeID, TGenList<INode>> read FTorrents;

    property OnPeersFound: TProc<TUniString, IList<IPeer>> read FOnPeersFound write FOnPeersFound;
    property OnStateChanged: TProc<TDHTState> read FOnStateChanged write FOnStateChanged;
  private
    procedure RequestChangeState; inline;
    function RefreshBuckets: Boolean;
  public
    constructor Create(APool: TThreadPool; AListener: TDHTListener; const ALocalID: TUniString);
    destructor Destroy; override;

    procedure CheckDisposed;
    procedure RegisterRequest; inline;
    procedure UnregisterRequest; inline;
    procedure RaiseStateChanged(ANewState: TDHTState);
    procedure RaisePeersFound(AInfoHash: TNodeID; APeers: IList<IPeer>);
    //procedure RaiseNodesFound();

    procedure Add(ANodes: IList<INode>); overload;
    procedure Add(ANode: INode); overload;

    procedure Lock; inline;
    procedure Unlock; inline;

    procedure Dispose;

    procedure Announce(const AInfoHash: TUniString; APort: TIdPort);
    procedure GetPeers(const AInfoHash: TUniString);

    function SaveNodes: IBencodedList;

    procedure Start; overload;
    procedure Start(AInitialNodes: IBencodedList); overload;
    procedure Stop;
  end;

  EDHTException     = class(Exception);
  EDHTEngine        = class(EDHTException);
  EMessageLoop      = class(EDHTException);
  EGetPeersResponse = class(EDHTException);
  EMessageFactory   = class(EDHTException);
  EErrorMessage     = class(EDHTException);

implementation

uses
  Winapi.Windows,
  DHT.RoutingTable, DHT.TokenManager, DHT.Tasks, DHT.Messages, DHT.Node,
  DHT.Messages.MessageLoop;

{ TDHTEngine }

procedure TDHTEngine.Announce(const AInfoHash: TUniString; APort: TIdPort);
begin
  Assert(AInfoHash.Len = TNodeID.NodeIDLen, 'Invalid AInfoHash length');

  CheckDisposed;

  with TAnnounceTask.Create(Self, FPool, AInfoHash, APort) as IAnnounceTask do
  begin
    OnCompleted.Add(procedure (e: ITaskCompleteEventArgs; ACaller: IInterface)
    begin
      UnregisterRequest;
    end);

    RegisterRequest;
    Execute;
  end;
end;

procedure TDHTEngine.Add(ANodes: IList<INode>);
var
  n: INode;
begin
  Assert(Assigned(ANodes), 'ANodes not defined');

  for n in ANodes do
    Add(n);
end;

procedure TDHTEngine.Add(ANode: INode);
begin
  Assert(Assigned(ANode), 'ANode not defined');

  with TSendQueryTask.Create(Self, FPool,
       TPing.Create(RoutingTable.LocalNode.ID),
       ANode) as ISendQueryTask do
    Execute;
end;

procedure TDHTEngine.CheckDisposed;
begin
  if FDisposed then
    raise EDHTEngine.Create('Object disposed');
end;

class constructor TDHTEngine.ClassCreate;
begin
  FOnStop := TGenList<TPair<Integer, TProc>>.Create;
  FOnStopLock := TObject.Create;
end;

class destructor TDHTEngine.ClassDestroy;
begin
  FOnStop.Free;
  FOnStopLock.Free;
end;

constructor TDHTEngine.Create(APool: TThreadPool; AListener: TDHTListener;
  const ALocalID: TUniString);
var
  s: TVarSin;
begin
  inherited Create;

  FLock := TObject.Create;
  FPool := APool;
  FActiveTasks := 0;
  FBootStrap := True;
  FBucketRefreshTimeout := TTimeSpan.FromMinutes(15);
  FState := sNotReady;

  if ALocalID.Len > 0 then
  begin
    s.Clear;
    FRoutingTable := TRoutingTable.Create(TNode.Create(TNodeID(ALocalID), s) as INode);
  end else
    FRoutingTable := TRoutingTable.Create;

  FTorrents := TGenObjectDictionary<TNodeID, TGenList<INode>>.Create([doOwnsValues],
    TDelegatedEqualityComparer<TNodeID>.Create(
      function (const ALeft, ARight: TNodeID): Boolean
      begin
        Result := ALeft.GetHashCode = ARight.GetHashCode;
      end,
      function (const AValue: TNodeID): Integer
      begin
        Result := AValue.GetHashCode;
      end
    ) as IEqualityComparer<TNodeID>);

  Assert(assigned(AListener));

  FMessageLoop  := TMessageLoop.Create(Self, FPool, AListener);
  FTimeout      := TTimeSpan.FromSeconds(15); // 15 second message timeout by default
  FTokenManager := TTokenManager.Create;
end;

destructor TDHTEngine.Destroy;
begin
  FTorrents.Free;
  FLock.Free;
  inherited;
end;

procedure TDHTEngine.Dispose;
var
  b: Boolean;
begin
  if FDisposed then
    Exit;

  b := True;

  FPool.Exec(function : Boolean
  begin
    Lock;
    try
      FDisposed := True;

      Common.Lock(FOnStop, procedure
      var
        i: Integer;
      begin
        for i := FOnStop.Count - 1 downto 0 do
          FOnStop[i].Value();

        FOnStop.Clear;
      end);

      b := False;
      Result := False;
    finally
      Unlock;
    end;
  end);

  while b do
    Sleep(1);
end;

function TDHTEngine.GetLocalId: TNodeID;
begin
  Result := FRoutingTable.LocalNode.ID;
end;

procedure TDHTEngine.GetPeers(const AInfoHash: TUniString);
begin
  Assert(AInfoHash.Len = TNodeID.NodeIDLen);

  CheckDisposed;

  with TGetPeersTask.Create(Self, FPool, AInfoHash) as IGetPeersTask do
  begin
    OnCompleted.Add(procedure (e: ITaskCompleteEventArgs; ACaller: IInterface)
    begin
      UnregisterRequest;
    end);

    RegisterRequest;
    Execute;
  end;
end;

procedure TDHTEngine.Lock;
begin
  TMonitor.Enter(FLock);
end;

procedure TDHTEngine.RaisePeersFound(AInfoHash: TNodeID; APeers: IList<IPeer>);
begin
  if Assigned(FOnPeersFound) then
    FOnPeersFound(AInfoHash.AsUniString, APeers);
end;

procedure TDHTEngine.RaiseStateChanged(ANewState: TDHTState);
begin
  FState := ANewState;

  if Assigned(FOnStateChanged) then
    FOnStateChanged(FState);
end;

function TDHTEngine.RefreshBuckets: Boolean;
var
  b: IBucket;
begin
  Result := not FDisposed;

  if Result then
  begin
    Lock;
    try
      for b in RoutingTable.Buckets do
        if TTimeSpan.Subtract(UtcNow, b.LastChanged) > FBucketRefreshTimeout then
        begin
          b.LastChanged := UtcNow;

          with TRefreshBucketTask.Create(Self, FPool, b) as IRefreshBucketTask do
            Execute;
        end;
    finally
      Unlock;
    end;
  end;

  Sleep(100);
end;

class procedure TDHTEngine.RegisterOnStop(AHashCode: Integer; AOnStop: TProc);
begin
  TMonitor.Enter(FOnStopLock);
  try
    FOnStop.Add(TPair<Integer, TProc>.Create(AHashCode, AOnStop));
  finally
    TMonitor.Exit(FOnStopLock);
  end;
end;

procedure TDHTEngine.RegisterRequest;
begin
  AtomicIncrement(FActiveTasks);
  RequestChangeState;
end;

function TDHTEngine.SaveNodes: IBencodedList;
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
      for b in RoutingTable.Buckets do
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
end;

procedure TDHTEngine.Start;
begin
  Start(BencodedList);
end;

procedure TDHTEngine.Start(AInitialNodes: IBencodedList);
begin
  CheckDisposed;

  FMessageLoop.Start;
  if FBootStrap then
  begin
    RegisterRequest;

    with TInitialiseTask.Create(Self, FPool, AInitialNodes) as IInitialiseTask do
      Execute;

    //RaiseStateChanged(sInitialising);
    FBootStrap := False;
  end else
    RaiseStateChanged(sReady);

  FPool.Exec(RefreshBuckets);
end;

procedure TDHTEngine.Stop;
begin
  Dispose;
  RaiseStateChanged(sStop);
  FMessageLoop.Stop;
end;

procedure TDHTEngine.RequestChangeState;
begin
  if not (FState in [sStop{, sInitialising}]) then
  begin
    if FActiveTasks = 0 then
      RaiseStateChanged(sReady)
    else
      RaiseStateChanged(sBusy);
  end;
end;

procedure TDHTEngine.Unlock;
begin
  TMonitor.Exit(FLock);
end;

class procedure TDHTEngine.UnregisterOnStop(AHashCode: Integer);
var
  i: Integer;
begin
  TMonitor.Enter(FOnStopLock);
  try
    for i := FOnStop.Count - 1 downto 0 do
      if FOnStop[i].Key = AHashCode then
      begin
        FOnStop.Delete(i);
        Exit;
      end;
  finally
    TMonitor.Exit(FOnStopLock);
  end;
end;

procedure TDHTEngine.UnregisterRequest;
begin
  AtomicDecrement(FActiveTasks);
  RequestChangeState;
end;

end.
