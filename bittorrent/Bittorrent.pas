unit Bittorrent;

interface

uses
  System.SysUtils, System.Generics.Collections, System.Generics.Defaults,
  System.Classes, System.DateUtils, System.TimeSpan,
  Basic.UniString, BusyObj, Bittorrent.Utils,
  Bittorrent.Bitfield, Bittorrent.Server, Bittorrent.ThreadPool,
  AccurateTimer,
  IdIOHandler, IdGlobal, IdContext, IdSchedulerOfThreadPool,
  Spring.Collections;

const
  DefaultPeerID           = '-MD0001-MADMADMAMMAD'; // in handshake
  DefaultClientVersion    = 'MAD Torrent 0.0.1';    // in extended handshake
  DefaultBlackListTime    = 30; { секунд }
  DefaultSeedingIdleTime  = 5;  { минут } // время, после которого выбрасываем раздачу из списка раздач

type
  {$REGION 'Messages'}
  IMessage = interface // переименовать бы в IPersistentMessage
  ['{1737BD06-7CF1-4323-BC33-806EB060CD3D}']
    function GetMsgSize: Integer;
    procedure Send(AIOHandler: TIdIOHandler);

    property MsgSize: Integer read GetMsgSize;
  end;

  TFixedMessageID = (
    idChoke         = 0,
    idUnchoke       = 1,
    idInterested    = 2,
    idNotInterested = 3,
    idHave          = 4,
    idBitfield      = 5,
    idRequest       = 6,
    idPiece         = 7,
    idCancel        = 8,
    idPort          = 9,
    idExtended      = 20
  );

  IFixedMessage = interface(IMessage)
  ['{EBC1F174-649A-44C0-BF94-FBD28646CBBC}']
    function GetMessageID: TFixedMessageID;
    //function GetPayloadSize: Integer;

    property MessageID: TFixedMessageID read GetMessageID;
    //property PayloadSize: Integer read GetPayloadSize;
  end;

  { пустое сообщение, или сообщение, которое не удалось идентифицировать }
  IKeepAliveMessage = interface(IMessage)
  ['{227D6130-9669-417E-A1AC-85637A66726F}']
    function GetDummy: TUniString;

    property Dummy: TUniString read GetDummy; { мусор }
  end;

  IChokeMessage = interface(IFixedMessage)
  ['{4FC4C2CF-D5BB-4740-B5B1-F49A658844D2}']
  end;

  IUnchokeMessage = interface(IFixedMessage)
  ['{FD18CD03-F648-4C7C-923A-A88CA86B1CC3}']
  end;

  IInterestedMessage = interface(IFixedMessage)
  ['{5CC649FA-4187-4107-9A03-D5816EA0ED43}']
  end;

  INotInterestedMessage = interface(IFixedMessage)
  ['{AD849517-D706-49E2-8858-B8A6CB4533C2}']
  end;

  IHaveMessage = interface(IFixedMessage)
  ['{A46C1A07-520E-445E-A2D2-236D459995DD}']
    function GetPieceIndex: Integer;

    property PieceIndex: Integer read GetPieceIndex;
  end;

  IBitfieldMessage = interface(IFixedMessage)
  ['{07F4AD47-E0B6-42B3-B1C6-EFC38987716F}']
    function GetBits: TBitField;

    property Bits: TBitField read GetBits;
  end;

  IRequestMessage = interface(IFixedMessage)
  ['{A9F5C862-1829-497A-B605-84AA54055F69}']
    function GetPieceIndex: Integer;
    function GetOffset: Integer;
    function GetSize: Integer;

    property PieceIndex: Integer read GetPieceIndex;
    property Offset: Integer read GetOffset;
    property Size: Integer read GetSize;
  end;

  IPieceMessage = interface(IFixedMessage)
  ['{04770891-7321-4282-84F1-BED1885E9B52}']
    function GetPieceIndex: Integer;
    function GetOffset: Integer;
    function GetBlock: TUniString;

    property PieceIndex: Integer read GetPieceIndex;
    property Offset: Integer read GetOffset;
    property Block: TUniString read GetBlock;
  end;

  ICancelMessage = interface(IFixedMessage)
  ['{421BC755-68A6-43B7-9492-17C599EA5060}']
    function GetPieceIndex: Integer;
    function GetOffset: Integer;
    function GetSize: Integer;

    property PieceIndex: Integer read GetPieceIndex;
    property Offset: Integer read GetOffset;
    property Size: Integer read GetSize;
  end;

  IPortMessage = interface(IFixedMessage)
  ['{E613243D-C193-494E-B533-7D35B5F3751D}']
    function GetPort: TIdPort;

    property Port: TIdPort read GetPort;
  end;

  IHandshakeMessage = interface(IMessage)
  ['{7A4C2C70-3DE7-45CD-A9FB-5FF5A43A347C}']
    function GetInfoHash: TUniString;
    function GetPeerID: TUniString;
    function GetFlags: TUniString;
    function GetSupportsDHT: Boolean;
    function GetSupportsExtendedMessaging: Boolean;
    function GetSupportsFastPeer: Boolean;

    property InfoHash: TUniString read GetInfoHash;
    property PeerID: TUniString read GetPeerID;
    property Flags: TUniString read GetFlags;
    property SupportsDHT: Boolean read GetSupportsDHT;
    property SupportsExtendedMessaging: Boolean read GetSupportsExtendedMessaging;
    property SupportsFastPeer: Boolean read GetSupportsFastPeer;
  end;

  IExtension = interface
  ['{B034EFF5-9A3F-45DB-AD3C-A76D376E6B97}']
    function GetData: TUniString;
    function GetSize: Integer;
    function GetSupportName: string;

    property Data: TUniString read GetData;
    property Size: Integer read GetSize;
    property SupportName: string read GetSupportName;
  end;

  IExtensionHandshake = interface(IExtension)
  ['{1991B2A0-2055-4C90-8DDE-0AB2A8178209}']
    function GetClientVersion: string;
    function GetPort: TIdPort;
    function GetMetadataSize: Integer;
    function GetSupports: IDictionary<string, Byte>;

    property ClientVersion: string read GetClientVersion;
    property Port: TIdPort read GetPort;
    property MetadataSize: Integer read GetMetadataSize;
    property Supports: IDictionary<{Name}string, {MsgID}Byte> read GetSupports;
  end;

  TMetadataMessageType = (mmtRequest = 0, mmtData = 1, mmtReject = 2);

  IExtensionMetadata = interface(IExtension)
  ['{CBF226B0-2555-499E-9C41-738448E4AE58}']
    function GetMessageType: TMetadataMessageType;
    function GetPiece: Integer;
    function GetMetadata: TUniString;

    property MessageType: TMetadataMessageType read GetMessageType;
    property Piece: Integer read GetPiece;
    property Metadata: TUniString read GetMetadata;
  end;

  TCommentMessageType = (cmtRequest = 0, cmtResponse = 1);

  IExtensionComment = interface(IExtension)
  ['{25DF5692-E76B-48E3-882A-9932B02B3DD8}']
    function GetMessageType: TCommentMessageType;

    property MessageType: TCommentMessageType read GetMessageType;
  end;

  IExtensionMessage = interface(IMessage)
  ['{4B8D86F8-33E3-479B-8C5D-BD89715B5861}']
    function GetExtension: IExtension;
    function GetMessageID: Byte;

    property MessageID: Byte read GetMessageID;
    property Extension: IExtension read GetExtension;
  end;
  {$ENDREGION}

  TConnectionType = (ctUnknown, ctOutgoing, ctIncoming);

  IConnection = interface
  ['{3AD9799D-DECE-42E7-AE25-1F79B96ED08A}']
    function GetHost: string;
    function GetPort: TIdPort;
    function GetIPVer: TIdIPVersion;
    function GetConnected: Boolean;
    function GetConnectionType: TConnectionType;
    function GetBytesSend: UInt64;
    function GetBytesReceived: UInt64;
    function GetOnDisconnect: TProc;
    procedure SetOnDisconnect(Value: TProc);

    procedure Connect;
    procedure Disconnect;

    procedure SendMessage(AMessage: IMessage);
    function ReceiveMessage(AHandshake: Boolean = False): IMessage;

    property Host: string read GetHost;
    property Port: TIdPort read GetPort;
    property IPVer: TIdIPVersion read GetIPVer;
    property Connected: Boolean read GetConnected;
    property ConnectionType: TConnectionType read GetConnectionType;

    property BytesSend: UInt64 read GetBytesSend;
    property BytesReceived: UInt64 read GetBytesReceived;

    property OnDisconnect: TProc read GetOnDisconnect write SetOnDisconnect;
  end;

  TPeerFlag = (pfWeChoke, pfWeInterested, pfTheyChoke, pfTheyInterested);
  TPeerFlags = set of TPeerFlag;

  IPeer = interface(IBusy)
  ['{C19B9DFA-B91E-4302-8FE2-BB8F6B18E62B}']
    {$REGION 'selectors/modificators'}
    function GetBitfield: TBitField;
    function GetConnected: Boolean;
    function GetFlags: TPeerFlags;
    function GetOnConnect: TProc<IPeer, IMessage>;
    procedure SetOnConnect(Value: TProc<IPeer, IMessage>);
    function GetOnChoke: TProc<IPeer>;
    procedure SetOnChoke(Value: TProc<IPeer>);
    function GetOnUnchoke: TProc<IPeer>;
    procedure SetOnUnchoke(Value: TProc<IPeer>);
    function GetOnInterest: TProc<IPeer>;
    procedure SetOnInterest(Value: TProc<IPeer>);
    function GetOnNotInerest: TProc<IPeer>;
    procedure SetOnNotInerest(Value: TProc<IPeer>);
    function GetOnBitField: TProc<TBitField>;
    procedure SetOnBitField(Value: TProc<TBitField>);
    function GetOnHave: TProc<Integer>;
    procedure SetOnHave(Value: TProc<Integer>);
    function GetOnRequest: TProc<IPeer, Integer, Integer, Integer>;
    procedure SetOnRequest(Value: TProc<IPeer, Integer, Integer, Integer>);
    function GetOnCancel: TProc<IPeer, Integer, Integer, Integer>;
    procedure SetOnCancel(Value: TProc<IPeer, Integer, Integer, Integer>);
    function GetOnPiece: TProc<IPeer, Integer, Integer, TUniString>;
    procedure SetOnPiece(Value: TProc<IPeer, Integer, Integer, TUniString>);
    function GetOnException: TProc<IPeer, Exception>;
    procedure SetOnException(Value: TProc<IPeer, Exception>);
    function GetHost: string;
    function GetPort: TIdPort;
    function GetIPVer: TIdIPVersion;
    function GetExteinsionSupports: IDictionary<{Name}string, {MsgID}Byte>;
    function GetHashCode: Integer;
    function GetOnExtendedMessage: TProc<IPeer, IExtension>;
    procedure SetOnExtendedMessage(Value: TProc<IPeer, IExtension>);
    {$ENDREGION}

    procedure Interested;
    procedure NotInterested;
    procedure Choke;
    procedure Unchoke;
    procedure Request(AIndex, AOffset, ALength: Integer);
    procedure SendHave(AIndex: Integer);
    procedure SendBitfield(const ABitfield: TBitField); { как-то бы назвать их грамотно }
    procedure SendPiece(APieceIndex, AOffset: Integer; const ABlock: TUniString);
    procedure SendPort(APort: TIdPort);
    procedure SendExtensionMessage(AExtension: IExtension);

    property Bitfield: TBitField read GetBitfield;
    property Connected: Boolean read GetConnected; { значит, что связь установлена и подтверждена }
    property Flags: TPeerFlags read GetFlags;

    property Host: string read GetHost;
    property Port: TIdPort read GetPort;
    property IPVer: TIdIPVersion read GetIPVer;
    property ExteinsionSupports: IDictionary<{Name}string, {MsgID}Byte> read GetExteinsionSupports;

    property HashCode: Integer read GetHashCode;

    /// Events
    property OnConnect: TProc<IPeer, IMessage> read GetOnConnect write SetOnConnect;
    property OnChoke: TProc<IPeer> read GetOnChoke write SetOnChoke;
    property OnUnchoke: TProc<IPeer> read GetOnUnchoke write SetOnUnchoke;
    property OnInterest: TProc<IPeer> read GetOnInterest write SetOnInterest;
    property OnNotInerest: TProc<IPeer> read GetOnNotInerest write SetOnNotInerest;

    property OnBitField: TProc<TBitField> read GetOnBitField write SetOnBitField;
    property OnHave: TProc<Integer { index }> read GetOnHave write SetOnHave;
    // с нас запрашивают блок index    offset   size     data
    property OnRequest: TProc<IPeer, Integer, Integer, Integer>
      read GetOnRequest write SetOnRequest;
    property OnCancel: TProc<IPeer, Integer, Integer, Integer>
      read GetOnCancel write SetOnCancel;
    property OnPiece: TProc<IPeer, Integer, Integer, TUniString> read GetOnPiece write SetOnPiece;
    property OnExtendedMessage: TProc<IPeer, IExtension> read GetOnExtendedMessage write SetOnExtendedMessage;
    property OnException: TProc<IPeer, Exception> read GetOnException write SetOnException;
  end;

  ITracker = interface(IBusy)
  ['{91C224F2-8443-4D74-A444-0F9874F9D768}']
    function GetInfoHash: TUniString;
    function GetAnnounceURL: string;
    function GetScrapeURL: string;
    function GetFailureResponse: string;
    function GetOnAnnounce: TProc<ITracker>;
    procedure SetOnAnnounce(const Value: TProc<ITracker>);
    function GetOnScrape: TProc<ITracker>;
    procedure SetOnScrape(const Value: TProc<ITracker>);

    property InfoHash: TUniString read GetInfoHash;

    property AnnounceURL: string read GetAnnounceURL;
    property ScrapeURL: string read GetScrapeURL;

    property FailureResponse: string read GetFailureResponse;

    property OnAnnounce: TProc<ITracker> read GetOnAnnounce write SetOnAnnounce;
    property OnScrape: TProc<ITracker> read GetOnScrape write SetOnScrape;
  end;

  THTTPTrackerEvent = (evStarted, evStopped, evComplete);

  THTTPTrackerEventHelper = record helper for THTTPTrackerEvent
    function ToString: string;
  end;

  IHTTPTrackerPeerInfo = interface
  ['{7DF7D17E-0949-47C2-97D6-AFDFFF4475EB}']
    function GetPeerID: TUniString;
    function GetHost: string;
    function GetPort: TIdPort;

    property PeerID: TUniString read GetPeerID;
    property Host: string read GetHost;
    property Port: TIdPort read GetPort;
  end;

  IHTTPTracker = interface(ITracker)
  ['{A9DD16E2-40F2-479A-B9C5-E8F7CA664C73}']
    function GetPeerID: string;
    function GetKey: string;
    function GetPort: TIdPort;
    function GetUploaded: UInt64;
    procedure SetUploaded(const Value: UInt64);
    function GetDownloaded: UInt64;
    procedure SetDownloaded(const Value: UInt64);
    function GetLeft: UInt64;
    procedure SetLeft(const Value: UInt64);
    function GetCorrupt: UInt64;
    procedure SetCorrupt(const Value: UInt64);
    function GetEvent: THTTPTrackerEvent;
    procedure SetEvent(const Value: THTTPTrackerEvent);
    function GetPeers: TList<IHTTPTrackerPeerInfo>;

    property PeerID: string read GetPeerID;
    property Key: string read GetKey;
    property Port: TIdPort read GetPort;
    property Uploaded: UInt64 read GetUploaded write SetUploaded;
    property Downloaded: UInt64 read GetDownloaded write SetDownloaded;
    property Left: UInt64 read GetLeft write SetLeft;
    property Corrupt: UInt64 read GetCorrupt write SetCorrupt;
    property Event: THTTPTrackerEvent read GetEvent write SetEvent;
    property Peers: TList<IHTTPTrackerPeerInfo> read GetPeers;
  end;

  IMagnetURI = interface
  ['{C90069A3-FA2D-41DE-897A-09868B542325}']
    function GetInfoHash: TUniString;
    function GetDisplayName: string;
    function GetTrackers: TStrings;
    function GetWebSeeds: TStrings;

    property InfoHash: TUniString read GetInfoHash;
    property DisplayName: string read GetDisplayName;
    property Trackers: TStrings read GetTrackers;
    property WebSeeds: TStrings read GetWebSeeds;
  end;

  IFileItem = interface
  ['{D93D9C1C-C709-4D53-BC9C-864C7A31A802}']
    function GetFilePath: string;
    function GetFileSize: UInt64;
    function GetFileOffset: UInt64;

    property FilePath: string read GetFilePath; { путь }
    property FileSize: UInt64 read GetFileSize; { размер }
    property FileOffset: UInt64 read GetFileOffset; { абсолютное смещение в общем потоке }
  end;

  IMetaFile = interface
  ['{E5ACCB77-FCEC-4DAF-8216-4CF23E63E30B}']
    function GetTotalSize: UInt64;
    function GetPieceHash(Index: Integer): TUniString;
    function GetPieceLength(APieceIndex: Integer): Integer;
    function GetPieceOffset(APieceIndex: Integer): Int64;
    function GetPiecesCount: Integer;
    function GetPiecesLength: Integer;
    function GetFilesByPiece(Index: Integer): IList<IFileItem>;
    function GetFiles: TList<IFileItem>;
    function GetTrackers: TStrings;
    function GetInfoHash: TUniString;
    function GetMetadataSize: Integer;
    function GetMetadata: TUniString;

    procedure LoadFromStream(AStream: TStream);
    procedure SaveToStream(AStream: TStream);

    property TotalSize: UInt64 read GetTotalSize;
    property PiecesCount: Integer read GetPiecesCount;
    property PiecesLength: Integer read GetPiecesLength;
    property PieceHash[Index: Integer]: TUniString read GetPieceHash;
    property PieceLength[APieceIndex: Integer]: Integer read GetPieceLength;
    property PieceOffset[APieceIndex: Integer]: Int64 read GetPieceOffset;
    property FilesByPiece[Index: Integer]: IList<IFileItem> read GetFilesByPiece;
    property Files: TList<IFileItem> read GetFiles;
    property Trackers: TStrings read GetTrackers;
    property InfoHash: TUniString read GetInfoHash;
    property MetadataSize: Integer read GetMetadataSize;
    property Metadata: TUniString read GetMetadata;
  end;

  IPiece = interface
  ['{89757657-B5F3-4C41-B8FE-933351B81D8A}']
    function GetCompleted: Boolean;
    function GetData: TUniString;
    function GetPieceLength: Integer;
    function GetIndex: Integer;

    procedure AddBlock(AOffset: Integer; const AData: TUniString);
    //function GetBlock(AOffset, ALength: Integer): TUniString;

    property Completed: Boolean read GetCompleted;
    property Data: TUniString read GetData;
    property PieceLength: Integer read GetPieceLength;
    property Index: Integer read GetIndex;
  end;

  IFileSystem = interface
  ['{A0154833-B944-4245-B515-4BDDBD14CBF3}']
    function GetDownloadFolder: string;
    procedure SetDownloadFolder(Value: string);
    function GetPiece(APieceIndex: Integer): IPiece;
    function GetOnChange: TProc<IFileSystem>;
    procedure SetOnChange(Value: TProc<IFileSystem>);

    procedure ClearCaches; { периодическая очистка файлового пула }
    function PieceCheck(APiece: IPiece): Boolean;
    procedure PieceWrite(APiece: IPiece);
    function CheckFiles: TBitField; { попытаться открыть файлы, прочитать куски и заполнить битфилд }

    procedure DeleteFiles;

    property DownloadFolder: string read GetDownloadFolder write SetDownloadFolder;
    property Piece[APieceIndex: Integer]: IPiece read GetPiece;

    property OnChange: TProc<IFileSystem> read GetOnChange write SetOnChange;
  end;

  IPiecePicker = interface
  ['{6D8A652E-852F-4F50-BDF7-4AC80E8812A1}']
    procedure PickPiece(APeer: IPeer; AAllPeers: TList<IPeer>;
      AWant: TBitField; ACallBack: TProc<Integer>);
  end;

  TSeedingState = (ssUnknown, ssHaveMetadata, ssActive, ssChecking, ssRetracking,
    ssDownloading, ssPaused, ssSeeding, ssCompleted, ssError, ssCorrupted);
  TSeedingStates = set of TSeedingState;

  ISeeding = interface(IBusy) { раздача, она же и закачка }
  ['{A428EA0C-EF82-4A67-9F74-DF22EC858D20}']
    function GetLastRequest: TDateTime;
    function GetPeers: TList<IPeer>;
    function GetTrackers: TList<ITracker>;
    function GetInfoHash: TUniString;
    function GetBitfield: TBitField;
    function GetMetafile: IMetaFile;
    function GetFileSystem: IFileSystem;
    function GetState: TSeedingStates;
    function GetHashErrorCount: Integer;
    function GetPercentComplete: Double;
    function GetDownloadPath: string;
    function GetOnMetadataLoaded: TProc<TUniString>;
    procedure SetOnMetadataLoaded(Value: TProc<TUniString>);

    procedure AddPeer(const AHost: string; APort: TIdPort; APeerID: string;
      AIPVer: TIdIPVersion = Id_IPv4); overload;
    procedure AddPeer(APeer: IPeer; AHSMessage: IHandshakeMessage); overload;
    procedure AddTracker(const ATrackerURL, APeerID: string; AListenPort: TIdPort);
    procedure Touch;
    procedure Delete(ADeleteFiles: Boolean = False);

    property LastRequest: TDateTime read GetLastRequest;
    property Peers: TList<IPeer> read GetPeers;
    property Trackers: TList<ITracker> read GetTrackers;
    property InfoHash: TUniString read GetInfoHash;
    property Bitfield: TBitField read GetBitfield;
    property Metafile: IMetaFile read GetMetafile;
    property FileSystem: IFileSystem read GetFileSystem;
    property State: TSeedingStates read GetState;
    property HashErrorCount: Integer read GetHashErrorCount;
    property PercentComplete: Double read GetPercentComplete;
    property DownloadPath: string read GetDownloadPath;
    property OnMetadataLoaded: TProc<TUniString> read GetOnMetadataLoaded write SetOnMetadataLoaded;
  end;

  TBittorrent = class
  private
    FThreads: TThreadPool;
    FClientVersion: string;
    FPeerID: string;
    FSeedings: TDictionary<TUniString, ISeeding>;
    FTerminated: Boolean;
    FLock: TObject;
    FListener: TTCPServer;
    FBlackListTime: Integer; // span
    FBlackListCounter: Integer; // избавиться бы от этого
    FBlackList: TDictionary<string, TDateTime>;
    FOnConnectIncoming: TProc<IPeer, TUniString>;

    procedure SetPeerID(const Value: string);
    procedure SetBlackListTime(const Value: Integer);
    procedure OnPeerConnect(AContext: TIdContext);
    function Blacklisted(AHost: string): Boolean; inline;
    procedure AddToBlackList(AHost: string); inline;

    procedure AddSeeding(ASeeding: ISeeding); inline;
    procedure Lock; inline;
    procedure Unlock; inline;
  public
    procedure Start; { запуск основного цикла }
    procedure Stop; inline;

    procedure AddPeer(const AInfoHash: TUniString; const AHost: string;
      APort: TIdPort; AIPVer: TIdIPVersion = Id_IPv4);

    { добавить торрент-файл }
    function AddTorrent(const AFileName, ADownloadPath: string): TUniString;
    { добавить торрент по magnet-ссылке }
    function AddMagnetURI(const AMagnetURI, ADownloadPath: string): TUniString;
    { добавить торрент-трекер }
    procedure AddTracker(const AInfoHash: TUniString; const ATrackerURL: string);

    function DeleteTorrent(const AInfoHash: TUniString): Boolean;

    class constructor ClassCreate;

    property Seedings: TDictionary<TUniString, ISeeding> read FSeedings;
    property ClientVersion: string read FClientVersion write FClientVersion;
    property PeerID: string read FPeerID write SetPeerID;
    property BlackListTime: Integer read FBlackListTime write SetBlackListTime;

    property OnConnectIncoming: TProc<IPeer, TUniString> read FOnConnectIncoming write FOnConnectIncoming;
    constructor Create(AListenPort: TIdPort); { передавать параметры для запуска слушалки }
    destructor Destroy; override;
  end;

  EBittorrentException        = class(Exception);

  ETrackerException           = class(EBittorrentException);
  ETrackerInvalidProtocol     = class(ETrackerException);
  ETrackerInvalidKey          = class(ETrackerException);
  ETrackerFailure             = class(ETrackerException);

  EServerException            = class(EBittorrentException);
  EServerInvalidPeer          = class(EServerException);

  EFileSystemException        = class(EBittorrentException);
  EFileSystemReadException    = class(EFileSystemException);
  EFileSystemWriteException   = class(EFileSystemException);
  EFileSystemCheckException   = class(EFileSystemException);

