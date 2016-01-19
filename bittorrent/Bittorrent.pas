unit Bittorrent;

interface

uses
  System.SysUtils, System.Generics.Collections, System.Generics.Defaults,
  System.Classes, System.DateUtils, System.Math,
  Basic.UniString,
  Common.BusyObj, Common.ThreadPool, Common.AccurateTimer, Common.Prelude,
  Bittorrent.Bitfield,
  DHT,
  IdIOHandler, IdSocketHandle, IdGlobal, IdContext, IdStack;

const
  DefaultBlackListTime    = 30; { секунд }

type
  IMessage = interface
  ['{91B37A10-A79C-4586-93C3-B254CCBABD44}']
    function GetMsgSize: Integer;

    procedure Send(AIOHandler: TIdIOHandler);

    property MsgSize: Integer read GetMsgSize;
  end;

  TMessageID = (
    idChoke,
    idUnchoke,
    idInterested,
    idNotInterested,
    idHave,
    idBitfield,
    idRequest,
    idPiece,
    idCancel,
    idPort,
    idExtended
  );

  TMessageIDHelper = record helper for TMessageID
  private
    const
      MessageIDCode: array[TMessageID] of Byte = (
        {idChoke}         0,
        {idUnchoke}       1,
        {idInterested}    2,
        {idNotInterested} 3,
        {idHave}          4,
        {idBitfield}      5,
        {idRequest}       6,
        {idPiece}         7,
        {idCancel}        8,
        {idPort}          9,
        {idExtended}      20
      );
  private
    function GetAsByte: Byte; inline;
    procedure SetAsByte(const Value: Byte);
  public
    property AsByte: Byte read GetAsByte write SetAsByte;
    class function Parse(AValue: Byte): TMessageID; static; inline;
  end;

  IFixedMessage = interface(IMessage)
  ['{F120467F-3088-4E50-815A-717798367D03}']
    function GetMessageID: TMessageID;

    property MessageID: TMessageID read GetMessageID;
  end;

  { пустое сообщение, или сообщение, которое не удалось идентифицировать }
  IKeepAliveMessage = interface(IMessage)
  ['{E672DBB7-31E8-4B97-B6CF-A37B611EC447}']
    function GetDummy: TUniString;

    property Dummy: TUniString read GetDummy; { мусор }
  end;

  IChokeMessage = interface(IFixedMessage)
  ['{90A75323-8002-4E75-96B3-B0AD86107755}']
  end;

  IUnchokeMessage = interface(IFixedMessage)
  ['{E80C43DD-C663-4044-A883-455C8DC988A1}']
  end;

  IInterestedMessage = interface(IFixedMessage)
  ['{0A380AF8-7986-4EB3-AA55-CA77C2657F00}']
  end;

  INotInterestedMessage = interface(IFixedMessage)
  ['{620365DA-DE5A-4C6C-AEA4-131521CAAD9C}']
  end;

  IHaveMessage = interface(IFixedMessage)
  ['{D5FBDAB6-BABF-4D12-A2AF-A341D2F48DB7}']
    function GetPieceIndex: Integer;

    property PieceIndex: Integer read GetPieceIndex;
  end;

  IBitfieldMessage = interface(IFixedMessage)
  ['{4BD183FB-7A32-4688-A403-03482EF221A3}']
    function GetBitField: TBitField;

    property BitField: TBitField read GetBitField;
  end;

  IRequestMessage = interface(IFixedMessage)
  ['{37267B1A-0DF8-425A-9B1C-2E3DABA18B38}']
    function GetPieceIndex: Integer;
    function GetOffset: Integer;
    function GetSize: Integer;

    property PieceIndex: Integer read GetPieceIndex;
    property Offset: Integer read GetOffset;
    property Size: Integer read GetSize;
  end;

  IPieceMessage = interface(IFixedMessage)
  ['{9ED990F7-A704-46ED-9492-43E16566AC99}']
    function GetPieceIndex: Integer;
    function GetOffset: Integer;
    function GetBlock: TUniString;

    property PieceIndex: Integer read GetPieceIndex;
    property Offset: Integer read GetOffset;
    property Block: TUniString read GetBlock;
  end;

  ICancelMessage = interface(IFixedMessage)
  ['{EA4C56F8-0617-4FB8-A795-10A19981A86F}']
    function GetPieceIndex: Integer;
    function GetOffset: Integer;
    function GetSize: Integer;

    property PieceIndex: Integer read GetPieceIndex;
    property Offset: Integer read GetOffset;
    property Size: Integer read GetSize;
  end;

  IPortMessage = interface(IFixedMessage)
  ['{C71C7DC2-CA7A-4D24-B71A-68C477746563}']
    function GetPort: TIdPort;

    property Port: TIdPort read GetPort;
  end;

  IHandshakeMessage = interface(IMessage)
  ['{3F782B6B-8C70-48F6-ADB0-0DBBD2014416}']
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
  ['{28B28D8A-C375-490B-9AF2-183682E3916A}']
    function GetData: TUniString;
    function GetSize: Integer;
    function GetSupportName: string;

    property Data: TUniString read GetData;
    property Size: Integer read GetSize;
    property SupportName: string read GetSupportName;
  end;

  TExtensionItem = record
  private
    FName: string;
    FMsgID: Byte;
  public
    property Name: string read FName;
    property MsgID: Byte read FMsgID;

    constructor Create(const AName: string; AMsgID: Byte);
  end;

  IExtensionHandshake = interface(IExtension)
  ['{B8188CDB-CFDB-43EB-B8B5-04B245978EBE}']
    function GetClientVersion: string;
    function GetPort: TIdPort;
    function GetMetadataSize: Integer;
    function GetSupports: TDictionary<string, Byte>;

    property ClientVersion: string read GetClientVersion;
    property Port: TIdPort read GetPort;
    property MetadataSize: Integer read GetMetadataSize;
    property Supports: TDictionary<string, Byte> read GetSupports;
  end;

  TMetadataMessageType = (
    mmtRequest,
    mmtData,
    mmtReject
  );

  TMetadataMessageTypeHelper = record helper for TMetadataMessageType
  private
    const
      MetadataMessageTypeByte: array[TMetadataMessageType] of Byte = (
        {mmtRequest}  0,
        {mmtData}     1,
        {mmtReject}   2
      );
  private
    function GetAsByte: Byte; inline;
  public
    property AsByte: Byte read GetAsByte;
  end;

  IExtensionMetadata = interface(IExtension)
  ['{B9DBBB68-96CC-4D1A-AA1F-3B8E056278D8}']
    function GetMessageType: TMetadataMessageType;
    function GetPiece: Integer;
    function GetMetadata: TUniString;

    property MessageType: TMetadataMessageType read GetMessageType;
    property Piece: Integer read GetPiece;
    property Metadata: TUniString read GetMetadata;
  end;

  IExtensionMessage = interface(IMessage)
  ['{AA21A80E-6D53-411D-BB0D-B7E41DB2238C}']
    function GetExtension: IExtension;
    function GetMessageID: Byte;

    property MessageID: Byte read GetMessageID;
    property Extension: IExtension read GetExtension;
  end;

  TConnectionType = (ctUnknown, ctOutgoing, ctIncoming);

  IConnection = interface
  ['{3AD9799D-DECE-42E7-AE25-1F79B96ED08A}']
    function GetHost: string;
    function GetPort: TIdPort;
    function GetIPVer: TIdIPVersion;
    function GetConnected: Boolean;
    function GetConnectionType: TConnectionType;
    function GetBytesSent: UInt64;
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

    property BytesSent: UInt64 read GetBytesSent;
    property BytesReceived: UInt64 read GetBytesReceived;

    property OnDisconnect: TProc read GetOnDisconnect write SetOnDisconnect;
  end;

  IServer = interface
  ['{4C250AE1-61F3-47E7-8A86-3F6A876EEB33}']
    function GetListenPort: TIdPort;
    procedure SetListenPort(const Value: TIdPort);
    function GetActive: Boolean;
    procedure SetActive(const Value: Boolean);
    function GetOnConnect: TProc<IConnection>;
    procedure SetOnConnect(const Value: TProc<IConnection>);
    function GetBindings: TIdSocketHandles;
    procedure SetBindings(const Value: TIdSocketHandles);
    function GetUseNagle: Boolean;
    procedure SetUseNagle(const Value: Boolean);

    property ListenPort: TIdPort read GetListenPort write SetListenPort;
    property Active: Boolean read GetActive write SetActive;
    property OnConnect: TProc<IConnection> read GetOnConnect write SetOnConnect;
    property Bindings: TIdSocketHandles read GetBindings write SetBindings;
    property UseNagle: Boolean read GetUseNagle write SetUseNagle;
  end;

  TPeerFlag = (pfWeChoke, pfWeInterested, pfTheyChoke, pfTheyInterested);
  TPeerFlags = set of TPeerFlag;

  IPeer = interface(IBusy)
  ['{C19B9DFA-B91E-4302-8FE2-BB8F6B18E62B}']
    {$REGION 'selectors/modificators'}
    function GetInfoHash: TUniString;
    function GetClientID: TUniString;
    function GetBitfield: TBitField;
    function GetExtensionSupports: TArray<TExtensionItem>;
    function GetConnectionEstablished: Boolean;
    function GetConnectionConnected: Boolean;
    function GetFlags: TPeerFlags;
    function GetOnConnect: TProc<IPeer, IMessage>;
    procedure SetOnConnect(Value: TProc<IPeer, IMessage>);
    function GetOnDisonnect: TProc<IPeer>;
    procedure SetOnDisconnect(Value: TProc<IPeer>);
    function GetOnChoke: TProc<IPeer>;
    procedure SetOnChoke(Value: TProc<IPeer>);
    function GetOnUnchoke: TProc<IPeer>;
    procedure SetOnUnchoke(Value: TProc<IPeer>);
    function GetOnInterest: TProc<IPeer>;
    procedure SetOnInterest(Value: TProc<IPeer>);
    function GetOnNotInerest: TProc<IPeer>;
    procedure SetOnNotInerest(Value: TProc<IPeer>);
    function GetOnStart: TProc<IPeer, TUniString, TBitField>;
    procedure SetOnStart(Value: TProc<IPeer, TUniString, TBitField>);
    function GetOnHave: TProc<IPeer, Integer>;
    procedure SetOnHave(Value: TProc<IPeer, Integer>);
    function GetOnRequest: TProc<IPeer, Integer, Integer, Integer>;
    procedure SetOnRequest(Value: TProc<IPeer, Integer, Integer, Integer>);
    function GetOnCancel: TProc<IPeer, Integer, Integer>;
    procedure SetOnCancel(Value: TProc<IPeer, Integer, Integer>);
    function GetOnPiece: TProc<IPeer, Integer, Integer, TUniString>;
    procedure SetOnPiece(Value: TProc<IPeer, Integer, Integer, TUniString>);
    function GetOnPort: TProc<IPeer, TIdPort>;
    procedure SetOnPort(Value: TProc<IPeer, TIdPort>);
    function GetOnExtendedMessage: TProc<IPeer, IExtension>;
    procedure SetOnExtendedMessage(Value: TProc<IPeer, IExtension>);
    function GetOnException: TProc<IPeer, Exception>;
    procedure SetOnException(Value: TProc<IPeer, Exception>);
    function GetOnUpdateCounter: TProc<IPeer, UInt64, UInt64>;
    procedure SetOnUpdateCounter(Value: TProc<IPeer, UInt64, UInt64>);

    function GetHost: string;
    function GetPort: TIdPort;
    function GetIPVer: TIdIPVersion;
    function GetConnectionType: TConnectionType;
    function GetBytesSent: UInt64;
    function GetBytesReceived: UInt64;
    function GetRate: Single;
    function GetHashCode: Integer;
    {$ENDREGION}

    procedure Interested;
    procedure NotInterested;
    procedure Choke;
    procedure Unchoke;
    procedure Request(AIndex, AOffset, ALength: Integer);
    procedure Cancel(AIndex, AOffset: Integer);
    procedure SendHave(AIndex: Integer);
    procedure SendBitfield(const ABitfield: TBitField);
    procedure SendPiece(APieceIndex, AOffset: Integer; const ABlock: TUniString);
    procedure SendExtensionMessage(AExtension: IExtension);
    procedure SendPort(APort: TIdPort);

    procedure Disconnect;
    procedure Shutdown;

    property InfoHash: TUniString read GetInfoHash;
    property ClientID: TUniString read GetClientID;
    property Bitfield: TBitField read GetBitfield;
    property ExtensionSupports: TArray<TExtensionItem> read GetExtensionSupports;
    property ConnectionEstablished: Boolean read GetConnectionEstablished; { значит, что связь установлена и подтверждена }
    property ConnectionConnected: Boolean read GetConnectionConnected;
    property Flags: TPeerFlags read GetFlags;

    property Host: string read GetHost;
    property Port: TIdPort read GetPort;
    property IPVer: TIdIPVersion read GetIPVer;
    property ConnectionType: TConnectionType read GetConnectionType;

    property BytesSent: UInt64 read GetBytesSent;
    property BytesReceived: UInt64 read GetBytesReceived;
    property Rate: Single read GetRate;

    property HashCode: Integer read GetHashCode;

    /// Events
    property OnConnect: TProc<IPeer, IMessage> read GetOnConnect write SetOnConnect;
    property OnDisonnect: TProc<IPeer> read GetOnDisonnect write SetOnDisconnect;
    property OnChoke: TProc<IPeer> read GetOnChoke write SetOnChoke;
    property OnUnchoke: TProc<IPeer> read GetOnUnchoke write SetOnUnchoke;
    property OnInterest: TProc<IPeer> read GetOnInterest write SetOnInterest;
    property OnNotInerest: TProc<IPeer> read GetOnNotInerest write SetOnNotInerest;

    property OnStart: TProc<IPeer, TUniString, TBitField> read GetOnStart write SetOnStart;
    property OnHave: TProc<IPeer, Integer { index }> read GetOnHave write SetOnHave;
    // с нас запрашивают блок index    offset   size     data
    property OnRequest: TProc<IPeer, Integer, Integer, Integer>
      read GetOnRequest write SetOnRequest;
    property OnCancel: TProc<IPeer, Integer, Integer>
      read GetOnCancel write SetOnCancel;
    property OnPiece: TProc<IPeer, Integer, Integer, TUniString> read GetOnPiece write SetOnPiece;
    property OnPort: TProc<IPeer, TIdPort> read GetOnPort write SetOnPort;
    property OnExtendedMessage: TProc<IPeer, IExtension> read GetOnExtendedMessage write SetOnExtendedMessage;
    property OnException: TProc<IPeer, Exception> read GetOnException write SetOnException;
    property OnUpdateCounter: TProc<IPeer, UInt64, UInt64> read GetOnUpdateCounter write SetOnUpdateCounter;
  end;

  ITracker = interface(IBusy)
  ['{94C212F0-D558-404C-8A8A-9A7BA62121B0}']
    function GetInfoHash: TUniString;
    function GetAnnouncePort: TIdPort;
    function GetAnnounceInterval: Integer;
    function GetRetrackInterval: Integer;
    function GetOnResponsePeerInfo: TProc<string, TIdPort>;
    procedure SetOnResponsePeerInfo(const Value: TProc<string, TIdPort>);

    property InfoHash: TUniString read GetInfoHash;
    property AnnouncePort: TIdPort read GetAnnouncePort;
    property AnnounceInterval: Integer read GetAnnounceInterval;
    property RetrackInterval: Integer read GetRetrackInterval;
    property OnResponsePeerInfo: TProc<string, TIdPort> read GetOnResponsePeerInfo write SetOnResponsePeerInfo;
  end;

  IStatTracker = interface(ITracker)
  ['{2207713C-A73B-4815-A036-847F7183F44C}']
    function GetBytesUploaded: Int64;
    procedure SetBytesUploaded(const Value: Int64);
    function GetBytesDownloaded: Int64;
    procedure SetBytesDownloaded(const Value: Int64);
    function GetBytesLeft: Int64;
    procedure SetBytesLeft(const Value: Int64);
    function GetBytesCorrupt: Int64;
    procedure SetBytesCorrupt(const Value: Int64);

    property BytesUploaded: Int64 read GetBytesUploaded write SetBytesUploaded;
    property BytesDownloaded: Int64 read GetBytesDownloaded write SetBytesDownloaded;
    property BytesLeft: Int64 read GetBytesLeft write SetBytesLeft;
    property BytesCorrupt: Int64 read GetBytesCorrupt write SetBytesCorrupt;
  end;

  IWebTracker = interface(IStatTracker)
  ['{4E288897-308A-4ED0-A210-49B958A5E969}']
    function GetTrackerURL: string;

    property TrackerURL: string read GetTrackerURL;
  end;

  IDHTTracker = interface(ITracker)
  ['{E9883783-6856-4F22-9A4F-996AACCADB77}']
  end;

  IHTTPTracker = interface(IWebTracker)
  ['{9ED2EB24-5902-4BF5-BAC5-1B2D464CD1C2}']
  end;

  IFileItem = interface
  ['{D93D9C1C-C709-4D53-BC9C-864C7A31A802}']
    function GetFilePath: string;
    function GetFileSize: UInt64;
    function GetFileOffset: UInt64;
    function GetFirstPiece: Integer;
    function GetLastPiece: Integer;
    function GetPiecesCount: Integer;
    function GetHashCode: Integer;

    property FilePath: string read GetFilePath; { путь }
    property FileSize: UInt64 read GetFileSize; { размер }
    property FileOffset: UInt64 read GetFileOffset; { абсолютное смещение в общем потоке }
    property FirstPiece: Integer read GetFirstPiece;
    property LastPiece: Integer read GetLastPiece;
    property PiecesCount: Integer read GetPiecesCount;
    property HashCode: Integer read GetHashCode;
  end;

  IMetaFile = interface
  ['{E5ACCB77-FCEC-4DAF-8216-4CF23E63E30B}']
    function GetTotalSize: UInt64;
    function GetPieceHash(APieceIndex: Integer): TUniString;
    function GetPieceLength(APieceIndex: Integer): Integer;
    function GetPieceOffset(APieceIndex: Integer): Int64;
    function GetPiecesCount: Integer;
    function GetPiecesLength: Integer;
    function GetFilesByPiece(APieceIndex: Integer): TArray<IFileItem>;
    function GetFiles: TEnumerable<IFileItem>;
    function GetFilesCount: Integer;
    function GetInfoHash: TUniString;
    function GetMetadata: TUniString;
    function GetTrackers: TEnumerable<string>;

    property TotalSize: UInt64 read GetTotalSize;
    property PiecesCount: Integer read GetPiecesCount;
    property PiecesLength: Integer read GetPiecesLength;
    property PieceHash[APieceIndex: Integer]: TUniString read GetPieceHash;
    property PieceLength[APieceIndex: Integer]: Integer read GetPieceLength;
    property PieceOffset[APieceIndex: Integer]: Int64 read GetPieceOffset;
    property FilesByPiece[APieceIndex: Integer]: TArray<IFileItem> read GetFilesByPiece;
    property Files: TEnumerable<IFileItem> read GetFiles;
    property FilesCount: Integer read GetFilesCount;
    property InfoHash: TUniString read GetInfoHash;
    property Metadata: TUniString read GetMetadata;
    property Trackers: TEnumerable<string> read GetTrackers;
  end;

  IPiece = interface
  ['{89757657-B5F3-4C41-B8FE-933351B81D8A}']
    function GetCompleted: Boolean;
    function GetData: TUniString;
    function GetPieceLength: Integer;
    function GetIndex: Integer;

    procedure AddBlock(AOffset: Integer; const AData: TUniString);

    procedure EnumBlocks(ACallBack: TProc<Integer, Integer>);

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

    procedure ClearCaches(AFullClear: Boolean = False); { периодическая очистка файлового пула }
    function PieceCheck(APiece: IPiece): Boolean;
    procedure PieceWrite(APiece: IPiece);
    function CheckFiles: TBitField; { попытаться открыть файлы, прочитать куски и заполнить битфилд }

    procedure DeleteFiles;

    property DownloadFolder: string read GetDownloadFolder write SetDownloadFolder;
    property Piece[APieceIndex: Integer]: IPiece read GetPiece;

    property OnChange: TProc<IFileSystem> read GetOnChange write SetOnChange;
  end;

  TSeedingState = (
    ssHaveMetadata,   // наличие метаданных (т.к. их не можен не быть -- всегда активно)
    ssActive,         // раздача захватывается циклом
    ssChecking,       // проверка хешей раздачи
    ssDownloading,    // происходит загрузка
    ssPaused,         // загрузка активна, но приостановлена
    ssCompleted,      // все файлы полностью загружены
    ssCorrupted,      // раздача повреждена (не совпал хеш при чтении); используется в паре с ssError
    ssError           // загрузка прервана по причине ошибки (например не получилось открыть файл)
  );
  TSeedingStates = set of TSeedingState;

  TSeedingStatesHelper = record helper for TSeedingStates
  private
    function GetAsInteger: Integer;
    procedure SetAsInteger(const Value: Integer);
  public
    property AsInteger: Integer read GetAsInteger write SetAsInteger;
    class function Parse(const Value: Integer): TSeedingStates; inline; static;
  end;

  ICounter = interface
  ['{A1DD7ABD-D8B1-42A9-8A3E-8E0BEA087DFA}']
    function GetTotalDownloaded: UInt64;
    function GetTotalUploaded: UInt64;
    function GetDownloadSpeed: Single;
    function GetUploadSpeed: Single;

    property TotalDownloaded: UInt64 read GetTotalDownloaded;
    property TotalUploaded: UInt64 read GetTotalUploaded;
    property DownloadSpeed: Single read GetDownloadSpeed; { Кбайт в секунду }
    property UploadSpeed: Single read GetUploadSpeed;
  end;

  IMutableCounter = interface
  ['{F1C91B52-79FF-43E0-9101-2EB86254722F}']
    procedure Update(const ADownloaded, AUploaded: UInt64);
    procedure Add(const ADownloaded, AUploaded: UInt64);
    procedure ResetSpeed;
  end;

  TFilePriority = (fpSkip, fpLowest, fpLow, fpNormal, fpHigh, fpHighest,
    fpImmediate);

  ISeedingItem = interface
  ['{2828BC03-1FB2-4731-B8FA-696FA6EE11FE}']
    function GetPriority: TFilePriority;
    procedure SetPriority(const Value: TFilePriority);
    function GetPath: string;
    function GetSize: Int64;
    function GetFirstPiece: Integer;
    function GetLastPiece: Integer;
    function GetPiecesCount: Integer;
    function GetPercentComplete: Double;

    function IsLoaded(AOffset, ALength: Int64): Boolean;
    function Require(AOffset, ALength: Int64): Boolean;

    property Priority: TFilePriority read GetPriority write SetPriority;
    property Path: string read GetPath;
    property Size: Int64 read GetSize;
    property FirstPiece: Integer read GetFirstPiece;
    property LastPiece: Integer read GetLastPiece;
    property PiecesCount: Integer read GetPiecesCount;
    property PercentComplete: Double read GetPercentComplete;
  end;

  IPiecePicker = interface
  ['{B3CB60AD-00AC-4479-AE3A-5A6C7C76FC70}']
    function GetNextPicker: IPiecePicker;
    function GetFetchSize: Integer;

    property NextPicker: IPiecePicker read GetNextPicker;
    property FetchSize: Integer read GetFetchSize;
    function Fetch(APeerHave: TBitField; APeersHave: TBitSum;
      AWant: TBitField): TArray<Integer>;
  end;

  IRequestFirstPicker = interface(IPiecePicker)
  ['{01A53CC5-652B-49A2-A680-63B180319B64}']
    function Push(AIndex: Integer): Boolean;
  end;

  IMagnetLink = interface
  ['{EF001EFC-18CD-4884-91BE-250ABB276DA8}']
    function GetInfoHash: TUniString;
    function GetDisplayName: string;
    function GetTrackers: TEnumerable<string>;
    function GetTrackersCount: Integer;

    property InfoHash: TUniString read GetInfoHash;
    property DisplayName: string read GetDisplayName;
    property Trackers: TEnumerable<string> read GetTrackers;
    property TrackersCount: Integer read GetTrackersCount;
  end;

  ISeeding = interface(IBusy) { раздача, она же и закачка }
  ['{A428EA0C-EF82-4A67-9F74-DF22EC858D20}']
    function GetLastRequest: TDateTime;
    function GetPeers: TEnumerable<IPeer>;
    function GetPeersCount: Integer;
    function GetTrackers: TEnumerable<ITracker>;
    function GetTrackersCount: Integer;
    function GetInfoHash: TUniString;
    function GetBitfield: TBitField;
    function GetWant: TBitField;
    function GetPeersHave: TBitSum;
    function GetItems: TEnumerable<ISeedingItem>;
    function GetItemsCount: Integer;
    function GetMetafile: IMetaFile;
    function GetFileSystem: IFileSystem;
    function GetState: TSeedingStates;
    function GetOverageCount: UInt64;
    function GetHashErrorCount: Integer;
    function GetPercentComplete: Double;
    function GetCompeteSize: UInt64;
    function GetTotalSize: UInt64;
    function GetCounter: ICounter;
    function GetDownloadPath: string;
    function GetOnMetadataLoaded: TProc<ISeeding, IMetaFile>;
    procedure SetOnMetadataLoaded(const Value: TProc<ISeeding, IMetaFile>);
    function GetOnUpdate: TProc<ISeeding>;
    procedure SetOnUpdate(Value: TProc<ISeeding>);
    function GetOnDelete: TProc<ISeeding>;
    procedure SetOnDelete(Value: TProc<ISeeding>);
    function GetOnUpdateCounter: TProc<ISeeding, UInt64, UInt64>;
    procedure SetOnUpdateCounter(Value: TProc<ISeeding, UInt64, UInt64>);

    procedure AddPeer(const AHost: string; APort: TIdPort;
      AIPVer: TIdIPVersion = Id_IPv4); overload;
    procedure AddPeer(APeer: IPeer); overload;
    procedure AddTracker(ATracker: ITracker);
    procedure RemovePeer(APeer: IPeer);

    procedure Touch;
    procedure Start;
    procedure Pause;
    procedure Stop;
    procedure Delete(ADeleteFiles: Boolean = False);

    { запросить загрузку в перую очередь }
    function Require(AItem: ISeedingItem; AOffset, ALength: Int64): Boolean;

    property LastRequest: TDateTime read GetLastRequest;
    property Peers: TEnumerable<IPeer> read GetPeers;
    property PeersCount: Integer read GetPeersCount;
    property Trackers: TEnumerable<ITracker> read GetTrackers;
    property TrackersCount: Integer read GetTrackersCount;
    property InfoHash: TUniString read GetInfoHash;
    property Bitfield: TBitField read GetBitfield; // загружено
    property Want: TBitField read GetWant; // необходимо
    property PeersHave: TBitSum read GetPeersHave; // всего доступно
    property Items: TEnumerable<ISeedingItem> read GetItems;
    property ItemsCount: Integer read GetItemsCount;
    property Metafile: IMetaFile read GetMetafile;
    property FileSystem: IFileSystem read GetFileSystem;
    property State: TSeedingStates read GetState;
    property OverageCount: UInt64 read GetOverageCount;
    property HashErrorCount: Integer read GetHashErrorCount;
    property PercentComplete: Double read GetPercentComplete;
    property CompeteSize: UInt64 read GetCompeteSize;
    property TotalSize: UInt64 read GetTotalSize;
    property DownloadPath: string read GetDownloadPath;
    property Counter: ICounter read GetCounter;

    property OnMetadataLoaded: TProc<ISeeding, IMetaFile> read GetOnMetadataLoaded write SetOnMetadataLoaded;
    property OnUpdate: TProc<ISeeding> read GetOnUpdate write SetOnUpdate;
    property OnDelete: TProc<ISeeding> read GetOnDelete write SetOnDelete;
    property OnUpdateCounter: TProc<ISeeding, UInt64, UInt64> read GetOnUpdateCounter write SetOnUpdateCounter;
  end;

  IBittorrent = interface
  ['{5F4DF5D0-6B21-4C16-8EB9-7B250AEA65CC}']
    function GetSeedings: TDictionary<TUniString, ISeeding>;
    function GetBlackListTime: Integer;
    procedure SetBlackListTime(const Value: Integer);
    function GetCounter: ICounter;
    function GetOnActivateSeeding: TProc<IPeer, TUniString>;
    procedure SetOnActivateSeeding(const Value: TProc<IPeer, TUniString>);

    procedure Start; { запуск основного цикла }
    procedure Stop;

    procedure AddPeer(const AInfoHash: TUniString; const AHost: string;
      APort: TIdPort; AIPVer: TIdIPVersion = Id_IPv4);

    function AddTorrent(AMagnetLink: IMagnetLink;
      const ADownloadPath: string): ISeeding; overload;
    function AddTorrent(AMetaFile: IMetaFile;
      const ADownloadPath: string): ISeeding; overload;
    function AddTorrent(AMetaFile: IMetaFile;
      const ADownloadPath: string; const ABitField: TUniString;
      AStates: TSeedingStates): ISeeding; overload;

    function ContainsUnit(const AInfoHash: TUniString): Boolean;

    function StartUnit(const AInfoHash: TUniString): Boolean;
    function PauseUnit(const AInfoHash: TUniString): Boolean;
    function StopUnit(const AInfoHash: TUniString): Boolean;
    function DeleteUnit(const AInfoHash: TUniString; ADeleteFiles: Boolean = False): Boolean;

    property Seedings: TDictionary<TUniString, ISeeding> read GetSeedings;
    property BlackListTime: Integer read GetBlackListTime write SetBlackListTime;

    property Counter: ICounter read GetCounter;

    property OnActivateSeeding: TProc<IPeer, TUniString> read GetOnActivateSeeding write SetOnActivateSeeding;
  end;

  TBittorrent = class(TInterfacedObject, IBittorrent)
  public
    const
      SharBlockCount  = 8;
      SharBlockLength = $4000;
      SharPieceLength = SharBlockLength * SharBlockCount; { 128 Kb = 8 * 16 Kb}
  private
    FThreads: TThreadPool;
    FClientID: TUniString;
    FSeedings: TDictionary<TUniString, ISeeding>;
    FTerminated: Boolean;
    FLock: TObject;
    FListener: IServer;
    FListenPort: TIdPort;
    FDHTEngine: IDHTEngine;
    FDHTReady: Boolean;
    FBlackListTime: Integer;
    FBlackListCounter: Integer;
    FBlackList: TDictionary<string, TDateTime>;
    FOnActivateSeeding: TProc<IPeer, TUniString>;
    FCounter: ICounter;

    function GetBlackListTime: Integer; inline;
    procedure SetBlackListTime(const Value: Integer); inline;
    function GetSeedings: TDictionary<TUniString, ISeeding>; inline;
    function GetCounter: ICounter; inline;
    function GetOnActivateSeeding: TProc<IPeer, TUniString>; inline;
    procedure SetOnActivateSeeding(const Value: TProc<IPeer, TUniString>); inline;

    procedure OnPeerConnect(AConnection: IConnection);
    procedure OnDHTReady(AEngine: IDHTEngine);
    function Blacklisted(AHost: string): Boolean; inline;
    procedure AddToBlackList(AHost: string); inline;
    procedure OnSeedingUpdateCounter(ASeeding: ISeeding; ADown, AUpl: UInt64);
    procedure OnSeedingDelete(ASeeding: ISeeding);

    procedure Lock; inline;
    procedure Unlock; inline;

    function SyncSeedings: Boolean;
    function SyncDHT: Boolean;

    procedure Start;
    procedure Stop; inline;

    procedure AddPeer(const AInfoHash: TUniString; const AHost: string;
      APort: TIdPort; AIPVer: TIdIPVersion = Id_IPv4);

    procedure RegisterSeeding(ASeeding: ISeeding);

    procedure BindSeedingDHT(ASeeding: ISeeding); inline;

    function AddTorrent(AMagnetLink: IMagnetLink;
      const ADownloadPath: string): ISeeding; overload; inline;
    function AddTorrent(AMetaFile: IMetaFile;
      const ADownloadPath: string): ISeeding; overload; inline;
    function AddTorrent(AMetaFile: IMetaFile;
      const ADownloadPath: string; const ABitField: TUniString;
      AStates: TSeedingStates): ISeeding; overload; inline;

    function ContainsUnit(const AInfoHash: TUniString): Boolean; inline;

    function StartUnit(const AInfoHash: TUniString): Boolean;
    function PauseUnit(const AInfoHash: TUniString): Boolean;
    function StopUnit(const AInfoHash: TUniString): Boolean;
    function DeleteUnit(const AInfoHash: TUniString; ADeleteFiles: Boolean = False): Boolean;
  public
    constructor Create(const AClientID: TUniString; AListenPort, ADHTPort: TIdPort);
    destructor Destroy; override;
  end;

  EBittorrentException = class(Exception);

  EPeerException = class(EBittorrentException);
  EPeerConnectionTimeout = class(EPeerException);
  EPeerInvalidPeer = class(EPeerException);
  EUnknownMessage = class(EPeerException);

  ESeedingException = class(EBittorrentException);
  EPeerAlreadyConnected = class(ESeedingException);

  EMetafileException = class(EBittorrentException);

  ETrackerException = class(EBittorrentException);
  ETrackerFailure = class(ETrackerException);

  EServerException = class(EBittorrentException);
  EPeerSelfConnect = class(EServerException);
  EInvalidPeer = class(EServerException);

  EProtocolWrongPiece = class(EBittorrentException);

  EFileSystemException = class(EBittorrentException);
  EFileSystemReadException = class(EFileSystemException);
  EFileSystemWriteException = class(EFileSystemException);
  EFileSystemCheckException = class(EFileSystemException);

