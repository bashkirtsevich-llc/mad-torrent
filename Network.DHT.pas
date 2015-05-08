unit Network.DHT;

interface

uses
  System.SysUtils, System.Generics.Collections, System.Generics.Defaults,
  System.DateUtils, System.TimeSpan, System.Classes,

  Spring.Collections, Spring.Collections.Lists, Spring.Collections.Dictionaries,
  Spring.Collections.Queues,

  Basic.BigInteger, Basic.UniString, Basic.Bencoding,
  Core.Basics, Core.Basics.Thread,
  Socket.Synsock, Socket.SynsockHelper,
  Common.Utils, Common.SortedList,
  Network.Basic, Network.UDP;

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

  TNodeID = record
  public
    const
      NODE_ID_LEN = 20;
  private
    FValue: TBigInteger;
  public
    function AsUniString: TUniString;
    procedure FillRandom;

    function CompareTo(AOther: TNodeID): Integer;
    function Equals(AOther: TNodeID): Boolean;
    class function New: TNodeID; static;
  public
    class operator Implicit(A: TBytes): TNodeID;
    class operator Implicit(A: Cardinal): TNodeID;
    class operator Implicit(A: TUniString): TNodeID;

    class operator Add(A, B: TNodeID): TNodeID;
    class operator Subtract(A, B: TNodeID): TNodeID;

    class operator Equal(A: TNodeID; B: TNodeID): Boolean;
    class operator NotEqual(A: TNodeID; B: TNodeID): Boolean;

    class operator GreaterThan(A, B: TNodeID): Boolean;
    class operator LessThan(A, B: TNodeID): Boolean;

    class operator GreaterThanOrEqual(A, B: TNodeID): Boolean;
    class operator LessThanOrEqual(A, B: TNodeID): Boolean;

    class operator BitwiseXor(A, B: TNodeID): TNodeID;
    class operator IntDivide(A: TNodeID; B: Integer): TNodeID;
  public
    function GetHashCode: Integer;
  end;

  TNodeState = (nsUnknown, nsGood, nsQuestionable, nsBad);

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

  TRoutingTable = class
  private
    FOnAddNode: TProc<INode>;
    FLocalNode: INode;
    FBuckets: TGenList<IBucket>;
  private
    procedure RaiseNodeAdded(ANode: INode); inline;

    function Add(ANode: INode; ARaiseNodeAdded: Boolean): Boolean; overload;
    procedure Add(ABucket: IBucket); overload;

    function FindNode(ANodeID: TNodeID): INode;

    procedure Remove(ABucket: IBucket); inline;
    function Split(ABucket: IBucket): Boolean;

    procedure Clear;
  public
    function Add(ANode: INode): Boolean; overload;
    function CountNodes: Integer;
    function GetClosest(ATarget: TNodeID): IList<INode>;
  public
    property Buckets: TGenList<IBucket> read FBuckets;
    property LocalNode: INode read FLocalNode;
  public
    constructor Create; overload;
    constructor Create(ALocalNode: INode); overload;
    destructor Destroy; override;
  public
    property OnAddNode: TProc<INode> read FOnAddNode write FOnAddNode;
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
    function GetLocalPort: Word;
    procedure SetLocalPort(const Value: Word);
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
    property LocalPort: Word read GetLocalPort write SetLocalPort;
    property LastConnectionAttempt: TDateTime read GetLastConnectionAttempt write SetLastConnectionAttempt;
    property RepeatedHashFails: Integer read GetRepeatedHashFails;

    function Equals(AOther: IPeer): Boolean;
    function GetHashCode: Integer;
    function ToString: string;
  end;

  TDHTListener = class(TListener)
  { nothing to override }
  end;

  TDHTEngine        = class;
  IMessage          = interface;

  IQueryMessage     = interface;
  IResponseMessage  = interface;

  TCreator = TFunc<IBencodedDictionary, IMessage>;
  TResponseCreator = TFunc<IBencodedDictionary, IQueryMessage, IMessage>;

  TMessageFactory = class { static class }
  private
    const
      QueryNameKey      = 'q';
      MessageTypeKey    = 'y';
      TransactionIdKey  = 't';

    class var FMessages: TGenDictionary<IBencodedValue, IQueryMessage>;
    class var FQueryDecoders: TGenDictionary<IBencodedString, TCreator>;
  public
    class function RegisteredMessages: Integer; static;
    class procedure RegisterSend(AMessage: IQueryMessage); static;
    class function UnregisterSend(AMessage: IQueryMessage): Boolean; static;
    class function DecodeMessage(ADict: IBencodedDictionary): IMessage; static; deprecated 'не используется';
    class function TryDecodeMessage(ADict: IBencodedDictionary;
      out AMsg: IMessage): Boolean; overload; static;
    class function TryDecodeMessage(ADict: IBencodedDictionary; out AMsg: IMessage;
      out AError: string): Boolean; overload; static;
    class function IsRegistered(ATransactionId: IBencodedValue): Boolean; static;

    class constructor ClassCreate;
    class destructor ClassDestroy;
  end;

  ISendQueryEventArgs = interface;

  TMessageLoop = class
  private
    type
      ISendDetails = interface
      ['{BB733FE2-683E-479C-85E2-E595E0B33711}']
        function GetDestination: TVarSin;
        {procedure SetDestination(const Value: TVarSin);}
        function GetMsg: IMessage;
        {procedure SetMsg(const Value: TMessage);}
        function GetSentAt: TDateTime;
        procedure SetSentAt(const Value: TDateTime);

        property Destination: TVarSin read GetDestination {write SetDestination};
        property Msg: IMessage read GetMsg {write SetMsg};
        property SentAt: TDateTime read GetSentAt write SetSentAt;
      end;

      TSendDetails = class(TInterfacedObject, ISendDetails)
      private
        FDestination: TVarSin;
        FMsg: IMessage;
        FSentAt: TDateTime;
      private
        function GetDestination: TVarSin;
        {procedure SetDestination(const Value: TVarSin);}
        function GetMsg: IMessage;
        {procedure SetMsg(const Value: TMessage);}
        function GetSentAt: TDateTime;
        procedure SetSentAt(const Value: TDateTime);
      public
        constructor Create(ADest: TVarSin; AMsg: IMessage);
      end;

      TTransactionID = class
      private
        class var FCurrent: array [0..1] of Byte;
        class var FLock: TObject;

        class constructor ClassCreate;
        class destructor ClassDestroy;
      public
        class function NextID: IBencodedString;
      end;
  private
    FOnQuerySent: TGenList<TFunc<ISendQueryEventArgs, {Handled:} Boolean>>;
    FEngine: TDHTEngine;
    FLastSent: TDateTime;
    FListener: TDHTListener;
    FSendQueue: TQueue<ISendDetails>;
    FReceiveQueue: TQueue<TPair<TVarSin, IMessage>>;
    FWaitingResponse: TGenList<ISendDetails>;
    function CanSend: Boolean;

    procedure SendMessage; overload;
    procedure SendMessage(AMsg: IMessage; ADest: TVarSin); overload;
    procedure ReceiveMessage;
    procedure TimeoutMessage;

    procedure RaiseMessageSent(AEndPoint: TVarSin; AQuery: IQueryMessage;
      AResponse: IResponseMessage);

    procedure EnqueueSend(AMessage: IMessage; AEndPoint: TVarSin); overload;
    procedure EnqueueSend(AMessage: IMessage; ANode: INode); overload;

    procedure Start;
    procedure Stop;
  public
    constructor Create(AEngine: TDHTEngine; AListener: TDHTListener);
    destructor Destroy; override;

    property OnQuerySent: TGenList<TFunc<ISendQueryEventArgs, Boolean>> read FOnQuerySent;
  end;

  TTokenManager = class
  private
    FSecret: TUniString;
    FPreviousSecret: TUniString;
    FLastSecretGeneration: TDateTime;
    FTimeout: TDateTime;
    function GetToken(ANode: INode; s: TUniString): TUniString;
  public
    property Timeout: TDateTime read FTimeout write FTimeout;
    function GenerateToken(ANode: INode): TUniString;
    function VerifyToken(ANode: INode; AToken: TUniString): Boolean;

    constructor Create;
  end;

  TDHTEngine = class
  public
    type
      TDHTState = (sNotReady, sBusy, sReady, sStop);
  private
    FBootStrap: Boolean;
    FBucketRefreshTimeout: TTimeSpan;
    FDisposed: Boolean;
    FState: TDHTState;
    FRoutingTable: TRoutingTable;
    FTimeout: TTimeSpan;
    FTorrents: TGenObjectDictionary<TNodeID, TGenList<INode>>;
    FTokenManager: TTokenManager;
    FMessageLoop: TMessageLoop;
    FActiveTasks: Integer;
  private
    FOnPeersFound: TProc<TUniString, IList<IPeer>>;
    FOnStateChanged: TProc<TDHTState>;

    function GetLocalId: TNodeID;
    //procedure SetTorrents(const Value: TGenObjectDictionary<TNodeID, TGenList<INode>>); deprecated;
  private
    class var FOnStop: TGenList<TProc>;
    class constructor ClassCreate;
    class destructor ClassDestroy;
  public
    property BootStrap: Boolean read FBootStrap write FBootStrap;
    property BucketRefreshTimeout: TTimeSpan read FBucketRefreshTimeout write FBucketRefreshTimeout;
    property Disposed: Boolean read FDisposed;
    property LocalId: TNodeID read GetLocalId;
    property MessageLoop: TMessageLoop read FMessageLoop;
    property RoutingTable: TRoutingTable read FRoutingTable;
    property State: TDHTState read FState;
    property TimeOut: TTimeSpan read FTimeOut write FTimeOut;
    property TokenManager: TTokenManager read FTokenManager;
    property Torrents: TGenObjectDictionary<TNodeID, TGenList<INode>> read FTorrents; // write SetTorrents;

    property OnPeersFound: TProc<TUniString, IList<IPeer>> read FOnPeersFound write FOnPeersFound;
    property OnStateChanged: TProc<TDHTState> read FOnStateChanged write FOnStateChanged;
  private
    procedure RequestChangeState; inline;
    procedure RegisterRequest; inline;
    procedure UnregisterRequest; inline;
  private
    procedure Add(ANodes: IList<INode>); overload;
    procedure Add(ANode: INode); overload;
    procedure CheckDisposed;
    procedure RaiseStateChanged(ANewState: TDHTState);
    procedure RaisePeersFound(AInfoHash: TNodeID; APeers: IList<IPeer>);
  public
    constructor Create(AListener: TDHTListener; ALocalID: TUniString);
    destructor Destroy; override;

    procedure Dispose;

    procedure Announce(AInfoHash: TUniString; APort: Word);
    procedure GetPeers(AInfoHash: TUniString);

    function SaveNodes: IBencodedList;

    procedure Start; overload;
    procedure Start(AInitialNodes: IBencodedList); overload;
    procedure Stop;
  end;

  TDHTThread = class(TBasicThread)
  private
    const
      QueueDelayInterval = 30; // секунд (сделать меньше?)
    type
      TRequestType = (rtAnnounce, rtGetPeers);

      TRequestInfo = record
        RequestType : TRequestType;
        InfoHash    : TUniString;
        Port        : Word;

        function IsEqual(const AOther: TRequestInfo): Boolean;

        constructor Create(ARequestType: TRequestType;
          const AInfoHash: TUniString); overload;
        constructor Create(ARequestType: TRequestType;
          const AInfoHash: TUniString; APort: Word); overload;
      end;
  private
    FDHTEngine: TDHTEngine;
    FOnDHTPeersFound: TProc<TUniString, IList<IPeer>>;
    FIsReady: Boolean;
    FOnDHTReady,
    FOnDHTStop: TProc;
    FRequestQueue: TQueue<TRequestInfo>;

    function GetSaveNodes: TUniString;
    procedure SetOnDHTPeersFound(const Value: TProc<TUniString, IList<IPeer>>);
  protected
    procedure Execute; override;
  public
    procedure Start; overload;
    procedure Start(AInitialNodes: IBencodedList); overload;
    procedure Stop;

    procedure Announce(const AInfoHash: TUniString; APort: Word);
    procedure GetPeers(const AInfoHash: TUniString);

    property IsReady: Boolean read FIsReady;
    property SaveNodes: TUniString read GetSaveNodes;
    property OnDHTPeersFound: TProc<TUniString, IList<IPeer>> read FOnDHTPeersFound write SetOnDHTPeersFound;
    property OnDHTReady: TProc read FOnDHTReady write FOnDHTReady;
    property OnDHTStop: TProc read FOnDHTStop write FOnDHTStop;

    constructor Create(AAF, APort: Word; const ALocalID: TUniString); reintroduce;
    destructor Destroy; override;
  end;