implementation

uses
  Bittorrent.Seeding, Bittorrent.MagnetURI, Bittorrent.MetaFile,
  Bittorrent.Messages, Bittorrent.Extensions, Bittorrent.Peer,
  Bittorrent.Connection;

{ TBittorrent }

function TBittorrent.AddMagnetURI(const AMagnetURI,
  ADownloadPath: string): TUniString;
var
  uri: IMagnetURI;
  s: ISeeding;
begin
  uri := TMagnetURI.Create(AMagnetURI) as IMagnetURI;
  Result := uri.InfoHash;

  s := TSeeding.Create(ADownloadPath, FThreads, Result, FClientVersion, 0) as ISeeding;
  s.OnMetadataLoaded := procedure (AData: TUniString)
  begin
    // не суть важно как именовать
    with TFileStream.Create(SHA1(AData).ToHexString + '.torrent', fmCreate) do
    try
      Write(AData.DataPtr[0]^, AData.Len);
    finally
      Free;
    end;
  end;

  AddSeeding(s);
end;

procedure TBittorrent.AddPeer(const AInfoHash: TUniString; const AHost: string;
  APort: TIdPort; AIPVer: TIdIPVersion);
begin
  Lock;
  try
    if FSeedings.ContainsKey(AInfoHash) then
      FSeedings[AInfoHash].AddPeer(AHost, APort, FPeerID, AIPVer);
  finally
    Unlock;
  end;