implementation

uses
  Bittorrent.Server, Bittorrent.Seeding, Bittorrent.MetaFile, Bittorrent.Messages,
  Bittorrent.Peer, Bittorrent.Connection, Bittorrent.Counter, Bittorrent.MagnetLink,
  Bittorrent.Tracker.DHT,
  DHT.Engine;

{ TMessageIDHelper }

function TMessageIDHelper.GetAsByte: Byte;
begin
  Result := MessageIDCode[Self];
end;

class function TMessageIDHelper.Parse(AValue: Byte): TMessageID;
begin
  Result.AsByte := AValue;
end;

procedure TMessageIDHelper.SetAsByte(const Value: Byte);
var
  id: TMessageID;
begin
  for id := Low(TMessageID) to High(TMessageID) do
    if MessageIDCode[id] = Value then
    begin
      Self := id;
      Exit;
    end;

  raise Exception.Create('Invalid value');
end;

{ TMetadataMessageTypeHelper }

function TMetadataMessageTypeHelper.GetAsByte: Byte;
begin
  Result := MetadataMessageTypeByte[Self];
end;

{ TExtensionItem }

constructor TExtensionItem.Create(const AName: string; AMsgID: Byte);
begin
  FName := AName;
  FMSgID := AMsgID;
end;

{ TBittorrent }