{$REGION 'messages'}
  IMessage              = interface
  ['{F2C3D311-94DC-4B49-AAFC-384E76ADBC48}']
    function GetID: TNodeID;
    function GetClientVersion: TUniString;
    function GetMessageType: TUniString;
    function GetTransactionID: IBencodedValue;
    procedure SetTransactionId(const Value: IBencodedValue);

    function GetAsObject: TObject;

    property ClientVersion: TUniString read GetClientVersion;
    property MessageType: TUniString read GetMessageType;
    property TransactionId: IBencodedValue read GetTransactionID write SetTransactionId;
    property ID: TNodeID read GetID;

    property AsObject: TObject read GetAsObject;

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
    function GetPort: Word;
    function GetToken: TUniString;

    property InfoHash: TNodeID read GetInfoHash;
    property Port: Word read GetPort;
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

{$REGION 'tasks'}
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

{$REGION 'exceptions'}
  EDHTException     = class(Exception);
  EDHTEngine        = class(EDHTException);
  EMessageLoop      = class(EDHTException);
  EGetPeersResponse = class(EDHTException);
  EMessageFactory   = class(EDHTException);
  EErrorMessage     = class(EDHTException);
{$ENDREGION}

implementation

uses
  Winapi.Windows;

type
  TNode = class(TInterfacedObject, INode)
  private
    const
      MaxFailures = 4;
    const
      IDKey   = 'id';
      NodeKey = 'node';
  private
    FEndPoint: TVarSin;
    FID: TNodeID;
    FFailedCount: Integer;
    FLastSeen: TDateTime;
    FToken: TUniString;
    function GetState: TNodeState; inline;
    function GetToken: TUniString; inline;
    procedure SetToken(const Value: TUniString); inline;
    function GetLastSeen: TDateTime; inline;
    procedure SetLastSeen(const Value: TDateTime); inline;
    function GetID: TNodeID; inline;
    function GetFailedCount: Integer; inline;
    procedure SetFailedCount(const Value: Integer); inline;
    function GetEndPoint: TVarSin; inline;
    procedure Seen; inline;

    function CompactPort: TUniString; overload; inline;
    function CompactNode: TUniString; overload; inline;
    function BencodeNode: IBencodedDictionary; overload;

    class function CompactPort(ASinAddr: TVarSin): TUniString; overload; static;
    class function CompactPort(APeers: IList<TVarSin>): TUniString; overload; static;
    class function CompactNode(ANode: INode): TUniString; overload; static;
    class function CompactNode(ANodes: IList<INode>): TUniString; overload; static;
    class function BencodeNode(ANode: INode): IBencodedDictionary; overload; static;
    class function BencodeNode(ANodes: IList<INode>): IBencodedList; overload; static;

    class function CloserNodes(
      ATarger: TNodeID;
      ACurrentNodes: TSortedList<TNodeId, TNodeId>;
      ANewNodes: IList<INode>; AMaxNodes: Integer): IList<INode>; static;
    class function FromCompactNode(ABuf: TUniString): IList<INode>; static;
    class function FromBencodedNode(ANodes: IBencodedList): IList<INode>; static;
  public
    constructor Create(ANodeID: TNodeID; AEndPoint: TVarSin);
    function GetHashCode: Integer; override;
  public
    function CompareTo(AOther: INode): Integer;
    function Equals(AOther: INode): Boolean; reintroduce;
  end;

  TBucket = class(TInterfacedObject, IBucket)
  public
    const
      MaxCapacity: Integer = 8;
  private
    FLastChanged: TDateTime;
    FMin, FMax: TNodeID;
    FNodes: TGenList<INode>;
    FReplacement: INode;
    function GetLastChanged: TDateTime; inline;
    procedure SetLastChanged(const Value: TDateTime); inline;
    function GetMax: TNodeID; inline;
    function GetMin: TNodeID; inline;
    function GetNodes: TGenList<INode>; inline;
    function GetReplacement: INode; inline;
    procedure SetReplacement(const Value: INode); inline;
  public
    constructor Create; reintroduce; overload;
    constructor Create(AMin, AMax: TNodeID); overload;
    destructor Destroy; override;
  public
    function Add(ANode: INode): Boolean;
    procedure SortBySeen;

    function CanContain(ANode: INode): Boolean; overload; inline;
    function CanContain(ANodeID: TNodeID): Boolean; overload; inline;

    function CompareTo(AOther: IBucket): Integer;

    function Equals(AOther: IBucket): Boolean; reintroduce;
  public
    function GetHashCode: Integer; override;
    function ToString: string; override;
  end;

  TPeer = class(TInterfacedObject, IPeer)
  private
    FCleanedUpCount: Integer;
    FConnectionUri: TVarSin;
    //encryption: TEncryptionTypes;
    FFailedConnectionAttempts: Integer;
    FLocalPort: Word;
    FTotalHashFails: Integer;
    FIsSeeder: Boolean;
    FPeerId: string;
    FRepeatedHashFails: Integer;
    FLastConnectionAttempt: TDateTime;
    function CompactPeer: TUniString; inline;
    procedure HashedPiece(ASucceeded: Boolean);

    class function DecodeFromDict(ADict: IBencodedDictionary): IPeer; static;
    class function Encode(APeers: IList<IPeer>): IBencodedList; static;

    function GetConnectionUri: TVarSin; inline;
    function GetCleanedUpCount: Integer; inline;
    procedure SetCleanedUpCount(const Value: Integer); inline;
    function GetTotalHashFails: Integer; inline;
    procedure SetTotalHashFails(const Value: Integer); inline;
    function GetPeerId: string; inline;
    procedure SetPeerId(const Value: string); inline;
    function GetIsSeeder: Boolean; inline;
    procedure SetIsSeeder(const Value: Boolean); inline;
    function GetFailedConnectionAttempts: Integer; inline;
    procedure SetFailedConnectionAttempts(const Value: Integer); inline;
    function GetLocalPort: Word; inline;
    procedure SetLocalPort(const Value: Word); inline;
    function GetLastConnectionAttempt: TDateTime; inline;
    procedure SetLastConnectionAttempt(const Value: TDateTime); inline;
    function GetRepeatedHashFails: Integer; inline;
  public
    constructor Create(APeerID: string; AConnectionUri: TVarSin);
    function Equals(AOther: IPeer): Boolean; reintroduce;
    function GetHashCode: Integer; override;
    function ToString: string; override;

    class function Decode(APeers: IBencodedList): IList<IPeer>; overload; static;
    class function Decode(APeers: TUniString): IList<IPeer>; overload; static;
  end;

{$REGION 'EventArgs implementation'}
  TTaskCompleteEventArgs = class(TInterfacedObject, ITaskCompleteEventArgs)
  private
    FTask: ITask;
  public
    function GetTask: ITask; inline;
    procedure SetTask(Value: ITask); inline;
    constructor Create(ATask: ITask);
  end;

  TSendQueryEventArgs = class(TTaskCompleteEventArgs, ISendQueryEventArgs)
  private
    FResponse: IResponseMessage;
    FQuery: IQueryMessage;
    FEndPoint: TVarSin;
  private
    function GetTimedOut: Boolean; inline;
    function GetEndPoint: TVarSin; inline;
    function GetQuery: IQueryMessage; inline;
    function GetResponse: IResponseMessage; inline;
  public
    constructor Create(AEndPoint: TVarSin; AQuery: IQueryMessage;
      AResponse: IResponseMessage); overload;
  end;
{$ENDREGION}