end;

procedure TBittorrent.AddSeeding(ASeeding: ISeeding);
begin
  Lock;
  try
    if not FSeedings.ContainsKey(ASeeding.InfoHash) then
      FSeedings.Add(ASeeding.InfoHash, ASeeding);
  finally
    Unlock;
  end;
end;

procedure TBittorrent.AddToBlackList(AHost: string);
begin
  Lock;
  try
    FBlackList.AddOrSetValue(AHost, UtcNow);
  finally
    Unlock;
  end;
end;

function TBittorrent.AddTorrent(const AFileName,
  ADownloadPath: string): TUniString;
var
  mf: IMetaFile;
begin
  mf := TMetaFile.Create(AFileName) as IMetaFile;
  Result := mf.InfoHash;

  AddSeeding(TSeeding.Create(ADownloadPath, FThreads, mf, FClientVersion, 0));
end;

procedure TBittorrent.AddTracker(const AInfoHash: TUniString; const ATrackerURL: string);
var
  s: ISeeding;
begin
  Lock;
  try
    if FSeedings.TryGetValue(AInfoHash, s) then
      s.AddTracker(ATrackerURL, FPeerID, FListener.DefaultPort);
  finally
    Unlock;
  end;
end;

function TBittorrent.Blacklisted(AHost: string): Boolean;
begin
  Lock;
  try
    Result := FBlackList.ContainsKey(AHost);
  finally
    Unlock;
  end;