function TBittorrent.AddTorrent(AMagnetLink: IMagnetLink;
  const ADownloadPath: string): ISeeding;
begin
  Lock;
  try
    if not FSeedings.TryGetValue(AMagnetLink.InfoHash, Result) then
    begin
      Result := TSeeding.Create(ADownloadPath, FThreads, FClientID,
        AMagnetLink.InfoHash, FListenPort);

      RegisterSeeding(Result);
    end;
  finally
    Unlock;
  end;
end;

procedure TBittorrent.AddPeer(const AInfoHash: TUniString; const AHost: string;
  APort: TIdPort; AIPVer: TIdIPVersion);
begin
  Assert(APort <> 0);

  Lock;
  try
    if FSeedings.ContainsKey(AInfoHash) then
    with FSeedings[AInfoHash] do
    begin
      AddPeer(AHost, APort, AIPVer);
      Touch;
    end;
  finally
    Unlock;
  end;
end;

procedure TBittorrent.RegisterSeeding(ASeeding: ISeeding);
begin
  Lock;
  try
    ASeeding.OnUpdateCounter := OnSeedingUpdateCounter;
    ASeeding.OnDelete := OnSeedingDelete;

    if FDHTReady then
      BindSeedingDHT(ASeeding);

    FSeedings.Add(ASeeding.InfoHash, ASeeding);
  finally
    Unlock;
  end;