{$REGION 'tasks implementation'}
  TTask = class(TInterfacedObject, ITask)
  private
    FOnStop: TProc;
    FOnCompleted: TGenList<TProc<ITaskCompleteEventArgs, IInterface>>;
    function GetOnCompleted: TGenList<TProc<ITaskCompleteEventArgs, IInterface>>; inline;
    function GetActive: Boolean; inline;
  private
    procedure Stop; inline;
  protected
    FActive: Boolean;
    procedure RaiseComplete(AEventArgs: ITaskCompleteEventArgs); virtual;
  public
    procedure Execute; virtual; abstract;
    procedure AfterConstruction; override;
    destructor Destroy; override;
  end;

  TSendQueryTask = class(TTask, ISendQueryTask)
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

    constructor Create(AEngine: TDHTEngine; AQuery: IQueryMessage; ANode: INode;
      ARetries: Integer); overload;
    constructor Create(AEngine: TDHTEngine; AQuery: IQueryMessage; ANode: INode); overload;
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
  protected
    procedure RaiseComplete(AEventArgs: ITaskCompleteEventArgs); override;
  public
    constructor Create(AEngine: TDHTEngine; AInfoHash: TNodeID);
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

    constructor Create(AEngine: TDHTEngine); overload;
    constructor Create(AEngine: TDHTEngine; AInitialNodes: TUniString); overload;
    constructor Create(AEngine: TDHTEngine; AInitialNodes: IBencodedList); overload;
    constructor Create(AEngine: TDHTEngine; ANodes: IList<INode>); overload;
    destructor Destroy; override;
  end;

  TRefreshBucketTask = class(TTask, IRefreshBucketTask)
  private
    FEngine: TDHTEngine;
    FBucket: IBucket;
    FMsg: IFindNode;
    FNode: INode;
    procedure QueryNode(ANode: INode);
  public
    constructor Create(AEngine: TDHTEngine; ABucket: IBucket);
    procedure Execute; override;
  end;

  TAnnounceTask = class(TTask, IAnnounceTask)
  private
    FActiveAnnounces: Integer;
    FInfoHash: TNodeId;
    FEngine: TDHTEngine;
    FPort: Word;
  protected
    procedure RaiseComplete(AEventArgs: ITaskCompleteEventArgs); override;
  public
    constructor Create(AEngine: TDHTEngine; AInfoHash: TUniString; APort: Word); overload;
    constructor Create(AEngine: TDHTEngine; AInfoHash: TNodeID; APort: Word); overload;
    procedure Execute; override;
  end;
{$ENDREGION}

{$REGION 'messages implementation'}
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
    function GetID: TNodeID; virtual; abstract;
  private
    function GetClientVersion: TUniString; inline;
    function GetMessageType: TUniString; inline;
    function GetTransactionID: IBencodedValue; inline;
    procedure SetTransactionId(const Value: IBencodedValue); inline;
    function GetAsObject: TObject; inline;
  public
    constructor Create(AMessageType: IBencodedString); overload;
    constructor Create(ADictionary: IBencodedDictionary); overload;
    destructor Destroy; override;

    function Encode: TUniString; virtual;

    procedure Handle(AEngine: TDHTEngine; ANode: INode); virtual;
  end;

  TQueryMessage = class(TMessage, IQueryMessage)
  private
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
  private
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
    constructor Create(AError: TErrorCode; AMessage: string); overload;
    procedure Handle(AEngine: TDHTEngine; ANode: INode); override;
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
    function GetPort: Word;
    function GetToken: TUniString;
  public
    procedure Handle(AEngine: TDHTEngine; ANode: INode); override;

    constructor Create(AID, AInfoHash: TNodeID; APort: Word; AToken: TUniString); overload;
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
    procedure Handle(AEngine: TDHTEngine; ANode: INode); override;
  public
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
{$ENDREGION}

{$REGION 'utils'}
function UtcNow: TDateTime;
var
  st1, st2: TSystemTime;
  tz: TTimeZoneInformation;
begin
  // TZ - локальные (Windows) настройки
  GetTimeZoneInformation(tz);

  // т.к. надо будет делать обратное преобразование - инвертируем bias
  tz.Bias := -tz.Bias;
  tz.StandardBias := -tz.StandardBias;
  tz.DaylightBias := -tz.DaylightBias;

  DateTimeToSystemTime(Now, st1);

  // Применение локальных настроек ко времени
  SystemTimeToTzSpecificLocalTime(@tz, st1, st2);

  // Приведение WindowsSystemTime к TDateTime
  Result := SystemTimeToDateTime(st2);
end;

function NodeIDSorter: IComparer<TNodeId>;
begin
  Result := TDelegatedComparer<TNodeId>.Create(
    function (const Left, Right: TNodeId): Integer
    begin
      if Left < Right then
        Result := -1
      else
      if Left > Right then
        Result := 1
      else
        Result := 0;
    end
  );
end;
{$ENDREGION}

{ TBucket }

function TBucket.Add(ANode: INode): Boolean;
var
  i: Integer;
begin
  if FNodes.Count < MaxCapacity then
  begin
    FNodes.Add(ANode);
    FLastChanged := UtcNow;
    Exit(True);
  end;

  for i := FNodes.Count - 1 downto 0 do
  begin
    if FNodes[i].State <> TNodeState.nsBad then
      continue;

    FNodes.Delete(i);
    FNodes.Add(ANode);
    FLastChanged := Now;
    Exit(True);
  end;

  Result := False;
end;

function TBucket.CanContain(ANodeID: TNodeID): Boolean;
begin
  Result := (FMin <= ANodeID) and (FMax > ANodeID);
end;

function TBucket.CanContain(ANode: INode): Boolean;
begin
  Assert(Assigned(ANode), 'ANode not defined');

  Result := CanContain(ANode.ID);
end;

function TBucket.CompareTo(AOther: IBucket): Integer;
begin
  Result := FMin.CompareTo(AOther.Min);
end;

constructor TBucket.Create;
var
  a, b: TBytes;
begin
  SetLength(a, TNodeID.NODE_ID_LEN);
  SetLength(b, TNodeID.NODE_ID_LEN);

  FillChar(b[0], TNodeID.NODE_ID_LEN, $FF);

  Create(a, b);
end;

constructor TBucket.Create(AMin, AMax: TNodeID);
begin
  FMin := AMin;
  FMax := AMax;

  FLastChanged := UtcNow;

  FNodes := TGenList<INode>.Create;
end;

destructor TBucket.Destroy;
begin
  FNodes.Free;
  inherited;
end;

function TBucket.Equals(AOther: IBucket): Boolean;
begin
  Result := FMin.Equals(AOther.Min) and FMax.Equals(AOther.Max);
end;

function TBucket.GetHashCode: Integer;
begin
  Result := FMin.GetHashCode xor FMax.GetHashCode;
end;

function TBucket.GetLastChanged: TDateTime;
begin
  Result := FLastChanged;
end;

function TBucket.GetMax: TNodeID;
begin
  Result := FMax;
end;

function TBucket.GetMin: TNodeID;
begin
  Result := FMin;
end;

function TBucket.GetNodes: TGenList<INode>;
begin
  Result := FNodes;
end;

function TBucket.GetReplacement: INode;
begin
  Result := FReplacement;
end;

procedure TBucket.SetLastChanged(const Value: TDateTime);
begin
  FLastChanged := Value;
end;

procedure TBucket.SetReplacement(const Value: INode);
begin
  FReplacement := Value;
end;

procedure TBucket.SortBySeen;
begin
  FNodes.Sort;
end;

function TBucket.ToString: string;
begin
  //Result := Format('Count: %d Min: {0}  Max: {1}', [FMin, FMax, FNodes.Count]);
end;

{ TRoutingTable }

constructor TRoutingTable.Create;
var
  s: TVarSin;
begin
  s.Clear;
  Create(TNode.Create(TNodeID.New, s) as INode);
end;

function TRoutingTable.Add(ANode: INode): Boolean;
begin
  Result := Add(ANode, True);
end;

function TRoutingTable.Add(ANode: INode; ARaiseNodeAdded: Boolean): Boolean;
var
  bucket: IBucket;
  added: Boolean;
begin
  Assert(Assigned(ANode), 'ANode not defined');

  bucket := nil;

  for bucket in FBuckets do
    if bucket.CanContain(ANode) then
      Break;

  if Assigned(bucket) then
  begin
    if bucket.Nodes.Contains(ANode) then
      Exit(False);

    added := bucket.Add(ANode);
    if added and ARaiseNodeAdded then
      RaiseNodeAdded(ANode);

    if ((not added) and bucket.CanContain(FLocalNode)) and Split(bucket) then
      Exit(Add(ANode, ARaiseNodeAdded));

    Result := added;
  end else
    Result := False;
end;

procedure TRoutingTable.Add(ABucket: IBucket);
begin
  FBuckets.Add(ABucket);
  FBuckets.Sort;
end;

procedure TRoutingTable.Clear;
begin
  FBuckets.Clear;
  Add(TBucket.Create as IBucket);
end;

function TRoutingTable.CountNodes: Integer;
var
  b: IBucket;
begin
  Result := 0;

  for b in FBuckets do
    Inc(Result, b.Nodes.Count);
end;

constructor TRoutingTable.Create(ALocalNode: INode);
begin
  Assert(Assigned(ALocalNode), 'ALocalNode not assigned');

  FBuckets := TGenList<IBucket>.Create;

  FLocalNode := ALocalNode;
  FLocalNode.Seen;

  Add(TBucket.Create as IBucket);
end;

destructor TRoutingTable.Destroy;
begin
  FBuckets.Free;
  FLocalNode := nil;
  inherited;
end;

function TRoutingTable.FindNode(ANodeID: TNodeID): INode;
var
  b: IBucket;
  reslt: INode;
begin
  for b in FBuckets do
    for reslt in b.Nodes do
      if reslt.ID.Equals(ANodeID) then
        Exit(reslt);

  Result := nil;
end;

function TRoutingTable.GetClosest(ATarget: TNodeID): IList<INode>;
var
  b: IBucket;
  n: INode;
  distance: TNodeID;
  sortedNodes: TSortedList<TNodeID, INode>;