end;

class constructor TBittorrent.ClassCreate;
begin
  TExtension.AddExtension(TExtensionMetadata);
  TExtension.AddExtension(TExtensionComment);
end;

constructor TBittorrent.Create(AListenPort: TIdPort);
begin
  Randomize;
  FThreads    := TThreadPool.Create;
  FSeedings   := System.Generics.Collections.TDictionary<TUniString, ISeeding>.Create(
    TUniStringEqualityComparer.Create as IEqualityComparer<TUniString>
  );
  FLock       := TObject.Create;

  FClientVersion := DefaultClientVersion;
  FPeerID     := DefaultPeerID;

  FTerminated := False;

  FBlackListCounter := 1000;
  FBlackListTime := DefaultBlackListTime;
  FBlackList  := TDictionary<string, TDateTime>.Create;
  { слушалка }
  FListener   := TTCPServer.Create(AListenPort);
  FListener.OnExecute   := OnPeerConnect;
  FListener.Scheduler   := TIdSchedulerOfThreadPool.Create(FListener);
  with TIdSchedulerOfThreadPool(FListener.Scheduler) do
  begin
    MaxThreads  := 100;
    PoolSize    := 50;
  end;
end;

function TBittorrent.DeleteTorrent(const AInfoHash: TUniString): Boolean;
begin
  Lock;
  try
    Result := FSeedings.ContainsKey(AInfoHash);

    if Result then
    begin
      // удаляем раздачу
      FSeedings[AInfoHash].Delete;
      FSeedings.Remove(AInfoHash);
    end;
  finally
    Unlock;
  end;