end;

procedure TBittorrent.AddToBlackList(AHost: string);
begin
  Lock;
  try
    FBlackList.AddOrSetValue(AHost, Now);
  finally
    Unlock;
  end;
end;

function TBittorrent.AddTorrent(AMetaFile: IMetaFile;
  const ADownloadPath: string): ISeeding;
begin
  Result := AddTorrent(AMetaFile, ADownloadPath, '', [ssHaveMetadata, ssDownloading]);
end;

function TBittorrent.AddTorrent(AMetaFile: IMetaFile; const ADownloadPath: string;
  const ABitField: TUniString; AStates: TSeedingStates): ISeeding;
begin
  Lock;
  try
    if not FSeedings.TryGetValue(AMetaFile.InfoHash, Result) then
    begin
      Result := TSeeding.Create(ADownloadPath, FThreads, FClientID, AMetaFile,
        TBitField.FromUniString(ABitField), AStates, FListenPort);

      RegisterSeeding(Result);
    end;
  finally
    Unlock;
  end;
end;

procedure TBittorrent.BindSeedingDHT(ASeeding: ISeeding);
begin
  ASeeding.AddTracker(TDHTTracker.Create(FThreads,
    FDHTEngine.Announce(ASeeding.InfoHash, FListenPort),
    FDHTEngine.GetPeers(ASeeding.InfoHash))
  );