begin
  sortedNodes := TSortedList<TNodeID, INode>.Create(NodeIDSorter);
  try
    for b in FBuckets do
      for n in b.Nodes do
      begin
        distance := n.ID xor ATarget;
        if sortedNodes.Count = TBucket.MaxCapacity then
        begin
          if distance > sortedNodes.Keys[sortedNodes.Count - 1] then
            Continue;

          sortedNodes.Delete(sortedNodes.Count - 1);
        end;

        sortedNodes.Add(distance, n);
      end;

    Result := TSprList<INode>.Create;
    for n in sortedNodes.Values do
      Result.Add(n);
  finally
    sortedNodes.Free;
  end;
end;

procedure TRoutingTable.RaiseNodeAdded(ANode: INode);
begin
  if Assigned(FOnAddNode) then
    FOnAddNode(ANode);
end;

procedure TRoutingTable.Remove(ABucket: IBucket);
begin
  FBuckets.Remove(ABucket);
end;

function TRoutingTable.Split(ABucket: IBucket): Boolean;
var
  median: TNodeID;
  left, right: IBucket;
  n: INode;
begin
  if ABucket.Max - ABucket.Min < TNodeID(TBucket.MaxCapacity) then
    Exit(False);

  median := (ABucket.Min + ABucket.Max) div 2;
  left := TBucket.Create(ABucket.Min, median);
  right := TBucket.Create(median, ABucket.Max);

  Remove(ABucket);
  Add(left);
  Add(right);

  for n in ABucket.Nodes do
    Add(n, False);

  if Assigned(ABucket.Replacement) then
    Add(ABucket.Replacement, False);

  Result := True;
end;

{ TNode }

class function TNode.CompactPort(ASinAddr: TVarSin): TUniString;
begin
  Result.Len := 0;

  case ASinAddr.AddressFamily of
    AF_INET:
      begin
        Result := Result + Integer(ASinAddr.sin_addr.S_addr) +
                           Word(ASinAddr.sin_port);
      end;

    AF_INET6:
      begin
        Result.Len := 16;
        Move(ASinAddr.sin6_addr.S6_addr[0], Result.DataPtr[0]^, 16);
        Result := Result + Word(ASinAddr.sin6_port);
      end;
  end;
end;

function TNode.CompactNode: TUniString;
begin
  Result := CompactNode(Self);
//  Result := Result.Len.ToString+':'+Result;
end;

class function TNode.CompactNode(ANode: INode): TUniString;
begin
  Result.Len := 0;
  Result := Result + ANode.ID.AsUniString + TNode.CompactPort(ANode.EndPoint);
end;

class function TNode.CloserNodes(ATarger: TNodeID;
  ACurrentNodes: TSortedList<TNodeId, TNodeId>; ANewNodes: IList<INode>;
  AMaxNodes: Integer): IList<INode>;
var
  node: INode;
  distance: TNodeID;
begin
  Result := TSprList<INode>.Create;

  for node in ANewNodes do
  begin
    if ACurrentNodes.ContainsValue(node.ID) then
      Continue;

    distance := node.ID xor ATarger;
    if ACurrentNodes.Count < AMaxNodes then
      ACurrentNodes.Add(distance, node.ID)
    else
    if distance < ACurrentNodes.Keys[ACurrentNodes.Count - 1] then
    begin
      ACurrentNodes.Delete(ACurrentNodes.Count - 1);
      ACurrentNodes.Add(distance, node.ID);
    end else
      continue;

    Result.Add(node);
  end;
end;

class function TNode.CompactNode(ANodes: IList<INode>): TUniString;
var
  n: INode;
begin
  Result.Len := 0;

  for n in ANodes do
    Result := Result + CompactNode(n);
end;

class function TNode.BencodeNode(ANode: INode): IBencodedDictionary;
begin
  Result := BencodedDictionary;
  Result.Add(BencodeString(IDKey), BencodeString(ANode.ID.AsUniString));
  Result.Add(BencodeString(NodeKey), BencodeString(ANode.EndPoint.Serialize));
end;

function TNode.BencodeNode: IBencodedDictionary;
begin
  Result := BencodeNode(Self);
end;

class function TNode.CompactPort(APeers: IList<TVarSin>): TUniString;
var
  s: TVarSin;
begin
  Result.Len := 0;

  for s in APeers do
    Result := Result + CompactPort(s);

//  Result := Result.Len.ToString+':'+Result;
end;

function TNode.CompareTo(AOther: INode): Integer;
begin
  if AOther = nil then
    Result := 1
  else
    Result := Ord(CompareDateTime(FLastSeen, AOther.LastSeen));
end;

function TNode.CompactPort: TUniString;
begin
  Result := CompactPort(FEndPoint);
//  Result := Result.Len.ToString+':'+Result;
end;

constructor TNode.Create(ANodeID: TNodeID; AEndPoint: TVarSin);
begin
  inherited Create;

  FEndPoint := AEndPoint;
  FID := ANodeID; { copy? }
end;

function TNode.Equals(AOther: INode): Boolean;
begin
  if AOther = nil then
    Result := False
  else
    Result := FID = AOther.ID;
end;

class function TNode.FromCompactNode(ABuf: TUniString): IList<INode>;
var
  tmp: TUniString;
  id: TNodeID;
  addr: TVarSin;
  port: Word;
begin
  Result := TSprList<INode>.Create;

  tmp.Assign(ABuf);
  while tmp.Len > 0 do
  begin
    id := tmp.Copy(0, TNodeID.NODE_ID_LEN);
    tmp.Delete(0, TNodeID.NODE_ID_LEN);

    addr.AddressFamily := AF_INET;
    Move(tmp.DataPtr[0]^, addr.sin_addr.S_addr, 4);
    tmp.Delete(0, 4);

    Move(tmp.DataPtr[0]^, port, 2);
    addr.sin_port := {htons}(port); { там порт лежит в сетевом формате, переводить в локальный не надо, ибо sin_port должен быть в сетевом формате }
    tmp.Delete(0, 2);

    Result.Add(TNode.Create(id, addr) as INode);
  end;
end;

function TNode.GetEndPoint: TVarSin;
begin
  Result := FEndPoint;
end;

function TNode.GetFailedCount: Integer;
begin
  Result := FFailedCount;
end;

function TNode.GetHashCode: Integer;
begin
  Result := FID.AsUniString.GetHashCode;
end;

function TNode.GetID: TNodeID;
begin
  Result := FID;
end;

function TNode.GetLastSeen: TDateTime;
begin
  Result := FLastSeen;
end;

function TNode.GetState: TNodeState;
begin
  if FFailedCount >= MaxFailures then
    Exit(nsBad)
  else
  if FlastSeen = MinDateTime then
    Exit(nsUnknown);

  if MinutesBetween(UtcNow, GetLastSeen) < 15 then
    Result := nsGood
  else
    Result := nsQuestionable;
end;

function TNode.GetToken: TUniString;
begin
  Result := FToken;
end;

procedure TNode.Seen;
begin
  FFailedCount := 0;
  FLastSeen := UtcNow;
end;

procedure TNode.SetFailedCount(const Value: Integer);
begin
  FFailedCount := Value;
end;

procedure TNode.SetLastSeen(const Value: TDateTime);
begin
  FLastSeen := Value;
end;

procedure TNode.SetToken(const Value: TUniString);
begin
  FToken := Value;
end;

class function TNode.FromBencodedNode(ANodes: IBencodedList): IList<INode>;
var
  vals: IBencodedValue;
  node: INode;
  id: TUniString;
  endpoint: TVarSin;
begin
  Result := TSprList<INode>.Create;

  for vals in ANodes.Childs do
  begin
    //bad format!
    if not Supports(vals, IBencodedList) then
      Continue;

    with (vals as IBencodedDictionary) do
    begin
      endpoint.Clear;

      id := (Items[IDKey] as IBencodedString).Value;
      endpoint.Deserealize((Items[NodeKey] as IBencodedString).Value);
      node := TNode.Create(id, endpoint);

      Result.Add(node);
    end;
  end;
end;

class function TNode.BencodeNode(ANodes: IList<INode>): IBencodedList;
var
  n: INode;
begin
  Result := BencodedList;

  for n in ANodes do
    Result.Add(BencodeNode(n));
end;

{ TNodeID }

class operator TNodeID.Add(A, B: TNodeID): TNodeID;
begin
  Result.FValue := A.FValue + B.FValue;
end;

function TNodeID.AsUniString: TUniString;
begin
  Result := FValue.Bytes;
  { дополняем нулями, пока длина меньше NODE_ID_LEN }
  while Result.Len < NODE_ID_LEN do
    Result := 0 + Result;
end;

class operator TNodeID.BitwiseXor(A, B: TNodeID): TNodeID;
begin
  Result.FValue := A.FValue xor B.FValue;
end;

function TNodeID.CompareTo(AOther: TNodeID): Integer;
begin
  Result := Ord(FValue.Compare(FValue, AOther.FValue));
end;

class operator TNodeID.Implicit(A: TUniString): TNodeID;
var
  b: TBytes;
begin
  b := A;
  Result := b;
end;

class operator TNodeID.IntDivide(A: TNodeID; B: Integer): TNodeID;
begin
  Result.FValue := A.FValue div B;
end;

class operator TNodeID.Equal(A: TNodeID; B: TNodeID): Boolean;
begin
  Result := A.FValue = B.FValue;
end;

function TNodeID.Equals(AOther: TNodeID): Boolean;
begin
  Result := CompareTo(AOther) = 0;
end;

procedure TNodeID.FillRandom;
begin

end;

function TNodeID.GetHashCode: Integer;
begin
  Result := FValue.GetHashCode;
end;

class operator TNodeID.GreaterThan(A, B: TNodeID): Boolean;
begin
  Result := A.FValue > B.FValue;
end;

class operator TNodeID.GreaterThanOrEqual(A, B: TNodeID): Boolean;
begin
  Result := A.FValue >= B.FValue;
end;

class operator TNodeID.Implicit(A: Cardinal): TNodeID;
begin
  Result.FValue := TBigInteger(A);
end;

class operator TNodeID.Implicit(A: TBytes): TNodeID;
begin
  Result.FValue := A;
end;

class operator TNodeID.LessThan(A, B: TNodeID): Boolean;
begin
  Result := A.FValue < B.FValue;
end;

class operator TNodeID.LessThanOrEqual(A, B: TNodeID): Boolean;
begin
  Result := A.FValue <= B.FValue;
end;

class function TNodeID.New: TNodeID;
var
  cid: TUniString;
  buf: TBytes;