end;

destructor TBittorrent.Destroy;
begin
  Stop;

  FBlackList.Free;
  FListener.Free;
  FThreads.Free;
  FSeedings.Free;
  FLock.Free;
  inherited;
end;

procedure TBittorrent.Lock;
begin
  System.TMonitor.Enter(FLock);
end;

procedure TBittorrent.OnPeerConnect(AContext: TIdContext);
var
  peer: IPeer;
  allOK: Boolean;
begin
  { проверяем, всё ли корректно и добавляем, если надо (иначе отключаем) }
  if Blacklisted(AContext.Binding.PeerIP) then
  begin
    AContext.Connection.Disconnect;
    Exit;
  end;

  try
    allOK := False;

    peer := TPeer.Create(FThreads,
        TIncomingConnection.Create(AContext.Connection) as IConnection,
        FPeerID) as IPeer;

    peer.OnConnect := procedure (APeer: IPeer; AMessage: IMessage)
    var
      seeding: ISeeding;
    begin
      with AMessage as IHandshakeMessage do
      begin
        // сообщаем о внешнем подключении
        if Assigned(FOnConnectIncoming) then
          FOnConnectIncoming(APeer, InfoHash);

        Lock;
        try
          allOK := FSeedings.TryGetValue(InfoHash, seeding);

          if allOK then
          begin
            seeding.AddPeer(APeer, AMessage as IHandshakeMessage); { добавляем новый пир }
            seeding.Touch;
          end;
        finally
          Unlock;
        end;
      end;
    end;

    { вызываем Sync, чтобы он законнектился и т.д. }
    peer.Sync;
    { ждем коннект }
    while peer.Busy do
      Sleep(10);

    if not allOK then
      raise EServerInvalidPeer.Create('Invalid peer');
  except
    AddToBlackList(AContext.Binding.PeerIP);
  end;