end;

function TBittorrent.Blacklisted(AHost: string): Boolean;
begin
  Lock;
  try
    Result := AHost.IsEmpty or (AHost = '127.0.0.1') or (AHost = '::1') or
      FBlackList.ContainsKey(AHost);
  finally
    Unlock;
  end;
end;

function TBittorrent.ContainsUnit(const AInfoHash: TUniString): Boolean;
begin
  Lock;
  try
    Result := FSeedings.ContainsKey(AInfoHash);
  finally
    Unlock;
  end;
end;

constructor TBittorrent.Create(const AClientID: TUniString; AListenPort,
  ADHTPort: TIdPort);
begin
  Randomize;

  FClientID.Assign(AClientID);

  FThreads    := TThreadPool.Create;

  FSeedings   := System.Generics.Collections.TDictionary<TUniString, ISeeding>.Create(
    TUniStringEqualityComparer.Create as IEqualityComparer<TUniString>
  );

  FLock       := TObject.Create;

  FTerminated := False;

  FBlackListCounter := 1000;
  FBlackListTime := DefaultBlackListTime;
  FBlackList  := TDictionary<string, TDateTime>.Create;

  FCounter    := TCounter.Create;
  { слушалка }
  FListenPort := AListenPort;

  FListener   := TServer.Create;
  FListener.ListenPort  := AListenPort;
  FListener.OnConnect   := OnPeerConnect;

  FDHTEngine  := TDHTEngine.Create(AClientID, ADHTPort);
  FDHTEngine.OnBootstrapComplete := OnDHTReady;
  {$IFDEF DEBUG}
  FDHTEngine.AddBootstrapNode('router.bittorrent.com', 6881);
  {$ENDIF}

  FDHTReady   := False;