begin
  cid.Len := 500+random(500);
  cid.FillRandom;
  cid := SHA1(cid);

  SetLength(buf, cid.Len);
  Move(cid.DataPtr[0]^, buf[0], cid.Len);
//  SetLength(buf, 20);
//  HexToBin('16D4F4BC149AE82CB8067A63A016BBA27367D527', buf[0], 20);

  Result := buf;
end;

class operator TNodeID.NotEqual(A: TNodeID; B: TNodeID): Boolean;
begin
  Result := A.FValue <> B.FValue;
end;

class operator TNodeID.Subtract(A, B: TNodeID): TNodeID;
begin
  Result.FValue := A.FValue - B.FValue;
end;

{ TDHTEngine }

procedure TDHTEngine.Announce(AInfoHash: TUniString; APort: Word);
begin
  DebugPrint('TDHTEngine.Announce' + AInfoHash.ToHexString);
  Assert(AInfoHash.Len = TNodeID.NODE_ID_LEN, 'Invalid AInfoHash length');

  CheckDisposed;

  RegisterRequest;

  with TAnnounceTask.Create(Self, AInfoHash, APort) as IAnnounceTask do
  begin
    OnCompleted.Add(procedure (e: ITaskCompleteEventArgs; ACaller: IInterface)
    begin
      UnregisterRequest;
    end);

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

  with TSendQueryTask.Create(Self,
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
  FOnStop := TGenList<TProc>.Create;
end;

class destructor TDHTEngine.ClassDestroy;
begin
  FOnStop.Free;
end;

constructor TDHTEngine.Create(AListener: TDHTListener; ALocalID: TUniString);
var
  s: TVarSin;
begin
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

  Assert(assigned(AListener), 'AListener not defined');

  FMessageLoop := TMessageLoop.Create(Self, AListener);
  FTimeout := TTimeSpan.FromSeconds(15); // 15 second message timeout by default
  FTokenManager := TTokenManager.Create;
end;

destructor TDHTEngine.Destroy;
begin
  FRoutingTable.Free;
  FTorrents.Free;
  FMessageLoop.Free;
  FTokenManager.Free;
  inherited;
end;

procedure TDHTEngine.Dispose;
begin
  if FDisposed then
    Exit;

  JExecWait(CONV_DHT, Job(procedure
  begin
    FDisposed := True;

    Lock(FOnStop, procedure
    var
      i: Integer;
    begin
      for i := FOnStop.Count - 1 downto 0 do
        FOnStop[i]();

      FOnStop.Clear;
    end);
  end)).Wait;
end;

function TDHTEngine.GetLocalId: TNodeID;
begin
  Result := FRoutingTable.LocalNode.ID;
end;

procedure TDHTEngine.GetPeers(AInfoHash: TUniString);
begin
  DebugPrint('TDHTEngine.GetPeers' + AInfoHash.ToHexString);
  Assert(AInfoHash.Len = TNodeID.NODE_ID_LEN, 'Invalid AInfoHash length');

  CheckDisposed;

  RegisterRequest;

  with TGetPeersTask.Create(Self, AInfoHash) as IGetPeersTask do
  begin
    OnCompleted.Add(procedure (e: ITaskCompleteEventArgs; ACaller: IInterface)
    begin
      UnregisterRequest;
    end);

    Execute;
  end;
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

procedure TDHTEngine.RegisterRequest;
begin
  AtomicIncrement(FActiveTasks);
  RequestChangeState;
end;

function TDHTEngine.SaveNodes: IBencodedList;
var
  result_: IBencodedList;
begin
  result_ := BencodedList;

  JExecWait(CONV_DHT, Job(procedure
  var
    b: IBucket;
    n: INode;
  begin
    for b in RoutingTable.Buckets do
    begin
      for n in b.Nodes do
        result_.Add(n.BencodeNode {BencodeString(n.CompactNode)});

      if Assigned(b.Replacement) and (b.Replacement.State <> nsBad) then
        result_.Add(b.Replacement.BencodeNode {BencodeString(b.Replacement.CompactNode)});
    end;
  end)).Wait;

  Result := result_;
end;

//procedure TDHTEngine.SetTorrents(
//  const Value: TGenObjectDictionary<TNodeID, TGenList<INode>>);
//begin
//  raise Exception.Create('deprecated function');
//  FTorrents := Value;
//end;

procedure TDHTEngine.Start;
begin
  Start(BencodedList);
end;

procedure TDHTEngine.Start(AInitialNodes: IBencodedList);
var
  loop: TProc;
begin
  CheckDisposed;

  FMessageLoop.Start;
  if FBootStrap then
  begin
    RegisterRequest;

    with TInitialiseTask.Create(Self, AInitialNodes) as IInitialiseTask do
      Execute;

    //RaiseStateChanged(sInitialising);
    FBootStrap := False;
  end else
    RaiseStateChanged(sReady);

  loop := procedure
  var
    b: IBucket;
  begin
    if FDisposed then
      Exit;

    for b in RoutingTable.Buckets do
      if TTimeSpan.Subtract(UtcNow, b.LastChanged) > FBucketRefreshTimeout then
      begin
        b.LastChanged := UtcNow;

        with TRefreshBucketTask.Create(self, b) as IRefreshBucketTask do
          Execute;
      end;

    if not FDisposed then
      JSchedule(CONV_DHT, 1000, Job(loop));
  end;

  JSchedule(CONV_DHT, 1000, Job(loop));
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

procedure TDHTEngine.UnregisterRequest;
begin
  AtomicDecrement(FActiveTasks);
  RequestChangeState;
end;

{ TMessageLoop }

function TMessageLoop.CanSend: Boolean;
begin
  Result := ({FActiveSends.Count < 5) and} FSendQueue.Count > 0) and
            (MilliSecondsBetween(Now, FLastSent) > 5);
end;

constructor TMessageLoop.Create(AEngine: TDHTEngine; AListener: TDHTListener);
var
  loop: TProc;
begin
  FOnQuerySent := TGenList<TFunc<ISendQueryEventArgs, Boolean>>.Create;

  FEngine := AEngine;
  FListener := AListener;

  FReceiveQueue := TQueue<TPair<TVarSin, IMessage>>.Create;
  FWaitingResponse := TGenList<ISendDetails>.Create;

  Lock(FListener.OnReceive, procedure
  begin
    FListener.OnReceive.Add(procedure (ABuffer: TUniString; ASource: TVarSin)
    var
      msg: IMessage;
      it: TPair<TVarSin, IMessage>;
      dict: IBencodedDictionary;
    begin
      try
        dict := (BencodeParse(ABuffer).Childs[0] as IBencodedDictionary);
        if TMessageFactory.TryDecodeMessage(dict, msg) then
        begin
          it.Key := ASource;
          it.Value := msg;

          Lock(FReceiveQueue, procedure
          begin
            FReceiveQueue.Enqueue(it);
          end);
        end;
      except
        //on E: MessageException do
        //  Console.WriteLine("Message Exception: {0}", ex);
        //on E: Exception do
        //  Console.WriteLine("OMGZERS! {0}", ex);
      end;
    end);
  end);

  FSendQueue := TQueue<ISendDetails>.Create;

  loop := procedure
  begin
    if FEngine.Disposed or gTerminate then
      Exit;

    try
      SendMessage;
      ReceiveMessage;
      TimeoutMessage;
    except
//      on E: Exception do
//      Debug.WriteLine("Error in DHT main loop:");
//      Debug.WriteLine(ex);
    end;

    if (not FEngine.Disposed) and (not gTerminate) then
      JSchedule(CONV_DHT, 5, Job(loop))
    else
      loop := nil;
  end;

  JSchedule(CONV_DHT, 5, Job(loop));
end;

destructor TMessageLoop.Destroy;
begin
  FOnQuerySent.Free;
  FSendQueue.Free;
  FReceiveQueue.Free;
  FWaitingResponse.Free;
  inherited;
end;

procedure TMessageLoop.EnqueueSend(AMessage: IMessage; AEndPoint: TVarSin);
begin
  if AMessage.TransactionId = nil then
  begin
    {(AMessage as TMessage) is TResponseMessage}
    if Supports(AMessage, IResponseMessage) then
      raise EMessageLoop.Create('Message must have a transaction id');

    repeat
      AMessage.TransactionId := TTransactionId.NextId;
    until not(TMessageFactory.IsRegistered(AMessage.TransactionId));
  end;

  // We need to be able to cancel a query message if we time out waiting for a response
  {(AMessage as TMessage) is TQueryMessage}
  if Supports(AMessage, IQueryMessage) then
    TMessageFactory.RegisterSend(AMessage as IQueryMessage);

  Lock(FSendQueue, procedure
  begin
    FSendQueue.Enqueue(TSendDetails.Create(AEndPoint, AMessage));
  end);
end;

procedure TMessageLoop.EnqueueSend(AMessage: IMessage; ANode: INode);
begin
  EnqueueSend(AMessage, ANode.EndPoint);
end;

procedure TMessageLoop.RaiseMessageSent(AEndPoint: TVarSin;
  AQuery: IQueryMessage; AResponse: IResponseMessage);
begin
  Lock(FOnQuerySent, procedure
  var
    i: Integer;
    args: ISendQueryEventArgs;
  begin
    i := 0;

    while i < FOnQuerySent.Count do
    begin
      {$MESSAGE WARN 'костыль'}
      try
        if FOnQuerySent[i](TSendQueryEventArgs.Create(AEndpoint, AQuery, AResponse)) then
          FOnQuerySent.Delete(i)
        else
          Inc(i);
      except
        FOnQuerySent.Delete(i);
      end;
    end;
  end);
end;

procedure TMessageLoop.ReceiveMessage;
var
  receive: TPair<TVarSin, IMessage>;
  m: IMessage;
  source: TVarSin;
  i: Integer;
  node: INode;
  response: IResponseMessage;