end;

procedure TBittorrent.SetBlackListTime(const Value: Integer);
begin
  Assert(Value >= 0);
  FBlackListTime := Value;
end;

procedure TBittorrent.SetPeerID(const Value: string);
begin
  // проверки
  FPeerID := Value;
end;

procedure TBittorrent.Start;
begin
  FListener.Active := FListener.DefaultPort <> 0;

  FTerminated := False;

  FThreads.Exec(function : Boolean
  var
    key: TUniString;
    h: string;
  begin
    Lock;
    try
      { тут надо бы порядок добавления торрентов соблюсти, плюс добавить ограничение }
      for key in FSeedings.Keys do
      with FSeedings[key] do
      begin
        if ssActive in State then
          Sync
        else
        if MinutesBetween(UtcNow, LastRequest) >= DefaultSeedingIdleTime then
        begin
          { если раздача неактивна более заданного времени -- убираем ее из списка.
            повторный подгруз раздачи при подключении пира извне (раздача перейдет в активный режим). }

          FSeedings.Remove(Key);
          Break;
        end;
      end;

      { чистим черный список }
      if FBlackListTime > 0 then
      begin
        if FBlackListCounter = 0 then
        begin
          for h in FBlackList.Keys do
            if MinutesBetween(UtcNow, FBlackList[h]) >= FBlackListTime then
            begin
              FBlackList.Remove(h);
              Break;
            end;

          FBlackListCounter := 10000;
        end else
          Dec(FBlackListCounter);
      end;

      DelayMicSec(100);
    finally
      Unlock;
    end;

    Result := not FTerminated;
  end);
end;

procedure TBittorrent.Stop;
begin
  FListener.Active := False;
  FTerminated := True;
end;

procedure TBittorrent.Unlock;
begin
  System.TMonitor.Exit(FLock);
end;

{ THTTPTrackerEventHelper }

function THTTPTrackerEventHelper.ToString: string;
const
  str: array[THTTPTrackerEvent] of string = (
    'started',
    'stopped',
    'complete'
  );
begin
  Result := str[Self];
end;

end.