end;

function TBittorrent.DeleteUnit(const AInfoHash: TUniString;
  ADeleteFiles: Boolean = False): Boolean;
begin
  Lock;
  try
    Result := FSeedings.ContainsKey(AInfoHash);

    if Result then
    begin
      // удаляем раздачу
      FSeedings[AInfoHash].Delete(ADeleteFiles);
      FSeedings.Remove(AInfoHash);
    end;
  finally
    Unlock;
  end;
end;

destructor TBittorrent.Destroy;
begin
  Stop;
  Sleep(1000); // для завершения активных тредов
  FBlackList.Free;
  FSeedings.Free;
  FLock.Free;
  FThreads.Free;
  inherited;
end;

function TBittorrent.GetBlackListTime: Integer;
begin
  Result := FBlackListTime;
end;

function TBittorrent.GetCounter: ICounter;
begin
  Result := FCounter;
end;

function TBittorrent.GetOnActivateSeeding: TProc<IPeer, TUniString>;
begin
  Result := FOnActivateSeeding;
end;

function TBittorrent.GetSeedings: TDictionary<TUniString, ISeeding>;
begin
  Result := FSeedings;
end;

procedure TBittorrent.Lock;
begin
  System.TMonitor.Enter(FLock);
end;

procedure TBittorrent.OnDHTReady(AEngine: IDHTEngine);
begin
  Lock;
  try
    TPrelude.Foreach<ISeeding>(FSeedings.Values.ToArray,
      procedure (ASeeding: ISeeding)
      begin
        BindSeedingDHT(ASeeding);
      end
    );

    FDHTReady := True;
  finally
    Unlock;
  end;