begin
  if FReceiveQueue.Count = 0 then
    Exit;

  receive := FReceiveQueue.Dequeue;
  m := receive.Value;
  source := receive.Key;

  for i := FWaitingResponse.Count - 1 downto 0 do
    try
    if FWaitingResponse[i].Msg.TransactionId.Equals(m.TransactionId) then
      FWaitingResponse.Delete(i);
    except
      Sleep(0);
    end;

  try
    node := FEngine.RoutingTable.FindNode(m.ID);

    // What do i do with a null node?
    if node = nil then
    begin
      node := TNode.Create(m.ID, source);
      FEngine.RoutingTable.Add(node);
    end;

    node.Seen;
    m.Handle(FEngine, node);

    if Supports(m, IResponseMessage) then
    begin
      response := m as IResponseMessage;
      RaiseMessageSent(node.EndPoint, response.Query, response);
    end;
  except
//  catch (EMessageException ex)
//      Console.WriteLine("Incoming message barfed: {0}", ex);
//  catch (EException ex)
//      Console.WriteLine("Handle Error for message: {0}", ex);
//      this.EnqueueSend(new ErrorMessage(ErrorCode.GenericError, "Misshandle received message!"), source);
    on E: Exception do
      EnqueueSend(TErrorMessage.Create(TErrorCode.GenericError, 'Misshandle received message!'), source);
  end;
end;

procedure TMessageLoop.SendMessage(AMsg: IMessage; ADest: TVarSin);
var
  buf: TUniString;
begin
  buf := AMsg.Encode;

  FLastSent := Now;
  FListener.Send(ADest, buf, 0);
end;

procedure TMessageLoop.Start;
begin
  {if FListener.Status <> sListening then
    FListener.Start;}
  FListener.Start;
end;

procedure TMessageLoop.Stop;
begin
  {if FListener.Status <> sNotListening then
    FListener.Stop;}
  Lock(FListener.OnReceive, procedure
  begin
    FListener.OnReceive.Clear;
  end);
  FListener.Terminate;
end;

procedure TMessageLoop.TimeoutMessage;
var
  details: ISendDetails;
begin
  if FWaitingResponse.Count > 0 then
  begin
    if TTimeSpan.Subtract(UtcNow, FWaitingResponse[0].SentAt) > FEngine.TimeOut then
    begin
      details := FWaitingResponse[0]; FWaitingResponse.Delete(0);

      TMessageFactory.UnregisterSend(details.Msg as IQueryMessage);
      RaiseMessageSent(details.Destination, details.Msg as IQueryMessage, nil);
    end;
  end;
end;

procedure TMessageLoop.SendMessage;
var
  send: ISendDetails;
begin
  send := nil;

  if CanSend then
    send := FSendQueue.Dequeue;

  if Assigned(send) then
  begin
    SendMessage(send.Msg, send.Destination);
    send.SentAt := UtcNow;

    if send.Msg is TQueryMessage then
      FWaitingResponse.Add(send)
  end;
end;

{ TaskCompleteEventArgs }

constructor TTaskCompleteEventArgs.Create(ATask: ITask);
begin
  inherited Create;
  FTask := ATask;
end;

function TTaskCompleteEventArgs.GetTask: ITask;
begin
  Result := FTask;
end;

procedure TTaskCompleteEventArgs.SetTask(Value: ITask);
begin
  FTask := Value;
end;

{ TTask }

procedure TTask.AfterConstruction;
begin
  inherited;
  FActive := False;
  FOnCompleted := TGenList<TProc<ITaskCompleteEventArgs, IInterface>>.Create;

  FOnStop := procedure
  begin
    Stop;
  end;

  Lock(TDHTEngine.FOnStop, procedure
  begin
    TDHTEngine.FOnStop.Add(FOnStop);
  end);
end;

destructor TTask.Destroy;
begin
  if Assigned(FOnCompleted) then
    FOnCompleted.Free;

  Lock(TDHTEngine.FOnStop, procedure
  begin
    TDHTEngine.FOnStop.Remove(FOnStop);
  end);

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

  Self._Release;
end;

procedure TTask.Stop;
begin
  while Self._Release > 0 do;
end;

{ TSendQueryEventArgs }

constructor TSendQueryEventArgs.Create(AEndPoint: TVarSin; AQuery: IQueryMessage;
  AResponse: IResponseMessage);
begin
  inherited Create(nil);

  FEndPoint := AEndPoint;
  FQuery    := AQuery;
  FResponse := AResponse;
end;

function TSendQueryEventArgs.GetEndPoint: TVarSin;
begin
  Result := FEndPoint;
end;

function TSendQueryEventArgs.GetQuery: IQueryMessage;
begin
  Result := FQuery;
end;

function TSendQueryEventArgs.GetResponse: IResponseMessage;
begin
  Result := FResponse;
end;

function TSendQueryEventArgs.GetTimedOut: Boolean;
begin
  Result := FResponse = nil;
end;

{ TGetPeersTask }

constructor TGetPeersTask.Create(AEngine: TDHTEngine; AInfoHash: TNodeID);
begin
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

  JExec(CONV_DHT, Job(procedure
  var
    newNodes: IList<INode>;
    n: INode;
  begin
    newNodes := FEngine.RoutingTable.GetClosest(FInfoHash);
    for n in TNode.CloserNodes(FInfoHash, FClosestNodes, newNodes, TBucket.MaxCapacity) do
      SendGetPeers(n);
  end));
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

  with TSendQueryTask.Create(FEngine,
       TGetPeers.Create(FEngine.LocalId, FInfoHash),
       ANode, 3) as ISendQueryTask do
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
      try
        Dec(FActiveQueries);
        e.Task.OnCompleted.Remove(TProc<ITaskCompleteEventArgs, IInterface>(ACaller));

        //lOnCompl := nil;

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

{ TMessage }

constructor TMessage.Create(AMessageType: IBencodedString);
begin
  FProperties := BencodedDictionary;

  FProperties.Add(BencodeString(TransactionIdKey), nil);
  FProperties.Add(BencodeString(MessageTypeKey), AMessageType);
  FProperties.Add(BencodeString(VersionKey), BencodeString(DHTVersion));
end;

constructor TMessage.Create(ADictionary: IBencodedDictionary);
begin
  FProperties := ADictionary;
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

function TMessage.GetAsObject: TObject;
begin
  Result := Self;
end;

function TMessage.GetClientVersion: TUniString;
var
  ver: IBencodedValue;
begin
  if FProperties.TryGetValue(VersionKey, ver) then
    Result := (ver as IBencodedString).Value;
end;

function TMessage.GetMessageType: TUniString;
begin
  Result := (FProperties[MessageTypeKey] as IBencodedString).Value;
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
  Create(ANodeID, AQueryName, BencodedDictionary, AResponseCreator);
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
  inherited Create(AID, QueryName, FResponseCreator);

  GetParameters.Add(BencodeString(InfoHashKey), BencodeString(AInfoHash.AsUniString));
end;

class destructor TGetPeers.ClassDestroy;
begin
  FResponseCreator := nil;
end;

constructor TGetPeers.Create(ADict: IBencodedDictionary);
begin
  inherited Create(ADict, FResponseCreator);
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

{ TSendQueryTask }

constructor TSendQueryTask.Create(AEngine: TDHTEngine; AQuery: IQueryMessage;
  ANode: INode; ARetries: Integer);
begin
  Assert(Assigned(AEngine), 'AEngine not defined' );
  Assert(Assigned(AQuery) , 'AQuery not defined'  );
  Assert(Assigned(ANode)  , 'ANode not defined'   );

  FEngine       := AEngine;
  FQuery        := AQuery;
  FNode         := ANode;
  FRetries      := ARetries;
  FOrigRetries  := ARetries;
end;

constructor TSendQueryTask.Create(AEngine: TDHTEngine; AQuery: IQueryMessage;
  ANode: INode);
begin
  Create(AEngine, AQuery, ANode, 3);
end;

procedure TSendQueryTask.Execute;
begin
  if FActive then
    Exit;

  Self._AddRef;

  FOnQuerySent := function (e: ISendQueryEventArgs): Boolean
  begin
    Assert(Self.FRefCount > 0, 'Вызван метод мертвого объекта');
    Result := False;

    if e.Query.AsObject <> FQuery.AsObject then
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
      FEngine.MessageLoop.EnqueueSend(FQuery, FNode)
    else
    begin
      RaiseComplete(e);
      Result := True;
    end;
  end;

  Lock(FEngine.MessageLoop.OnQuerySent, procedure
  begin
    FEngine.MessageLoop.OnQuerySent.Add(FOnQuerySent);
  end);

  FEngine.MessageLoop.EnqueueSend(FQuery, FNode);
end;

function TSendQueryTask.GetNode: INode;
begin
  Result := FNode;
end;

procedure TSendQueryTask.RaiseComplete(AEventArgs: ITaskCompleteEventArgs);
begin
  AEventArgs.Task := Self as ITask;
  inherited RaiseComplete(AEventArgs);
  AEventArgs.Task := nil; { спасёт ли это от AV? }
  Self._Release;
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

{ TPeer }

function TPeer.CompactPeer: TUniString;
begin
  Result := FConnectionUri.Serialize;
end;

constructor TPeer.Create(APeerID: string; AConnectionUri: TVarSin);
begin
  Assert(not AConnectionUri.IsIPEmpty, 'AConnectionUri not defined');

  FConnectionUri := AConnectionUri;
//  encryption = encryption;
  FpeerId := APeerID;
end;

class function TPeer.Decode(APeers: IBencodedList): IList<IPeer>;
var
  value: IBencodedValue;
  p: IPeer;
begin
  Result := TSprList<IPeer>.Create;

  for value in APeers.Childs do
  try
    if Supports(value, IBencodedDictionary) then
      Result.Add(DecodeFromDict(value as IBencodedDictionary))
    else
    if Supports(value, IBencodedString) then
      for p in Decode((value as IBencodedString).Value) do
        Result.Add(p);
  except
    // If something is invalid and throws an exception, ignore it
    // and continue decoding the rest of the peers
  end;
end;

class function TPeer.Decode(APeers: TUniString): IList<IPeer>;
var
  uri: TVarSin;
  tmp: TUniString;
begin
  // "Compact Response" peers are encoded in network byte order.
  // IP's are the first four bytes
  // Ports are the following 2 bytes

  Assert(APeers.Len mod 6 = 0, 'Invalid peers length');

  Result := TSprList<IPeer>.Create;
  tmp := APeers.Copy;

  while tmp.Len > 0 do
  begin
    uri.Clear;
    uri.AddressFamily := AF_INET;

    Move(tmp.DataPtr[0]^, uri.sin_addr.S_addr, 4);
    tmp.Delete(0, 4);
    Move(tmp.DataPtr[0]^, uri.sin_port, 2);
    tmp.Delete(0, 2);

    Result.Add(TPeer.Create('', uri{, EncryptionTypes.All}));
  end;
