unit DHT;

interface

uses
  System.Classes, System.SysUtils, System.Generics.Collections,
  System.Generics.Defaults,
  Common.BusyObj,
  Basic.UniString, Basic.Bencoding,
  DHT.NodeID,
  IdGlobal;

type
  TErrorCode = (ecGenericError, ecServerError, ecProtocolError, ecMethodUnknown);

  TErrorCodeHelper = record helper for TErrorCode
  private
    const
      ErrorCodesInt: array[TErrorCode] of Integer = (201, 202, 203, 204);
  private
    function GetAsInteger: Integer; inline;
    procedure SetAsInteger(const Value: Integer);
  public
    property AsInteger: Integer read GetAsInteger write SetAsInteger;
  end;

  TNodeState = (nsUnknown, nsGood, nsQuestionable, nsBad);

  INode = interface
  ['{F0BB514B-E674-4AFA-BCA5-077E84DC646D}']
    function GetState: TNodeState;
    function GetToken: TUniString;
    procedure SetToken(const Value: TUniString);
    function GetLastSeen: TDateTime;
    procedure SetLastSeen(const Value: TDateTime);
    function GetID: TNodeID;
    function GetFailedCount: Integer;
    procedure SetFailedCount(const Value: Integer);
    function GetHost: string;
    function GetPort: TIdPort;

    procedure Seen;

    function GetHashCode: Integer;
    function CompareTo(AOther: INode): Integer;
    function Equals(AOther: INode): Boolean;

    function GetCompactAddress: TUniString;
    function GetCompact: TUniString;

    property Host: string read GetHost;
    property Port: TIdPort read GetPort;

    property ID: TNodeID read GetID;

    property CompactAddress: TUniString read GetCompactAddress;
    property Compact: TUniString read GetCompact;

    property FailedCount: Integer read GetFailedCount write SetFailedCount;
    property LastSeen: TDateTime read GetLastSeen write SetLastSeen;
    property State: TNodeState read GetState;
    property Token: TUniString read GetToken write SetToken;
  end;

  IBucket = interface
  ['{083360ED-C773-478F-9B76-8F2A0D442B83}']
    function GetLastChanged: TDateTime;
    procedure SetLastChanged(const Value: TDateTime);
    function GetMax: TNodeID;
    function GetMin: TNodeID;
    function GetNodes: TEnumerable<INode>;
    function GetNodesCount: Integer;
    function GetReplacement: INode;
    procedure SetReplacement(const Value: INode);

    function Add(ANode: INode): Boolean;
    procedure SortBySeen;

    function CanContain(ANode: INode): Boolean; overload;
    function CanContain(ANodeID: TNodeID): Boolean; overload;
    function Contain(ANode: INode): Boolean; overload;
    function Contain(ANodeID: TNodeID): Boolean; overload;

    function IndexOfNode(ANode: INode): Integer; // она как-то не особо нужна

    function CompareTo(AOther: IBucket): Integer;

    function Equals(AOther: IBucket): Boolean;
    function GetHashCode: Integer;
    function ToString: string;

    property LastChanged: TDateTime read GetLastChanged write SetLastChanged;

    property Max: TNodeID read GetMax;
    property Min: TNodeID read GetMin;

    property Nodes: TEnumerable<INode> read GetNodes;
    property NodesCount: Integer read GetNodesCount;

    property Replacement: INode read GetReplacement write SetReplacement;
  end;

  IPeer = interface
  ['{5C5769BE-5359-48FC-B632-A56C59E1AB46}']
    function GetHost: string;
    function GetPort: TIdPort;

    function GetCompactAddress: TUniString;

    property Host: string read GetHost;
    property Port: TIdPort read GetPort;
    property CompactAddress: TUniString read GetCompactAddress;
  end;

  IMessage = interface
  ['{F2C3D311-94DC-4B49-AAFC-384E76ADBC48}']
    function GetID: TNodeID;
    function GetClientVersion: TUniString;
    function GetMessageType: TUniString;
    function GetTransactionID: TUniString;

    property ClientVersion: TUniString read GetClientVersion;
    property MessageType: TUniString read GetMessageType;
    property TransactionId: TUniString read GetTransactionID;
    property ID: TNodeID read GetID;

    function Encode: TUniString;
  end;

  IQueryMessage = interface(IMessage)
  ['{3EA9BF45-3CB8-427C-80BD-83CB297CE6B9}']
    function GetResponseCreator: TFunc<IBencodedDictionary, IQueryMessage, IMessage>;
    function GetParameters: IBencodedDictionary;

    property ResponseCreator: TFunc<IBencodedDictionary, IQueryMessage, IMessage> read GetResponseCreator;
    property Parameters: IBencodedDictionary read GetParameters;
  end;

  IResponseMessage = interface(IMessage)
  ['{AF76945A-6958-4113-A99F-85DB4668768C}']
    function GetParameters: IBencodedDictionary;
    function GetQuery: IQueryMessage;

    property Parameters: IBencodedDictionary read GetParameters;
    property Query: IQueryMessage read GetQuery;
  end;

  IErrorMessage = interface(IMessage)
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

  IGetPeersResponse = interface(IResponseMessage)
  ['{F1A2D60D-E51D-4F4D-A1AC-4979CF29589E}']
    function GetToken: TUniString;
    function GetNodes: TUniString;
    function GetValues: IBencodedList;

    property Token: TUniString read GetToken;
    property Nodes: TUniString read GetNodes;
    property Values: IBencodedList read GetValues;
  end;

  IFindNodeResponse = interface(IResponseMessage)
  ['{8E5EAE5F-A926-4435-819C-448046C42A8D}']
    function GetNodes: TUniString;

    property Nodes: TUniString read GetNodes;
  end;

  IPingResponse = interface(IResponseMessage)
  ['{955569DD-BF73-4242-8B8D-E27D9A1F46D3}']
  end;

  IAnnouncePeer = interface(IQueryMessage)
  ['{B623BC5A-5AC3-4A12-8E4A-227FFCC84A5A}']
    function GetInfoHash: TNodeID;
    function GetPort: TIdPort;
    function GetToken: TUniString;

    property InfoHash: TNodeID read GetInfoHash;
    property Port: TIdPort read GetPort;
    property Token: TUniString read GetToken;
  end;

  IFindNode = interface(IQueryMessage)
  ['{DEDEA1AB-5225-4295-A329-0CA912B70494}']
    function GetTarget: TNodeID;

    property Target: TNodeID read GetTarget;
  end;

  IGetPeers = interface(IQueryMessage)
  ['{798F3829-5D8A-4CEE-A24D-0EE8BD1F419F}']
    function GetInfoHash: TNodeID;

    property InfoHash: TNodeID read GetInfoHash;
  end;

  IPing = interface(IQueryMessage)
  ['{0730B787-F457-4A38-AC90-239821DBEAD2}']
  end;

  ICompleteEventArgs = interface
  ['{D30F710D-7473-4FC6-89B9-79A3CDB814AF}']
  end;

  ITask = interface(IBusy)
  ['{7ACFDA3B-1E67-4955-A0E2-02C6C9816E0D}']
    function GetCompleted: Boolean;
    function GetOnCompleted: TProc<ITask, ICompleteEventArgs>;
    procedure SetOnCompleted(const Value: TProc<ITask, ICompleteEventArgs>);

    procedure Reset;

    property Completed: Boolean read GetCompleted;
    property OnCompleted: TProc<ITask, ICompleteEventArgs> read GetOnCompleted write SetOnCompleted;
  end;

  ISendQueryTask = interface(ITask)
  ['{3BB84873-DAAB-425B-84E3-147EA4BF3232}']
    function GetTarget: INode;

    property Target: INode read GetTarget;
  end;

  ISendQueryEventArgs = interface(ICompleteEventArgs)
  ['{3228A7BA-C521-481F-98FF-FE089E67065B}']
    function GetHost: string;
    function GetPort: TIdPort;
    function GetQuery: IQueryMessage;
    function GetResponse: IResponseMessage;
    function GetTimedOut: Boolean;

    property Host: string read GetHost;
    property Port: TIdPort read GetPort;
    property Query: IQueryMessage read GetQuery;
    property Response: IResponseMessage read GetResponse;
    property TimedOut: Boolean read GetTimedOut;
  end;

  IInitialiseTask = interface(ITask)
  ['{95E7679F-F296-44B9-8AA7-CEA12F0EB90C}']
  end;

  IRefreshBucketTask = interface(ITask)
  ['{44FEBB0E-0DB4-4795-8F4A-EF9A9C592FF5}']
  end;

  IFindPeersTask = interface(ITask)
  ['{D2EEE4D3-6A3E-43B0-A795-31892F933FDB}']
    function GetInfoHash: TNodeID;
    function GetOnPeersFound: TProc<TArray<IPeer>>;
    procedure SetOnPeersFound(const Value: TProc<TArray<IPeer>>);

    property InfoHash: TNodeID read GetInfoHash;
    property OnPeersFound: TProc<TArray<IPeer>> read GetOnPeersFound write SetOnPeersFound;
  end;

  IGetPeersTask = interface(IFindPeersTask)
  ['{C832DC19-7BF0-4B61-8582-7FAABFD51F5D}']
    function GetClosestActiveNodes: TEnumerable<INode>;
    function GetClosestActiveNodesCount: Integer;

    property ClosestActiveNodes: TEnumerable<INode> read GetClosestActiveNodes;
    property ClosestActiveNodesCount: Integer read GetClosestActiveNodesCount;
  end;

  IAnnounceTask = interface(IFindPeersTask)
  ['{6C586445-1D21-43C7-B41E-5F357E1793E5}']
    function GetPort: TIdPort;

    property Port: TIdPort read GetPort;
  end;

  IRoutingTable = interface
  ['{F3DE6C68-2BD3-4485-B6EC-BC1E841FC9DC}']
    function GetBuckets: TEnumerable<IBucket>;
    function GetBucketsCount: Integer;
    function GetNodesCount: Integer;
    function GetClosest(ATarget: TNodeID): TArray<INode>;
    function GetLocalNode: INode;
    function GetOnAddNode: TProc<INode>;
    procedure SetOnAddNode(Value: TProc<INode>);

    function Add(ANode: INode): Boolean;
    function FindNode(ANodeID: TNodeID): INode;
    function ContainsNode(ANodeID: TNodeID): Boolean;
    procedure Clear;

    property Buckets: TEnumerable<IBucket> read GetBuckets;
    property BucketsCount: Integer read GetBucketsCount;
    property NodesCount: Integer read GetNodesCount;
    property Closest[ATarget: TNodeID]: TArray<INode> read GetClosest;
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

  IMessageLoop = interface(IBusy)
  ['{2C78F069-4FF2-485E-9D0C-1B6B7208F70E}']
    function GetOnError: TProc<IMessageLoop, string, TIdPort, Exception>;
    procedure SetOnError(const Value: TProc<IMessageLoop, string, TIdPort, Exception>);

    procedure Start;
    procedure Stop;

    procedure EnqueueSend(const AHost: string; APort: TIdPort;
      AMessage: IMessage; AOnSent: TProc<ISendQueryEventArgs> = nil); overload;
    procedure EnqueueSend(ANode: INode; AMessage: IMessage;
      AOnSent: TProc<ISendQueryEventArgs> = nil); overload;

    property OnError: TProc<IMessageLoop, string, TIdPort, Exception> read GetOnError write SetOnError;
  end;

  IDHTEngine = interface(IBusy)
  ['{E0E1833D-196C-490A-BB93-32A5682245B1}']
    function GetOnBootstrapComplete: TProc<IDHTEngine>;
    procedure SetOnBootstrapComplete(const Value: TProc<IDHTEngine>);

    function Announce(const AInfoHash: TUniString; APort: TIdPort): IAnnounceTask;
    function GetPeers(const AInfoHash: TUniString): IGetPeersTask;

    procedure AddBootstrapNode(const AHost: string; APort: TIdPort);

    property OnBootstrapComplete: TProc<IDHTEngine> read GetOnBootstrapComplete write SetOnBootstrapComplete;
  end;

  EDHTException = class(Exception);
  EDHTEngine = class(EDHTException);
  EMessageLoop = class(EDHTException);
  EInvalidCompactNodesFormat = class(EDHTException);
  EGetPeersResponse = class(EDHTException);
  EMessageFactory = class(EDHTException);
  EErrorMessage = class(EDHTException);

implementation

{ TErrorCodeHelper }

function TErrorCodeHelper.GetAsInteger: Integer;
begin
  Result := ErrorCodesInt[Self];
end;

procedure TErrorCodeHelper.SetAsInteger(const Value: Integer);
var
  it: TErrorCode;
begin
  for it := Low(TErrorCode) to High(TErrorCode) do
    if ErrorCodesInt[it] = Value then
    begin
      Self := it;
      Break;
    end;
end;

end.