end;

procedure TBittorrent.OnPeerConnect(AConnection: IConnection);
var
  peer: IPeer;
  needStart, allOK: Boolean;
begin
  TIdStack.IncUsage;
  try
    { проверяем, всё ли корректно и добавляем, если надо (иначе отключаем) }
    with AConnection do
    if Blacklisted(Host) or (GStack.LocalAddresses.IndexOf(Host) <> -1) then
    begin
      Disconnect;
      Exit;
    end;
  finally
    TIdStack.DecUsage;
  end;

  try
    {$IFDEF PUBL_UTIL}
    DebugOutput('Peer connecting ' + AConnection.Host);
    {$ENDIF}

    allOK := False;
    needStart := True;

    peer := TPeer.Create(FThreads, AConnection, FClientID) as IPeer;

    peer.OnConnect := procedure (APeer: IPeer; AMsg: IMessage)
    begin
      if APeer.ClientID = FClientID then
      begin
        needStart := False;
        raise EPeerSelfConnect.Create('Self connection');
      end;

      {$IFDEF PUBL_UTIL}
      DebugOutput('Peer ' + APeer.Host + ' connected OK');
      {$ENDIF}

      allOK := True;
    end;

    peer.OnStart := procedure (APeer: IPeer; AInfoHash: TUniString;
      AHave: TBitField)
    var
      seeding: ISeeding;
    begin
      {$IFDEF PUBL_UTIL}
      DebugOutput('Seeding_OnStart ' + AInfoHash.ToHexString);
      {$ENDIF}
      // сообщаем о внешнем подключении
      if Assigned(FOnActivateSeeding) then
        FOnActivateSeeding(APeer, AInfoHash);

      {$IFDEF PUBL_UTIL}
      DebugOutput('Seeding_OnStart try lock and add peer');
      {$ENDIF}

      Lock;
      try
        {$IFDEF PUBL_UTIL}
        try
        {$ENDIF}
          allOK := FSeedings.TryGetValue(AInfoHash, seeding);
          Assert(allOK);

          seeding.AddPeer(APeer); { добавляем новый пир }
          seeding.Touch;

        {$IFDEF PUBL_UTIL}
        except
          on E: Exception do
          begin
            DebugOutput('Seeding_OnStart error: ' + E.ToString);
            raise;
          end;
        end;
        {$ENDIF}
      finally
        needStart := False;
        Unlock;
      end;

      {$IFDEF PUBL_UTIL}
      DebugOutput('Seeding_OnStart status = ' + BoolToStr(allOK, True));
      {$ENDIF}
    end;

    { ждем от него «старт» }
    while needStart do
    begin
      { вызываем Sync, чтобы он законнектился и т.д. }
      peer.Sync;
      { ждем коннект }
      while peer.Busy do
        Sleep(10);
    end;

    if not allOK then
      raise EInvalidPeer.Create('Invalid peer');
  except
    AddToBlackList(AConnection.Host);
  end;