end;

class function TPeer.DecodeFromDict(ADict: IBencodedDictionary): IPeer;
var
  peerId: string;
  connectionUri: TVarSin;
begin
  { в каком формате приходят к нам значения? }
  if ADict.ContainsKey('peer id') then
    peerId := (ADict['peer id'] as IBencodedString).Value.AsString
  else
  // HACK: Some trackers return "peer_id" instead of "peer id"
  if ADict.ContainsKey('peer_id') then
    peerId := (ADict['peer_id'] as IBencodedString).Value.AsString
  else
    peerId := '';

  connectionUri.Clear;
  Result := TPeer.Create(peerId, connectionUri{, EncryptionTypes.All});
end;

class function TPeer.Encode(APeers: IList<IPeer>): IBencodedList;
var
  p: IPeer;
begin
  Result := BencodedList;
  for p in APeers do
    Result.Add(BencodeString(p.CompactPeer));
end;

function TPeer.Equals(AOther: IPeer): Boolean;
begin
  if not Assigned(AOther) then
    Exit(False);

  if (FPeerId = '') and (AOther.PeerId = '') then
    Result := FConnectionUri.sin_addr.S_addr = AOther.ConnectionUri.sin_addr.S_addr
  else
    Result := FPeerId = AOther.PeerId;
end;

function TPeer.GetCleanedUpCount: Integer;
begin
  Result := FCleanedUpCount;
end;

function TPeer.GetConnectionUri: TVarSin;
begin
  Result := FConnectionUri;
end;

function TPeer.GetFailedConnectionAttempts: Integer;
begin
  Result := FFailedConnectionAttempts;
end;

function TPeer.GetHashCode: Integer;
begin
  Result := BobJenkinsHash(FConnectionUri.sin_addr.S_addr, 4, 0);
end;

function TPeer.GetIsSeeder: Boolean;
begin
  Result := FIsSeeder;
end;

function TPeer.GetLastConnectionAttempt: TDateTime;
begin
  Result := FLastConnectionAttempt;
end;

function TPeer.GetLocalPort: Word;
begin
  Result := FLocalPort;
end;

function TPeer.GetPeerId: string;
begin
  Result := FPeerId;
end;

function TPeer.GetRepeatedHashFails: Integer;
begin
  Result := FRepeatedHashFails;
end;

function TPeer.GetTotalHashFails: Integer;
begin
  Result := FTotalHashFails;
end;

procedure TPeer.HashedPiece(ASucceeded: Boolean);
begin
  if ASucceeded and (FRepeatedHashFails > 0) then
    Dec(FRepeatedHashFails);

  if not ASucceeded then
  begin
    Inc(FRepeatedHashFails);
    Inc(FTotalHashFails);
  end;
end;

procedure TPeer.SetCleanedUpCount(const Value: Integer);
begin
  FCleanedUpCount := Value;
end;

procedure TPeer.SetFailedConnectionAttempts(const Value: Integer);
begin
  FFailedConnectionAttempts := Value;
end;

procedure TPeer.SetIsSeeder(const Value: Boolean);
begin
  FIsSeeder := Value;
end;

procedure TPeer.SetLastConnectionAttempt(const Value: TDateTime);
begin
  FLastConnectionAttempt := Value;
end;

procedure TPeer.SetLocalPort(const Value: Word);
begin
  FLocalPort := Value;
end;

procedure TPeer.SetPeerId(const Value: string);
begin
  FPeerId := Value;
end;

procedure TPeer.SetTotalHashFails(const Value: Integer);
begin
  FTotalHashFails := Value;
end;

function TPeer.ToString: string;
begin
  Result := FConnectionUri.ToString;
end;

{ TTokenManager }

constructor TTokenManager.Create;
begin
  FLastSecretGeneration := MinDateTime;

  FSecret.Len := 10; FSecret.FillRandom;
  fpreviousSecret.Len := 10; fpreviousSecret.FillRandom;
end;

function TTokenManager.GenerateToken(ANode: INode): TUniString;
begin
  Result.Len := 0;
  Result := GetToken(anode, fsecret);
end;

function TTokenManager.GetToken(ANode: INode; s: TUniString): TUniString;
var
  n: TUniString;
begin
  if MinutesBetween(UtcNow, FTimeout) > 5 then
  begin
    FLastSecretGeneration := UtcNow;
    FPreviousSecret := FSecret.Copy;
    FSecret.FillRandom;
  end;

  n := ANode.CompactPort;
  Result := SHA1(n);
end;

function TTokenManager.VerifyToken(ANode: INode; AToken: TUniString): Boolean;
begin
  Result := (AToken = GetToken(anode, fsecret)) or
            (AToken = GetToken(anode, FPreviousSecret));
end;

{ TMessageFactory }

class constructor TMessageFactory.ClassCreate;
begin
  FMessages := TGenDictionary<IBencodedValue, IQueryMessage>.Create(
    TDelegatedEqualityComparer<IBencodedValue>.Create(
      function (const ALeft, ARight: IBencodedValue): Boolean
      begin
        Result := ALeft.GetHashCode = ARight.GetHashCode;
      end,
      function (const AValue: IBencodedValue): Integer
      begin
        Result := AValue.GetHashCode;
      end
    ) as IEqualityComparer<IBencodedValue>);
  FQueryDecoders := TGenDictionary<IBencodedString, TCreator>.Create(
    TDelegatedEqualityComparer<IBencodedString>.Create(
      function (const ALeft, ARight: IBencodedString): Boolean
      begin
        Result := ALeft.GetHashCode = ARight.GetHashCode;
      end,
      function (const AValue: IBencodedString): Integer
      begin
        Result := AValue.GetHashCode;
      end
    ) as IEqualityComparer<IBencodedString>);

  FQueryDecoders.Add(BencodeString('announce_peer') ,
    function (d: IBencodedDictionary): IMessage
    begin
      Result := TAnnouncePeer.Create(d);
    end);
  FQueryDecoders.Add(BencodeString('find_node')     ,
    function (d: IBencodedDictionary): IMessage
    begin
      Result := TFindNode.Create(d);
    end);
  FQueryDecoders.Add(BencodeString('get_peers')     ,
    function (d: IBencodedDictionary): IMessage
    begin
      Result := TGetPeers.Create(d);
    end);
  FQueryDecoders.Add(BencodeString('ping')          ,
    function (d: IBencodedDictionary): IMessage
    begin
      Result := TPing.Create(d);
    end);
end;

class destructor TMessageFactory.ClassDestroy;
begin
  FMessages.Free;
  FQueryDecoders.Free;
end;

class function TMessageFactory.DecodeMessage(
  ADict: IBencodedDictionary): IMessage;
var
  error: string;
begin
  Result := nil;

  if not TryDecodeMessage(ADict, Result, error) then
    raise EMessageFactory.Create(error);
end;

class function TMessageFactory.IsRegistered(
  ATransactionId: IBencodedValue): Boolean;
begin
  Result := FMessages.ContainsKey(ATransactionId);
end;

class function TMessageFactory.RegisteredMessages: Integer;
begin
  Result := FMessages.Count;
end;

class procedure TMessageFactory.RegisterSend(AMessage: IQueryMessage);
begin
  FMessages.Add(AMessage.TransactionId, AMessage);
end;

class function TMessageFactory.TryDecodeMessage(ADict: IBencodedDictionary;
  out AMsg: IMessage; out AError: string): Boolean;
var
  key: IBencodedString;
  query: IQueryMessage;
begin
  AMsg := nil;
  AError := '';

  if (ADict[MessageTypeKey] as IBencodedString).Value = TQueryMessage.QueryType then
    AMsg := FQueryDecoders[(ADict[QueryNameKey] as IBencodedString)](ADict)
  else
  if (ADict[MessageTypeKey] as IBencodedString).Value = TErrorMessage.ErrorType then
    AMsg := TErrorMessage.Create(ADict)
  else
  begin
    key := (ADict[TransactionIdKey] as IBencodedString);

    if FMessages.TryGetValue(key, query) then
    begin
      FMessages.Remove(key);
      try
        AMsg := query.ResponseCreator(ADict, query);
      except
        AError := 'Response dictionary was invalid';
      end;
    end else
      AError := 'Response had bad transaction ID';
  end;

  Result := (AError = '') and Assigned(AMsg);
end;

class function TMessageFactory.TryDecodeMessage(ADict: IBencodedDictionary;
  out AMsg: IMessage): Boolean;
var
  error: string;
begin
  Result := TryDecodeMessage(ADict, AMsg, error);
end;

class function TMessageFactory.UnregisterSend(AMessage: IQueryMessage): Boolean;
begin
  FMessages.Remove(AMessage.TransactionId);
  Result := True;
end;

{ TAnnouncePeer }

class constructor TAnnouncePeer.ClassCreate;
begin
  FResponseCreator := function (d: IBencodedDictionary; m: IQueryMessage): IMessage
  begin
    Result := TAnnouncePeerResponse.Create(d, m);
  end;
end;

constructor TAnnouncePeer.Create(AID, AInfoHash: TNodeID; APort: Word;
  AToken: TUniString);
begin
  inherited Create(AID, QueryName, FresponseCreator);
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
  inherited Create(ADict, FResponseCreator);
end;

function TAnnouncePeer.GetInfoHash: TNodeID;
begin
  // пример: d1:ad2:id20:abcdefghij01234567899:info_hash20:mnopqrstuvwxyz1234564:porti6881e5:token8:aoeusnthe1:q13:announce_peer1:t2:aa1:y1:qe
  // не забыть про «implied_port»
  Result := (GetParameters[InfoHashKey] as IBencodedString).Value;
end;

function TAnnouncePeer.GetPort: Word;
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
  inherited Create(AID, QueryName, FResponseCreator);
  GetParameters.Add(BencodeString(TargetKey), BencodeString(ATarget.AsUniString));
end;

class destructor TFindNode.ClassDestroy;
begin
  FResponseCreator := nil;