end;

function TBittorrent.PauseUnit(const AInfoHash: TUniString): Boolean;
begin
  Lock;
  try
    Result := FSeedings.ContainsKey(AInfoHash);

    if Result then
      FSeedings[AInfoHash].Pause;
  finally
    Unlock;
  end;
end;

procedure TBittorrent.OnSeedingDelete(ASeeding: ISeeding);
begin
  Lock;
  try
    if FSeedings.ContainsKey(ASeeding.InfoHash) then
      FSeedings.Remove(ASeeding.InfoHash);
  finally
    Unlock;
  end;
end;

procedure TBittorrent.OnSeedingUpdateCounter(ASeeding: ISeeding; ADown, AUpl: UInt64);
begin
  (FCounter as IMutableCounter).Add(ADown, AUpl);
end;

procedure TBittorrent.SetBlackListTime(const Value: Integer);
begin
  Assert(Value >= 0);
  FBlackListTime := Value;
end;

procedure TBittorrent.SetOnActivateSeeding(const Value: TProc<IPeer, TUniString>);
begin
  FOnActivateSeeding := Value;
end;

procedure TBittorrent.Start;
begin
  FListener.Active := True;

  FTerminated := False;

  FThreads.Exec(Integer(TBittorrent), SyncSeedings);
  FThreads.Exec(Integer(TDHTEngine), SyncDHT);
end;

function TBittorrent.StartUnit(const AInfoHash: TUniString): Boolean;
begin
  Lock;
  try
    Result := FSeedings.ContainsKey(AInfoHash);

    if Result then
      FSeedings[AInfoHash].Start;
  finally
    Unlock;
  end;
end;

procedure TBittorrent.Stop;
begin
  FListener.Active := False;
  FTerminated := True;
end;

function TBittorrent.StopUnit(const AInfoHash: TUniString): Boolean;
begin
  Lock;
  try
    Result := FSeedings.ContainsKey(AInfoHash);

    if Result then
      FSeedings[AInfoHash].Stop;
  finally
    Unlock;
  end;
end;

function TBittorrent.SyncDHT: Boolean;
begin
  try
    if not FDHTEngine.Busy then
      FDHTEngine.Sync;
  except
  end;

  if not FTerminated then
    FThreads.Schedule(Integer(TDHTEngine), 1, SyncDHT);

  Result := False;
end;

function TBittorrent.SyncSeedings: Boolean;
var
  key: TUniString;
  h: string;
  t: TDateTime;
begin
  Lock;
  try
    t := Now;

    { тут надо бы порядок добавления торрентов соблюсти, плюс добавить ограничение }
    for key in FSeedings.Keys do
    with FSeedings[key] do
    begin
      try
        Sync;
      except
      end;
    end;

    { сброс счётчика, если нет активных раздач }
    (FCounter as IMutableCounter).Add(0, 0);

    { чистим черный список }
    if FBlackListTime > 0 then
    begin
      if FBlackListCounter = 0 then
      begin
        for h in FBlackList.Keys do
          if MinutesBetween(t, FBlackList[h]) >= FBlackListTime then
          begin
            FBlackList.Remove(h);
            Break;
          end;

        FBlackListCounter := 100000;
      end else
        Dec(FBlackListCounter);
    end;
  except
  end;

  Unlock;

  if not FTerminated then
    FThreads.Schedule(Integer(TBittorrent), 1, SyncSeedings);

  Result := False;
end;

procedure TBittorrent.Unlock;
begin
  System.TMonitor.Exit(FLock);
end;

{ TSeedingStatesHelper }

function TSeedingStatesHelper.GetAsInteger: Integer;
var
  s: TSeedingState;
begin
  Result := 0;

  for s := Low(TSeedingState) to High(TSeedingState) do
    if s in Self then
      Result := Result or (1 shl Ord(s));
end;

class function TSeedingStatesHelper.Parse(const Value: Integer): TSeedingStates;
begin
  Result.AsInteger := Value;
end;

procedure TSeedingStatesHelper.SetAsInteger(const Value: Integer);
var
  s: TSeedingState;
  i: Integer;
begin
  for s := Low(TSeedingState) to High(TSeedingState) do
  begin
    i := 1 shl Ord(s);

    if Value and i = i then
      Include(Self, s)
    else
      Exclude(Self, s);
  end;
end;

end.