end;

constructor TFindNode.Create(ADict: IBencodedDictionary);
begin
  inherited Create(ADict, FResponseCreator);
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
  inherited Create(aid, QueryName, fresponseCreator);
end;

class destructor TPing.ClassDestroy;
begin
  FResponseCreator := nil;
end;

constructor TPing.Create(ADict: IBencodedDictionary);
begin
  inherited Create(adict, fresponseCreator);
end;

procedure TPing.Handle(AEngine: TDHTEngine; ANode: INode);
var
  m: TPingResponse;
begin
  inherited Handle(AEngine, ANode);

  m := TPingResponse.Create(aengine.RoutingTable.LocalNode.Id, GetTransactionID);
  aengine.MessageLoop.EnqueueSend(m, anode.EndPoint);
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

{ TMessageLoop.TSendDetails }

constructor TMessageLoop.TSendDetails.Create(ADest: TVarSin; AMsg: IMessage);
begin
  FDestination := ADest;
  FMsg := AMsg;
  FSentAt := MinDateTime;
end;

{ TAnnouncePeerResponse }

function TMessageLoop.TSendDetails.GetDestination: TVarSin;
begin
  Result := FDestination;
end;

function TMessageLoop.TSendDetails.GetMsg: IMessage;
begin
  Result := FMsg;
end;

function TMessageLoop.TSendDetails.GetSentAt: TDateTime;
begin
  Result := FSentAt;
end;

//procedure TMessageLoop.TSendDetails.SetDestination(const Value: TVarSin);
//begin
//  FDestination := Value;
//end;
//
//procedure TMessageLoop.TSendDetails.SetMsg(const Value: TMessage);
//begin
//  FMsg := Value;
//end;

procedure TMessageLoop.TSendDetails.SetSentAt(const Value: TDateTime);
begin
  FSentAt := Value;
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

{ TInitialiseTask }

constructor TInitialiseTask.Create(AEngine: TDHTEngine);
begin
  Initialise(AEngine, nil);
end;

constructor TInitialiseTask.Create(AEngine: TDHTEngine;
  AInitialNodes: TUniString);
begin
  Initialise(AEngine, TNode.FromCompactNode(AInitialNodes));
end;

constructor TInitialiseTask.Create(AEngine: TDHTEngine; ANodes: IList<INode>);
begin
  Initialise(AEngine, ANodes);
end;

destructor TInitialiseTask.Destroy;
begin
  FNodes.Free;
  inherited;
end;

constructor TInitialiseTask.Create(AEngine: TDHTEngine;
  AInitialNodes: IBencodedList);
begin
  Initialise(AEngine, TNode.FromBencodedNode(AInitialNodes));
end;

procedure TInitialiseTask.Execute;
var
  node, utorrent: INode;
  bootList: IList<INode>;
begin
  if FActive then
    Exit;

  FActive := true;

  Self._AddRef;

  // If we were given a list of nodes to load at the start, use them
  if FInitialNodes.Count > 0 then
  begin
    for node in FInitialNodes do
      FEngine.Add(node);

    SendFindNode(FInitialNodes);
  end else
  try
    utorrent := TNode.Create(TNodeID.New, StrToVarSin('67.215.246.10:6881'));
//    utorrent := TNode.Create(TNodeID.New, StrToVarSin('82.221.103.244:6881'));
    bootList := TSprList<INode>.Create;
    bootList.Add(utorrent);

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
    with TInitialiseTask.Create(FEngine) as IInitialiseTask do
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

    with TSendQueryTask.Create(FEngine,
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

constructor TRefreshBucketTask.Create(AEngine: TDHTEngine; ABucket: IBucket);
begin
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

  with TSendQueryTask.Create(FEngine, FMsg, fnode) as ISendQueryTask do
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

{ TMessageLoop.TTransactionID }

class constructor TMessageLoop.TTransactionID.ClassCreate;
begin
  FLock := TObject.Create;
end;

class destructor TMessageLoop.TTransactionID.ClassDestroy;
begin
  FLock.Free;
end;

class function TMessageLoop.TTransactionID.NextID: IBencodedString;
var
  reslt: IBencodedString;
begin
  Lock(FLock, procedure
  var
    foo: TUniString;
  begin
    foo.Len := Length(FCurrent);
    Move(FCurrent[0], foo.DataPtr[0]^, foo.Len);
    reslt := BencodeString(foo);

    if FCurrent[0] = 255 then
      Inc(FCurrent[1]);
    Inc(FCurrent[0]);
  end);

  Result := reslt;
end;

{ TAnnounceTask }

constructor TAnnounceTask.Create(AEngine: TDHTEngine; AInfoHash: TUniString;
  APort: Word);
begin
  Create(AEngine, TNodeID(AInfoHash), APort);
end;

constructor TAnnounceTask.Create(AEngine: TDHTEngine; AInfoHash: TNodeID;
  APort: Word);
begin
  FEngine := AEngine;
  FInfoHash := AInfoHash;
  FPort := APort;
end;

procedure TAnnounceTask.Execute;
begin
  Self._AddRef;

  with TGetPeersTask.Create(FEngine, FInfoHash) as IGetPeersTask do
  begin
    OnCompleted.Add(procedure (e1: ITaskCompleteEventArgs; ACaller1: IInterface)
    var
      getpeers: TGetPeersTask;
      n: INode;
    begin
      Assert(Self is TAnnounceTask, 'Self is not TAnnounceTask');

      e1.Task.OnCompleted.Remove(TProc<ITaskCompleteEventArgs, IInterface>(ACaller1));

      getpeers := e1.Task as TGetPeersTask;
      for n in getpeers.FQueriedNodes.Values do
      begin
        if n.Token = '' then
          Continue;

        with TSendQueryTask.Create(FEngine,
             TAnnouncePeer.Create(FEngine.LocalId, FInfoHash, FPort, n.Token),
             n) as ISendQueryTask do
        begin
          OnCompleted.Add(procedure (e2: ITaskCompleteEventArgs; ACaller2: IInterface)
          begin
            Assert(Self is TAnnounceTask, 'Self is not TAnnounceTask');

            e2.Task.OnCompleted.Remove(TProc<ITaskCompleteEventArgs, IInterface>(ACaller2));
            Dec(FActiveAnnounces);

            if FActiveAnnounces = 0 then
              RaiseComplete(TTaskCompleteEventArgs.Create(Self as ITask));
          end);

          Execute;
        end;

        Inc(FActiveAnnounces);
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

{ TDHT }

procedure TDHTThread.Announce(const AInfoHash: TUniString; APort: Word);
begin
  Lock(FRequestQueue, procedure
  var
    it: TRequestInfo;
  begin
    it := TRequestInfo.Create(rtAnnounce, AInfoHash, APort);
    FRequestQueue.Enqueue(it);
  end);
end;

constructor TDHTThread.Create(AAF, APort: Word; const ALocalID: TUniString);
begin
  inherited Create(True);
  FreeOnTerminate := True;

  FIsReady := False;

  FRequestQueue := TQueue<TRequestInfo>.Create;

  FDHTEngine := TDHTEngine.Create(TDHTListener.Create(AAF, APort), ALocalID);
  FDHTEngine.OnStateChanged := procedure (AState: TDHTEngine.TDHTState)
  begin
    case AState of
      sReady:
        if not FIsReady then
        begin
          FIsReady := True;

          if Assigned(FOnDHTReady) then
            FOnDHTReady;
        end;

      sStop:
        if FIsReady then
        begin
          FIsReady := False;

          if Assigned(FOnDHTStop) then
            FOnDHTStop;
        end;
    end;
  end;
end;

destructor TDHTThread.Destroy;
begin
  Stop;

  FRequestQueue.Free;

  FDHTEngine.Free;
  inherited;
end;

procedure TDHTThread.Execute;
var
  i: Integer;
begin
  while not (Terminated or gTerminate) do
  begin
    if FIsReady then
      Lock(FRequestQueue, procedure
      begin
        if FRequestQueue.Count > 0 then
          with FRequestQueue.Dequeue do
            case RequestType of
              rtAnnounce:
                FDHTEngine.Announce(InfoHash, Port);

              rtGetPeers:
                FDHTEngine.GetPeers(InfoHash);
            end;
      end);

    for i := 1 to QueueDelayInterval*100 do
      if Terminated or gTerminate then
        Break
      else
        Sleep(10);
  end;
end;

procedure TDHTThread.GetPeers(const AInfoHash: TUniString);
begin
  Lock(FRequestQueue, procedure
  var
    it: TRequestInfo;
  begin
    it := TRequestInfo.Create(rtGetPeers, AInfoHash);
    FRequestQueue.Enqueue(it);
  end);
end;

function TDHTThread.GetSaveNodes: TUniString;
var
  reslt: TUniString;
begin
  Lock(FDHTEngine, procedure
  begin
    reslt := FDHTEngine.SaveNodes.Encode;
  end);

  Result := reslt;
end;

procedure TDHTThread.Start;
begin
  Start(BencodedList);
end;

procedure TDHTThread.SetOnDHTPeersFound(const Value: TProc<TUniString, IList<IPeer>>);
begin
  FOnDHTPeersFound := Value;
  FDHTEngine.OnPeersFound := FOnDHTPeersFound;
end;

procedure TDHTThread.Start(AInitialNodes: IBencodedList);
begin
  FDHTEngine.Start(AInitialNodes);
  inherited Start;
end;

procedure TDHTThread.Stop;
begin
  FDHTEngine.Stop;
  Terminate;
end;

{ TDHT.TRequestInfo }

constructor TDHTThread.TRequestInfo.Create(ARequestType: TRequestType;
  const AInfoHash: TUniString);
begin
  RequestType := ARequestType;
  InfoHash.Assign(AInfoHash);
end;

constructor TDHTThread.TRequestInfo.Create(ARequestType: TRequestType;
  const AInfoHash: TUniString; APort: Word);
begin
  RequestType := ARequestType;
  InfoHash.Assign(AInfoHash);
  Port := APort;
end;

function TDHTThread.TRequestInfo.IsEqual(const AOther: TRequestInfo): Boolean;
begin
  Result := (InfoHash = AOther.InfoHash) and (RequestType = AOther.RequestType);
end;

end.
