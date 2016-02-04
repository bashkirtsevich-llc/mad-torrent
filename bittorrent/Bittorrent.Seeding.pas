unit Bittorrent.Seeding;

interface

uses
  System.SysUtils, System.Generics.Collections, System.Generics.Defaults,
  System.Math, System.DateUtils, System.Hash, System.IOUtils,
  Basic.UniString,
  Common.Prelude,
  Bittorrent, Bittorrent.Bitfield, Bittorrent.Counter,
  Common.BusyObj, Common.ThreadPool, Common.SHA1,
  IdGlobal, IdStack;

type
  { собственно раздача. одна раздача -- одна загрузка }
  TSeeding = class(TBusy, ISeeding)
  private
    const
      MinPeerRate          = -100;{ минимальный рейтинг, после которого блокируем отдачу пиру }
      MaxIdleTime          = 5*60*1000; { 5 минут }
      MaxBlocksQueueSize   = 20480;{ максимальное кол-во запрашиваемых блоков }
      { это значение необходимо рассчитывать, т.к. размер куска может быть разным (32 куска по 32 кб = 1 мегабайт) }
      MaxPeerBlocksCount   = 1;   { максимальное кол-во блоков, запрашиваемых с одного пира за раз }
      MaxPieceQueueTimeout = 60;  { секунд (тоже зависит от скорости) }
      MaxPieceRequestCount = 8;   { на сколько запросов мы можем ответить за проход }
      CacheClearInterval   = 5;   { секунд }
      DefaultBlackListTime = 10;  { минут }
    type
      IPieceQueue = interface
      ['{2A153346-D39E-48CE-9D84-7FFD5186C83A}']
        procedure CancelRequests(APeer: IPeer);
        procedure CancelRequest(APeer: IPeer; APieceIndex, AOffset: Integer);
      end;

      IDownloadPieceQueue = interface(IPieceQueue)
      ['{21E227E7-EDCF-4CB0-9F4E-4E2861E39E85}']
        function CanEnqueue(APeer: IPeer = nil): Boolean; overload;
        function CanEnqueue(APiece, AOffset, ASize: Integer): Boolean; overload;
        function CanEnqueue(APiece, AOffset, ASize: Integer; APeer: IPeer): Boolean; overload;
        procedure Enqueue(APiece, AOffset, ASize: Integer; APeer: IPeer); { поставить в очередь }
        procedure Dequeue(APiece, AOffset, ASize: Integer); overload;
        procedure Dequeue(APiece: Integer); overload;
        procedure Timeout; { выбросить всё ненужное по таймауту }
      end;

      IUploadPieceQueue = interface(IPieceQueue)
      ['{21E227E7-EDCF-4CB0-9F4E-4E2861E39E85}']
        function GetIsEmpty: Boolean;

        function CanEnqueue(APiece, AOffset, ASize: Integer; APeer: IPeer): Boolean;
        procedure Enqueue(APiece, AOffset, ASize: Integer; APeer: IPeer); { поставить в очередь }
        function Dequeue(APeer: IPeer;
          ADequeueProc: TProc<IPeer, {piece}Integer, {offset}Integer, {size}Integer>): Boolean;

        property IsEmpty: Boolean read GetIsEmpty;
      end;

      TPieceQueue = class abstract(TInterfacedObject, IPieceQueue)
      protected
        procedure CancelRequests(APeer: IPeer); virtual; abstract;
        procedure CancelRequest(APeer: IPeer; APieceIndex, AOffset: Integer); virtual; abstract;
      end;

      // убрать здесь дублирование кода
      TDownloadPieceQueue = class(TPieceQueue, IDownloadPieceQueue)
      private
        type
          TDownloadPieceQueueItem = record
            Peer: IPeer;
            TimeStamp: TDateTime;

            constructor Create(APeer: IPeer);
          end;

          TDownloadKeyItem = (dkiPiece, dkiOffset, dkiSize);
          TDownloadKey = array[TDownloadKeyItem] of Integer;
      private
        FItems: TDictionary<TDownloadKey, TDownloadPieceQueueItem>;
        FOnTimeout: TProc<Integer, Integer, IPeer>;
        FOnCancel: TProc<Integer, Integer, IPeer>;

        function CreateKey(APiece, AOffset, ASize: Integer): TDownloadKey; inline;

        function CanEnqueue(APeer: IPeer = nil): Boolean; overload;
        function CanEnqueue(APiece, AOffset, ASize: Integer): Boolean; overload;
        function CanEnqueue(APiece, AOffset, ASize: Integer; APeer: IPeer): Boolean; overload; inline;
        procedure Enqueue(APiece, AOffset, ASize: Integer; APeer: IPeer); inline;
        procedure Dequeue(APiece, AOffset, ASize: Integer); overload; inline;
        procedure Dequeue(APiece: Integer); overload;
        procedure Timeout;
      protected
        procedure CancelRequests(APeer: IPeer); override;
        procedure CancelRequest(APeer: IPeer; APieceIndex, AOffset: Integer); override;
      public
        constructor Create(APieceCount: Integer; AOnTimeout,
          AOnCancel: TProc<Integer, Integer, IPeer>);
        destructor Destroy; override;
      end;

      TUploadPieceQueue = class(TPieceQueue, IUploadPieceQueue)
      private
        type
          TUploadPieceQueueItem = record { наверное тоже нужен таймаут, т.к. пир может резко отвалиться }
            Peer: IPeer;
            Piece,
            Offset,
            Size: Integer;

            constructor Create(APeer: IPeer; APiece, AOffset, ASize: Integer);
          end;
      private
        FList: TList<TUploadPieceQueueItem>;
        function GetIsEmpty: Boolean; inline;
        function CanEnqueue(APiece, AOffset, ASize: Integer; APeer: IPeer): Boolean;
        procedure Enqueue(APiece, AOffset, ASize: Integer; APeer: IPeer); inline;
        function Dequeue(APeer: IPeer; ADequeueProc: TProc<IPeer, Integer, Integer, Integer>): Boolean;
      protected
        procedure CancelRequests(APeer: IPeer); override;
        procedure CancelRequest(APeer: IPeer; APieceIndex, AOffset: Integer); override;
      public
        constructor Create;
        destructor Destroy; override;
      end;
  protected
    FLastRequest: TDateTime;
    FLastCacheClear: TDateTime;
    FBlackList: TDictionary<string, TDateTime>;
    FBlackListTime: Integer;
    FLock: TObject;
    FMetafile: IMetaFile;
    FMetafileMap: TDictionary<Integer, TUniString>;
    FMetadataSize: Integer;
    FInfoHash: TUniString;
    FClientID: TUniString;
    FFileSystem: IFileSystem;
    FDownloadPath: string;
    FCounter: ICounter;
    FEndGame: Boolean;
    FEndGameList: TDictionary<IPeer, TArray<Integer>>;
    FDownloadQueue: IDownloadPieceQueue; // список кусков, которые мы запросили (чтобы не запрашивать повторно)
    FUploadQueue: IUploadPieceQueue; // список кусков, которые с нас запросили
    FPiecePicker: IRequestFirstPicker;
    FThreadPool: TThreadPool;
    FPeers: TList<IPeer>; // их бы сортировать по скорости и количеству отдаваемго
    FListenPort: TIdPort;
    FTrackers: TList<ITracker>;
    FLastTrackersSync: TDateTime;
    FPiecesBuf: TDictionary<Integer, IPiece>;
    FStates: TSeedingStates;
    FBitField: TBitField; // маска загрузки
    FPeersHave: TBitSum; // доступно на пирах
    FItems: TList<ISeedingItem>; // для управления закачкой
    FOnMetadataLoaded: TProc<ISeeding, IMetaFile>;
    FOnUpdate: TProc<ISeeding>;
    FOnDelete: TProc<ISeeding>;
    FOnUpdateCounter: TProc<ISeeding, UInt64, UInt64>;
    FOverageCount: UInt64;
    FHashErrorCount: Integer;
  private
    function GetLastRequest: TDateTime; inline;
    function GetPeers: TEnumerable<IPeer>; inline;
    function GetPeersCount: Integer; inline;
    function GetTrackers: TEnumerable<ITracker>; inline;
    function GetTrackersCount: Integer; inline;
    function GetInfoHash: TUniString; inline;
    function GetBitfield: TBitField; inline;
    function GetWant: TBitField; inline;
    function GetPeersHave: TBitSum; inline;
    function GetItems: TEnumerable<ISeedingItem>; inline;
    function GetItemsCount: Integer; inline;
    function GetMetafile: IMetaFile; inline;
    function GetFileSystem: IFileSystem; inline;
    function GetState: TSeedingStates; inline;
    function GetOverageCount: UInt64; inline;
    function GetHashErrorCount: Integer; inline;
    function GetPercentComplete: Double; inline;
    function GetCompeteSize: UInt64;
    function GetTotalSize: UInt64; inline;
    function GetCorruptedSize: UInt64; inline;
    function GetCounter: ICounter; inline;
    function GetDownloadPath: string; inline;
    function GetOnMetadataLoaded: TProc<ISeeding, IMetaFile>; inline;
    procedure SetOnMetadataLoaded(const Value: TProc<ISeeding, IMetaFile>); inline;
    function GetOnUpdate: TProc<ISeeding>; inline;
    procedure SetOnUpdate(Value: TProc<ISeeding>); inline;
    function GetOnDelete: TProc<ISeeding>; inline;
    procedure SetOnDelete(Value: TProc<ISeeding>); inline;
    function GetOnUpdateCounter: TProc<ISeeding, UInt64, UInt64>; inline;
    procedure SetOnUpdateCounter(Value: TProc<ISeeding, UInt64, UInt64>); inline;

    procedure OnGetBitField(ACallback: TProc<TBitField>);
    function OnGetState(AItem: ISeedingItem): TSeedingStates;
    function OnRequire(AItem: ISeedingItem; AOffset, ALength: Int64): Boolean;

    procedure Update; inline;
    procedure UpdateCounter(APeer: IPeer; ADown, AUpl: UInt64); inline;

    procedure AddPeer(const AHost: string; APort: TIdPort;
      AIPVer: TIdIPVersion = Id_IPv4); overload;
    procedure AddPeer(APeer: IPeer); overload; inline;
    procedure AddTracker(ATracker: ITracker);
    procedure RemovePeer(APeer: IPeer); inline;

    procedure CancelReuests(APiece, AOffset: Integer; APeer: IPeer);

    procedure Touch; inline;
    procedure CancelDownloading;
    // управлять состоянием можно только у ЗАГРУЖАЕМОЙ раздачи
    procedure Start; inline;
    procedure Pause; inline;
    procedure Resume; inline;
    procedure Stop; inline;
    procedure Delete(ADeleteFiles: Boolean = False);

    procedure MarkAsError; inline; // раздача с ошибкой

    function Require(AItem: ISeedingItem; AOffset, ALength: Int64): Boolean;
    procedure FetchNext(APeer: IPeer);

    { обработчики событий пира }
    procedure OnPeerConnect(APeer: IPeer; AMessage: IMessage);
    procedure OnPeerDisconnect(APeer: IPeer);
    procedure OnPeerException(APeer: IPeer; AException: Exception);
    procedure OnPeerBitfield(APeer: IPeer; AInfoHash: TUniString;
      ABitField: TBitField);
    procedure OnPeerHave(APeer: IPeer; APieceIndex: Integer);

    procedure OnPeerRequest(APeer: IPeer; APieceIndex, AOffset, ASize: Integer);
    procedure OnPeerCancel(APeer: IPeer; APieceIndex, AOffset: Integer);
    procedure OnPeerPiece(APeer: IPeer; APieceIndex, AOffset: Integer;
      AData: TUniString);
    procedure OnPeerChoke(APeer: IPeer);
    procedure OnPeerInterest(APeer: IPeer);
    procedure OnPeerExtendedMessage(APeer: IPeer; AMessage: IExtension);

    procedure Lock; inline;
    procedure Unlock; inline;

    procedure InitMetadata(AMetafile: IMetaFile);

    procedure CheckBlackList;

    procedure DisconnectAllPeers;
    function ApplyPeerCallbacks(APeer: IPeer): IPeer;
    procedure RemovePeerCallbacks(APeer: IPeer); inline;
  protected
    procedure DoSync; override;
  public
    constructor Create(const ADownloadPath: string; AThreadPoolEx: TThreadPool;
      const AClientID, AInfoHash: TUniString; AListenPort: TIdPort;
      ABlackListTime: Integer = DefaultBlackListTime); reintroduce; overload;

    constructor Create(const ADownloadPath: string; AThreadPoolEx: TThreadPool;
      const AClientID: TUniString; AMetafile: IMetaFile;
      const ABitField: TBitField; AStates: TSeedingStates;
      AListenPort: TIdPort; ABlackListTime: Integer = DefaultBlackListTime); reintroduce; overload;
    destructor Destroy; override;
  end;

implementation

uses
  Bittorrent.Peer, Bittorrent.Messages, Bittorrent.Piece, Bittorrent.MetaFile,
  Bittorrent.PiecePicker, Bittorrent.FileSystem, Bittorrent.SeedingItem,
  Bittorrent.Tracker, Bittorrent.Extensions;

{ TSeeding }

procedure TSeeding.AddPeer(const AHost: string; APort: TIdPort; AIPVer: TIdIPVersion);
var
  peer: IPeer;
  ip, addr: string;
begin
  Lock;
  try
    { не рекомендуется цепляться более чем к 50-и пирам }
    if TPrelude.Fold<IPeer, Integer>(FPeers.ToArray, 0,
      function (X: Integer; Y: IPeer): Integer
      begin
        Result := X + System.Math.IfThen(Y.ConnectionType = ctOutgoing, 1);
      end) < 50 then
    begin
      TIdStack.IncUsage;
      try
        ip := GStack.ResolveHost(AHost);
      finally
        TIdStack.DecUsage;
      end;

      CheckBlackList;

      if (ssDownloading in FStates) or not (ssHaveMetadata in FStates) and
        not FBlackList.ContainsKey(ip) then
      begin
        addr := Format('%s:%d', [ip, APort]);

        for peer in FPeers do
          if peer.Host + ':' + peer.Port.ToString = addr then
            Exit;

        FPeers.Add(ApplyPeerCallbacks(TPeer.Create(FThreadPool, ip, APort,
          FInfoHash, FClientID, AIPVer)));

        {$IFDEF DEBUG}
        DebugOutput('add peer ' + addr);
        {$ENDIF}

        Touch; { пинаем раздачу, пусть пробует качать }
      end;
    end;
  finally
    Unlock;
  end;
end;

procedure TSeeding.AddPeer(APeer: IPeer);
begin
  Lock;
  try
    FPeers.Add(ApplyPeerCallbacks(APeer));

    APeer.SendBitfield(FBitField);
  finally
    Unlock;
  end;
end;

procedure TSeeding.AddTracker(ATracker: ITracker);
begin
  Lock;
  try
    if not FTrackers.Contains(ATracker) then
      FTrackers.Add(ATracker);

    ATracker.OnResponsePeerInfo := procedure (AHost: string; APort: TIdPort)
    begin
      AddPeer(AHost, APort);
    end;
  finally
    Unlock;
  end;
end;

function TSeeding.ApplyPeerCallbacks(APeer: IPeer): IPeer;
begin
  Result := APeer;

  Result.OnConnect          := OnPeerConnect;
  Result.OnDisonnect        := OnPeerDisconnect;
  Result.OnException        := OnPeerException;
  Result.OnBitfield         := OnPeerBitfield;
  Result.OnRequest          := OnPeerRequest;
  Result.OnHave             := OnPeerHave;
  Result.OnCancel           := OnPeerCancel;
  Result.OnPiece            := OnPeerPiece;
  Result.OnChoke            := OnPeerChoke;
  Result.OnInterest         := OnPeerInterest;
  Result.OnExtendedMessage  := OnPeerExtendedMessage;
  Result.OnUpdateCounter    := UpdateCounter;
end;

procedure TSeeding.CancelDownloading;
var
  p: IPeer;
begin
  Lock;
  try
    for p in FPeers do
      FDownloadQueue.CancelRequests(p);
  finally
    Unlock;
  end;
end;

constructor TSeeding.Create(const ADownloadPath: string;
  AThreadPoolEx: TThreadPool; const AClientID: TUniString; AMetafile: IMetaFile;
  const ABitField: TBitField; AStates: TSeedingStates; AListenPort: TIdPort;
  ABlackListTime: Integer);
begin
  Assert(Assigned(AMetafile));

  Create(ADownloadPath, AThreadPoolEx, AClientID, AMetafile.InfoHash, AListenPort,
    ABlackListTime);

  { init metadata }
  InitMetadata(AMetafile);

  { объединяем множества }
  FStates := FStates + AStates;

  { установка битфилдов и всего прочего }
  FBitField.CopyFrom(ABitField);

  if FBitField.AllFalse then
    FBitField := FFileSystem.CheckFiles;

  if FBitField.AllTrue then
    FStates := FStates + [ssCompleted] - [ssActive, ssDownloading]
end;

constructor TSeeding.Create(const ADownloadPath: string;
  AThreadPoolEx: TThreadPool; const AClientID, AInfoHash: TUniString;
  AListenPort: TIdPort; ABlackListTime: Integer);
begin
  inherited Create;

  FHashErrorCount := 0;
  FOverageCount   := 0;
  FThreadPool     := AThreadPoolEx;
  FClientID       := AClientID;
  FLastCacheClear := Now;
  FInfoHash.Assign(AInfoHash);
  FDownloadPath   := ADownloadPath;
  FListenPort     := AListenPort;
  FStates         := [ssDownloading, ssActive];
  FMetafileMap    := TDictionary<Integer, TUniString>.Create;
  FMetadataSize   := 0;

  FBlackList      := TDictionary<string, TDateTime>.Create;
  FBlackListTime  := ABlackListTime;

  FLastTrackersSync := MinDateTime;
  FEndGame        := False;
  FEndGameList    := TDictionary<IPeer, TArray<Integer>>.Create;
  FCounter        := TCounter.Create;
  FLock           := TObject.Create;
  FPeers          := TList<IPeer>.Create;
  FTrackers       := TList<ITracker>.Create;
  FItems          := TList<ISeedingItem>.Create;
  FPiecesBuf      := TDictionary<Integer, IPiece>.Create;

  FBitField       := TBitField.Create(0);
  FPeersHave      := TBitSum.Create(0);

  FDownloadQueue  := TDownloadPieceQueue.Create(0, nil, nil);
  FUploadQueue    := TUploadPieceQueue.Create;
end;

procedure TSeeding.Delete(ADeleteFiles: Boolean = False);
begin
  Lock;
  try
    FStates := [];

    if ADeleteFiles then
      FFileSystem.DeleteFiles;
  finally
    Unlock;
  end;

  if Assigned(FOnDelete) then
    FOnDelete(Self);
end;

destructor TSeeding.Destroy;
begin
  FStates := [];

  DisconnectAllPeers;

  FEndGameList.Free;
  FPeers.Free;
  FTrackers.Free;
  FItems.Free;
  FPiecesBuf.Free;
  FLock.Free;
  FMetafileMap.Free;
  FBlackList.Free;
  inherited;
end;

procedure TSeeding.DisconnectAllPeers;
var
  i: Integer;
  it: IPeer;
begin
  Lock;
  try
    for i := FPeers.Count - 1 downto 0 do
    begin
      it := FPeers[i];

      if it.ConnectionConnected then
        it.Disconnect
      else
      begin
        FDownloadQueue.CancelRequests(it);
        FUploadQueue.CancelRequests(it);
      end;

      RemovePeerCallbacks(it);
    end;
  finally
    Unlock;
  end;
end;

function TSeeding.GetPeersHave: TBitSum;
begin
  Result := FPeersHave;
end;

function TSeeding.GetBitfield: TBitField;
begin
  Result := FBitField;
end;

function TSeeding.GetCompeteSize: UInt64;
var
  i: Integer;
begin
  if ssHaveMetadata in FStates then
  begin
    Lock;
    try
      Result := 0;

      // кол-во завершенных кусков * размер куска
      for i := 0 to FBitField.Len - 1 do
        if FBitField[i] then
          Inc(Result, FMetafile.PieceLength[i]);
    finally
      Unlock;
    end;
  end else
    Result := 0;
end;

function TSeeding.GetCorruptedSize: UInt64;
begin
  if ssHaveMetadata in FStates then
    Result := FHashErrorCount * FMetafile.PiecesLength
  else
    Result := 0;
end;

function TSeeding.GetTotalSize: UInt64;
begin
  if ssHaveMetadata in FStates then
    Result := FMetafile.TotalSize
  else
    Result := 0;
end;

function TSeeding.GetTrackers: TEnumerable<ITracker>;
begin
  Result := FTrackers;
end;

function TSeeding.GetTrackersCount: Integer;
begin
  Result := FTrackers.Count;
end;

function TSeeding.GetWant: TBitField;
begin
  Lock;
  try
    Result := not FBitField;
    Assert(Result.Len = FBitField.Len);
  finally
    Unlock;
  end;
end;

procedure TSeeding.InitMetadata(AMetafile: IMetaFile);
var
  it: IFileItem;
  {s: string;}
begin
  Assert(Assigned(AMetafile));

  Lock;
  try
    FMetafile := AMetafile;
    FMetadataSize := AMetafile.Metadata.Len;

    for it in AMetafile.Files do
      FItems.Add(TSeedingItem.Create(FDownloadPath, it, AMetafile.PiecesLength,
        OnGetBitField, OnGetState, OnRequire));

    FPiecePicker    := TRequestFirstPicker.Create(
        TPriorityPicker.Create(
          TRarestFirstPicker.Create(
            TRandomPicker.Create(
              TLinearPicker.Create(nil, 1),
            10),
          20),
        30, FItems),
      1
    );

    FFileSystem     := TFileSystem.Create(AMetafile, FDownloadPath);

    { проверяем папку назначения }
    if TDirectory.Exists(FDownloadPath) and TDirectory.IsEmpty(FDownloadPath) then
      FBitField     := TBitField.Create(AMetafile.PiecesCount)
    else
      FBitField     := FFileSystem.CheckFiles;

    FPeersHave.Len  := AMetafile.PiecesCount;

    FDownloadQueue  := TDownloadPieceQueue.Create(AMetafile.PiecesCount,
      CancelReuests, CancelReuests);

    FStates         := [ssHaveMetadata];

    if FBitField.AllTrue then
      Include(FStates, ssCompleted);

    FLastRequest    := Now;
  finally
    Unlock;
  end;
end;

function TSeeding.GetCounter: ICounter;
begin
  Result := FCounter;
end;

function TSeeding.GetDownloadPath: string;
begin
  Result := FDownloadPath;
end;

function TSeeding.GetFileSystem: IFileSystem;
begin
  Result := FFileSystem;
end;

function TSeeding.GetHashErrorCount: Integer;
begin
  Result := FHashErrorCount;
end;

function TSeeding.GetInfoHash: TUniString;
begin
  Result := FInfoHash;
end;

function TSeeding.GetItems: TEnumerable<ISeedingItem>;
begin
  Result := FItems;
end;

function TSeeding.GetItemsCount: Integer;
begin
  Result := FItems.Count;
end;

function TSeeding.GetLastRequest: TDateTime;
begin
  Result := FLastRequest;
end;

function TSeeding.GetMetafile: IMetaFile;
begin
  Result := FMetafile;
end;

function TSeeding.GetOnDelete: TProc<ISeeding>;
begin
  Result := FOnDelete;
end;

function TSeeding.GetOnMetadataLoaded: TProc<ISeeding, IMetaFile>;
begin
  Result := FOnMetadataLoaded;
end;

function TSeeding.GetOnUpdate: TProc<ISeeding>;
begin
  Result := FOnUpdate;
end;

function TSeeding.GetOnUpdateCounter: TProc<ISeeding, UInt64, UInt64>;
begin
  Result := FOnUpdateCounter;
end;

function TSeeding.GetOverageCount: UInt64;
begin
  Result := FOverageCount;
end;

function TSeeding.GetPeers: TEnumerable<IPeer>;
begin
  Result := FPeers;
end;

function TSeeding.GetPeersCount: Integer;
begin
  Result := FPeers.Count;
end;

function TSeeding.GetPercentComplete: Double;
begin
  Lock;
  try
    with FBitField do
      Result := CheckedCount / Len * 100;
  finally
    Unlock;
  end;
end;

function TSeeding.GetState: TSeedingStates;
begin
  Result := FStates;
end;

procedure TSeeding.Lock;
begin
  System.TMonitor.Enter(FLock);
end;

procedure TSeeding.MarkAsError;
begin
  FStates := [ssError];
  DisconnectAllPeers;
end;

procedure TSeeding.OnGetBitField(ACallback: TProc<TBitField>);
begin
  Lock;
  try
    ACallback(FBitField);
  finally
    Unlock;
  end;
end;

function TSeeding.OnGetState(AItem: ISeedingItem): TSeedingStates;
begin
  Result := FStates;
end;

procedure TSeeding.OnPeerCancel(APeer: IPeer; APieceIndex, AOffset: Integer);
begin
  Lock;
  try
    FUploadQueue.CancelRequest(APeer, APieceIndex, AOffset);
  finally
    Unlock;
  end;
end;

procedure TSeeding.OnPeerChoke(APeer: IPeer);
begin
  Lock;
  try
    FDownloadQueue.CancelRequests(APeer);
  finally
    Unlock;
  end;
end;

procedure TSeeding.OnPeerConnect(APeer: IPeer; AMessage: IMessage);
begin
  Lock;
  try
    Assert(Supports(APeer, IPeer));

    { шлём extension-хендшейк }
    APeer.SendExtensionMessage(TExtensionHandshake.Create('MAD-Torrent',
      FListenPort, FMetadataSize));

    APeer.SendPort(FListenPort);

    { сразу отправляем ему bitfield, если есть }
    if ssHaveMetadata in FStates then
      APeer.SendBitfield(FBitField);
  finally
    Unlock;
  end;
end;

procedure TSeeding.OnPeerDisconnect(APeer: IPeer);
begin
  Lock;
  try
    RemovePeer(APeer);
  finally
    Unlock;
  end;
end;

procedure TSeeding.OnPeerException(APeer: IPeer; AException: Exception);
begin
  Lock;
  try
    RemovePeer(APeer);

    FBlackList.AddOrSetValue(APeer.Host, Now);
  finally
    Unlock;
  end;
end;

procedure TSeeding.OnPeerExtendedMessage(APeer: IPeer; AMessage: IExtension);
var
  hs: IExtensionHandshake;
  md: IExtensionMetadata;
  i: Integer;
  tmp: TUniString;
  mf: IMetaFile;
  metadataID: Byte;
begin
  Lock;
  try
    if Supports(AMessage, IExtensionHandshake, hs) then
    begin
      { пробуем запросить метаданные, если у нас их нет }
      if (hs.MetadataSize > 0) and not(ssHaveMetadata in FStates) and
        hs.Supports.TryGetValue(TExtensionMetadata.GetClassSupportName, metadataID) then
      begin
        FMetadataSize := hs.MetadataSize;
        { request all metadata pieces }
        i := 0;

        while i * TExtensionMetadata.BlockSize < FMetadataSize do
        begin
          if not FMetafileMap.ContainsKey(i) then
            APeer.SendExtensionMessage(TExtensionMetadata.Create(mmtRequest, i));

          Inc(i);
        end;
      end;
    end else
    if Supports(AMessage, IExtensionMetadata, md) then
    begin
      { receive, store }
      case md.MessageType of
        mmtRequest:
          begin
            { they ask us }
            tmp := FMetafile.Metadata;
            { проверка правильности указания куска }
            Assert(md.Piece * TExtensionMetadata.BlockSize <= tmp.Len);

            APeer.SendExtensionMessage(
              TExtensionMetadata.Create(mmtData, md.Piece,
                tmp.Copy(md.Piece * TExtensionMetadata.BlockSize,
                  Min(TExtensionMetadata.BlockSize,
                      tmp.Len - md.Piece * TExtensionMetadata.BlockSize))
              )
            );
          end;

        mmtData:
          begin
            if not(ssHaveMetadata in FStates) then
            begin
              if not FMetafileMap.ContainsKey(md.Piece) then
                FMetafileMap.Add(md.Piece, md.Metadata);

              tmp := TPrelude.Fold<Integer, TUniString>(
                TPrelude.Sort<Integer>(FMetafileMap.Keys.ToArray,
                  TDelegatedComparer<Integer>.Create(
                    function (const Left, Right: Integer): Integer
                    begin
                      Result := Left - Right;
                    end
                  )
                ), string.Empty,
                function (X: TUniString; Y: Integer): TUniString
                begin
                  Result := X + FMetafileMap[Y];
                end
              );

              if tmp.Len = FMetadataSize then
              begin
                { check infohash }
                if SHA1(tmp) = FInfoHash then
                begin
                  { успешно загрузили метафайл }
                  mf := TMetaFile.Create(tmp);
                  InitMetadata(mf);

                  if Assigned(FOnMetadataLoaded) then
                    FOnMetadataLoaded(Self, mf);
                end else
                  FMetadataSize := 0; { метаданные загрузились с ошибкой }

                FMetafileMap.Clear;
              end;
            end;
          end;

        mmtReject:; { запрос отклонен }
      end;
    end;
  finally
    Unlock;
  end;
end;

procedure TSeeding.OnPeerHave(APeer: IPeer; APieceIndex: Integer);
begin
  Lock;
  try
    { расширяем сумму }
    FPeersHave.Len := Max(FPeersHave.Len, APieceIndex);
    { добавляем в сумму индекс, который до этого отсутствовал у пира }
    FPeersHave.Inc(APieceIndex);
  finally
    Unlock;
  end;
end;

procedure TSeeding.OnPeerInterest(APeer: IPeer);
begin
  Lock;
  try
    if (ssCompleted in FStates) or not (not APeer.Bitfield and FBitField).AllFalse then
      APeer.Unchoke;
  finally
    Unlock;
  end;
end;

procedure TSeeding.OnPeerPiece(APeer: IPeer; APieceIndex, AOffset: Integer;
  AData: TUniString);
var
  p: IPiece;
  it: IPeer;
begin
  Lock;
  try
    { когда нам приходит левый кусок, по идее надо кикать пира }
    if APieceIndex >= FMetafile.PiecesCount then
      raise EProtocolWrongPiece.CreateFmt('Wrong piece (%d)', [APieceIndex]);

    if FBitField[APieceIndex] then
    begin
      Inc(FOverageCount, AData.Len);
      {$IFDEF DEBUG}
      DebugOutput('Ненужный кусок ' + APieceIndex.ToString);
      {$ENDIF}
      Exit;
    end;

    if FPiecesBuf.ContainsKey(APieceIndex) then
    begin
      p := FPiecesBuf[APieceIndex];
      p.AddBlock(AOffset, AData);
    end else
    begin
      // newpiece
      p := TPiece.Create(APieceIndex, FMetafile.PieceLength[APieceIndex], AOffset, AData);
      FPiecesBuf.Add(APieceIndex, p);
    end;

    FDownloadQueue.Dequeue(APieceIndex, AOffset, AData.Len); { выбрасываем из буфера закачек }

    if p.Completed then
    try
      try
        {$IFDEF DEBUG}
        DebugOutput('write piece ' + p.Index.ToString);
        {$ENDIF}
        FFileSystem.PieceWrite(p);
      except
        on E: EFileSystemWriteException do
        begin
          FPiecesBuf.Clear;
          MarkAsError;
          raise;
        end;

        on E: EFileSystemCheckException do
        begin
          { выбрасываем кусок }
          FPiecesBuf.Remove(APieceIndex);
          Inc(FHashErrorCount);
          Exit;
        end;

        on E: Exception do
        begin
          FPiecesBuf.Clear;
          MarkAsError;
          raise;
        end;
      end;

      FBitField[APieceIndex] := True; { делаем отметку, что кусок загружен }

      for it in FPeers do
      begin
        {if it.HaveMask[AIndex] then  (типа разослать только тем, у кого есть кусок?)}
        it.SendHave(APieceIndex);

        { рассылаем всем отмену запрошенного куска, если запрашивали в режиме EndGame }
        if FEndGame then
          TPiece.EnumBlocks(FMetafile.PieceLength[APieceIndex],
            procedure (AOffset, ALength: Integer)
            begin
              it.Cancel(APieceIndex, AOffset);
            end);
      end;

      FPiecesBuf.Remove(APieceIndex);

      { всё загружено? }
      if FBitField.AllTrue then
      begin
        FStates := FStates + [ssCompleted] - [ssDownloading];

        { мы всё загрузили, нам больше никто не интересен }
        for it in FPeers do
          if pfWeInterested in it.Flags then
            it.NotInterested;
      end else
      if not FEndGame then
        FetchNext(APeer);
    finally
      Update;
    end;
  finally
    Unlock;
  end;
end;

procedure TSeeding.OnPeerRequest(APeer: IPeer; APieceIndex, AOffset,
  ASize: Integer);
begin
  Lock;
  try
    { надо кикать и блочить пира, если он спрашивает с нас то, чего мы не имеем }
    Assert(ssHaveMetadata in FStates);
    Assert(not (pfWeChoke in APeer.Flags));
    Assert(FBitField[APieceIndex]);

    { добавляем в очередь на отправку
      (запрещаем повторные реквесты, ибо гарантируем отдачу куска) }
    with FUploadQueue do
      if CanEnqueue(APieceIndex, AOffset, ASize, APeer) then
        Enqueue(APieceIndex, AOffset, ASize, APeer);
  finally
    Unlock;
  end;
end;

procedure TSeeding.OnPeerBitfield(APeer: IPeer; AInfoHash: TUniString;
  ABitField: TBitField);
begin
  Lock;
  try
    // пополняем список доступности
    FPeersHave := FPeersHave + ABitField;
  finally
    Unlock;
  end;
end;

function TSeeding.OnRequire(AItem: ISeedingItem; AOffset,
  ALength: Int64): Boolean;
begin
  Result := Require(AItem, AOffset, ALength);
end;

procedure TSeeding.Pause;
begin
  Lock;
  try
    if ssDownloading in FStates then
    begin
      FStates := FStates + [ssPaused];
      CancelDownloading;
      Update;
    end;
  finally
    Unlock;
  end;
end;

procedure TSeeding.CancelReuests(APiece, AOffset: Integer; APeer: IPeer);
begin
  {$IFDEF DEBUG}
  DebugOutput('отмена запрошенного куска ' + APiece.ToString);
  {$ENDIF}

  APeer.Cancel(APiece, AOffset);
end;

procedure TSeeding.CheckBlackList;
var
  h: string;
  t: TDateTime;
begin
  t := Now;

  for h in FBlackList.Keys do
    if MinutesBetween(t, FBlackList[h]) >= FBlackListTime then
      FBlackList.Remove(h);
end;

procedure TSeeding.RemovePeer(APeer: IPeer);
begin
  Lock;
  try
    { вычитаем маску пира }
    if APeer.Bitfield.CheckedCount > 0 then
      FPeersHave := FPeersHave - APeer.Bitfield;

    FDownloadQueue.CancelRequests(APeer);
    FUploadQueue.CancelRequests(APeer);

    RemovePeerCallbacks(APeer);

    FEndGameList.Remove(APeer);
    FPeers.Remove(APeer);
  finally
    Unlock;
  end;
end;

procedure TSeeding.RemovePeerCallbacks(APeer: IPeer);
begin
  APeer.OnConnect       := nil;
  APeer.OnDisonnect     := nil;
  APeer.OnException     := nil;
  APeer.OnBitfield      := nil;
  APeer.OnRequest       := nil;
  APeer.OnHave          := nil;
  APeer.OnCancel        := nil;
  APeer.OnPiece         := nil;
  APeer.OnChoke         := nil;
  APeer.OnInterest      := nil;
  APeer.OnUpdateCounter := nil;
end;

function TSeeding.Require(AItem: ISeedingItem; AOffset,
  ALength: Int64): Boolean;
var
  i, fp, lp: Integer;
begin
  Lock;
  try
    Result := False;

    if (AItem.Priority <> fpSkip) and not AItem.IsLoaded(AOffset, ALength) then
    begin
      { определяем нужные куски и смотрим, есть ли они в очереди }
      fp := AItem.FirstPiece + AOffset div FMetafile.PiecesLength;
      lp := AItem.FirstPiece + (AOffset + ALength) div FMetafile.PiecesLength;

      for i := lp downto fp do
        Result := FPiecePicker.Push(i) or Result;
    end;
  finally
    Unlock;
  end;
end;

procedure TSeeding.Resume;
begin
  Lock;
  try
    if ssDownloading in FStates then
    begin
      FStates := FStates - [ssPaused];
      Touch;
    end;
  finally
    Unlock;
  end;
end;

procedure TSeeding.SetOnDelete(Value: TProc<ISeeding>);
begin
  FOnDelete := Value;
end;

procedure TSeeding.SetOnMetadataLoaded(const Value: TProc<ISeeding, IMetaFile>);
begin
  FOnMetadataLoaded := Value;
end;

procedure TSeeding.SetOnUpdate(Value: TProc<ISeeding>);
begin
  FOnUpdate := Value;
end;

procedure TSeeding.SetOnUpdateCounter(Value: TProc<ISeeding, UInt64, UInt64>);
begin
  FOnUpdateCounter := Value;
end;

procedure TSeeding.Start;
begin
  Lock;
  try
    if not (ssDownloading in FStates) and not FBitField.AllTrue then
    begin
      FStates := FStates + [ssDownloading] - [ssPaused];
      Touch;
    end;
  finally
    Unlock;
  end;
end;

procedure TSeeding.Stop;
begin
  Lock;
  try
    if ssDownloading in FStates then
    begin
      FStates := FStates - [ssActive, ssPaused];
      CancelDownloading;
      Update;
    end;
  finally
    Unlock;
  end;
end;

procedure TSeeding.Touch;
begin
  Lock;
  try
    FLastRequest := Now;
    FStates := FStates + [ssActive];
    Update;
  finally
    Unlock;
  end;
end;

procedure TSeeding.DoSync;
var
  tr: ITracker;
  trstat: IStatTracker;
  peer: IPeer;
  want: TBitField;
  haveMD,
  weLoad, alive: Boolean;
  t: TTime;
begin
  Lock;
  try
    t := Now;

    if SecondsBetween(t, FLastTrackersSync) >= 1 then
    begin
      { устанавливаем данные трекерам и вызываем им всем Sync }
      for tr in FTrackers do
        if not tr.Busy then
        begin
          if Supports(tr, IStatTracker, trstat) then
          with trstat do
          begin
            BytesUploaded    := FCounter.TotalUploaded;
            BytesDownloaded  := GetCompeteSize;
            BytesLeft        := GetTotalSize - GetCompeteSize;
            BytesCorrupt     := GetCorruptedSize;
          end;

          tr.Sync;
        end;

      FLastTrackersSync := t;
    end;

    if not(ssActive in FStates) then
      Exit;

    haveMD  := (ssHaveMetadata in FStates);
    weLoad  := (ssDownloading  in FStates) and not (ssPaused in FStates);
    alive   := False;

    if haveMD and weLoad then
      want := GetWant
    else
    if not weLoad then
      (FCounter as IMutableCounter).ResetSpeed; { сброс показаний скорости }

    FDownloadQueue.Timeout; { проверка таймаута }

    for peer in FPeers do
      if not peer.Busy then
      begin
        { соединение (хендшейк пройден) установлено успешно и у нас есть метаданные }
        if peer.ConnectionEstablished and haveMD then { мы чето качаем }
        begin
          FEndGame := weLoad and want.AllFalse and not FBitField.AllTrue;

          if weLoad and (peer.Bitfield.Len > 0) and (FEndGame or
            not TBitField(want and peer.Bitfield).AllFalse) then
          begin
            { он нам интересен, просим нас раздушить }
            if [pfWeInterested] * peer.Flags = [] then
              peer.Interested
            else
              FetchNext(peer); { пробуем что-нибудь с него скачать }
          end;

          { отвечаем на запросы }
          alive := FUploadQueue.Dequeue(peer,
            procedure (APeer: IPeer; APiece, AOffset, ASize: Integer)
            var
              p: IPiece;
              d: TUniString;
            begin
              try
                p := FFileSystem.Piece[APiece];
                Assert(Assigned(p));

                d.Assign(p.Data);
                Assert(not d.Empty);
              except
                on E: Exception do
                begin
                  MarkAsError;
                  raise;
                end;
              end;

              APeer.SendPiece(APiece, AOffset, d.Copy(AOffset, ASize));
            end) or weLoad or alive;
        end;

        if weLoad or (pfTheyInterested in peer.Flags) then
        begin
          (*
          // если мы качаем и с нас скачивают больше, чем отдают -- душим
          // а когда снимать удушение?
          if (not weLoad) and (peer.Rate < MinPeerRate) then
          begin
            FUploadQueue.CancelRequests(peer);
            peer.Choke;
          end;
          *)

          { sync! }
          peer.Sync;
        end else
        if not weLoad and (peer.ConnectionType = ctOutgoing) then
        begin
          { отключаемся от пиров, к которым МЫ подключились, если загрузка завершена
            и пир в нас не заинтересован }
          {$IFDEF DEBUG}
          DebugOutput('disconnect ' + peer.Host);
          {$ENDIF}
          peer.Disconnect;
          Break;
        end;
      end;

    if haveMD and (SecondsBetween(t, FLastCacheClear) >= CacheClearInterval) then
    begin
      FFileSystem.ClearCaches;
      FLastCacheClear := t;
    end;

    if alive then
      Touch
    else
    if haveMD and ((SecondsBetween(t, FLastRequest) >= MaxIdleTime) or
        (not weload and (Length(TPrelude.Filter<IPeer>(FPeers.ToArray,
            function(APeer: IPeer): Boolean
            begin
              Result := APeer.ConnectionType = ctIncoming;
            end)
            ) = 0
          )
        )
      ) then
    begin
      { мы скачали, а с нас не качают -- переводим раздачу в пассивный режим,
        отключаемся от пиров }
      Exclude(FStates, ssActive);

      DisconnectAllPeers;

      FEndGameList.Clear;
      FPeers.Clear;
    end;
  finally
    Unlock;
  end;
end;

procedure TSeeding.FetchNext(APeer: IPeer);
var
  idx: Integer;
  pcs: TArray<Integer>;
begin
  Lock;
  try
    if ([pfTheyChoke] * APeer.Flags = []) and (FEndGame or FDownloadQueue.CanEnqueue(APeer)) then
    begin
      for idx in FPiecePicker.Fetch(APeer.Bitfield, FPeersHave, GetWant) do
      begin
        if FEndGame then
        begin
          FEndGameList.TryGetValue(APeer, pcs);

          if (Length(pcs) = 0) or (TPrelude.ElemIndex<Integer>(pcs, idx) = -1) then
          begin
            TAppender.Append<Integer>(pcs, idx);
            FEndGameList.AddOrSetValue(APeer, pcs);
          end else
            Continue;
        end;

        TPiece.EnumBlocks(FMetafile.PieceLength[idx],
          procedure (AOffset, ALength: Integer)
          begin
            if FEndGame then
              APeer.Request(idx, AOffset, ALength)
            else { проверяем, загружен ли текущий блок или его можно запросить с кого-либо }
            if not (FPiecesBuf.ContainsKey(idx) and FPiecesBuf[idx].ContainsBlock(AOffset)) and
                FDownloadQueue.CanEnqueue(idx, AOffset, ALength, APeer) then
            begin
              FDownloadQueue.Enqueue(idx, AOffset, ALength, APeer);
              APeer.Request(idx, AOffset, ALength);

              {$IFDEF DEBUG}
              DebugOutput(Format('fetch %d (%d/%d) from %s', [idx, AOffset, ALength, APeer.Host]));
              {$ENDIF}
            end;
          end);
      end;
    end;
  finally
    Unlock;
  end;
end;

procedure TSeeding.Unlock;
begin
  System.TMonitor.Exit(FLock);
end;

procedure TSeeding.Update;
begin
  if Assigned(FOnUpdate) then
    FOnUpdate(Self);
end;

procedure TSeeding.UpdateCounter(APeer: IPeer; ADown, AUpl: UInt64);
begin
  (FCounter as IMutableCounter).Add(ADown, AUpl);

  if Assigned(FOnUpdateCounter) then
    FOnUpdateCounter(Self, ADown, AUpl);
end;

{ TSeeding.TDownloadPieceQueue }

constructor TSeeding.TDownloadPieceQueue.Create(APieceCount: Integer;
  AOnTimeout, AOnCancel: TProc<Integer, Integer, IPeer>);
begin
  inherited Create;

  FItems      := TDictionary<TDownloadKey, TDownloadPieceQueueItem>.Create(
    TDelegatedEqualityComparer<TDownloadKey>.Create(
      function (const ALeft, ARight: TDownloadKey): Boolean
      begin
        Result := CompareMem(@ALeft[dkiPiece], @ARight[dkiPiece], SizeOf(TDownloadKey));
      end,
      function (const AValue: TDownloadKey): Integer
      begin
        Result := THashBobJenkins.GetHashValue(AValue[dkiPiece], SizeOf(TDownloadKey));
      end
    )
  );
  FOnTimeout  := AOnTimeout;
  FOnCancel   := AOnCancel;
end;

function TSeeding.TDownloadPieceQueue.CreateKey(APiece, AOffset,
  ASize: Integer): TDownloadKey;
begin
  Result[dkiPiece]   := APiece;
  Result[dkiOffset]  := AOffset;
  Result[dkiSize]    := ASize;
end;

procedure TSeeding.TDownloadPieceQueue.Dequeue(APiece, AOffset, ASize: Integer);
begin
  FItems.Remove(CreateKey(APiece, AOffset, ASize));
end;

procedure TSeeding.TDownloadPieceQueue.Dequeue(APiece: Integer);
var
  keys: TArray<TDownloadKey>;
  key: TDownloadKey;
begin
  keys := FItems.Keys.ToArray;

  for key in keys do
    if key[dkiPiece] = APiece then
      FItems.Remove(key);
end;

destructor TSeeding.TDownloadPieceQueue.Destroy;
begin
  FItems.Free;
  inherited;
end;

procedure TSeeding.TDownloadPieceQueue.Enqueue(APiece, AOffset, ASize: Integer; APeer: IPeer);
begin
  FItems.Add(CreateKey(APiece, AOffset, ASize),
    TDownloadPieceQueueItem.Create(APeer));
end;

procedure TSeeding.TDownloadPieceQueue.CancelRequest(APeer: IPeer; APieceIndex,
  AOffset: Integer);
var
  key: TDownloadKey;
  keys: TArray<TDownloadKey>;
begin
  keys := FItems.Keys.ToArray; // по идее, при таком использовании должны удаляться все элементы

  for key in keys do
    if key[dkiPiece] = APieceIndex then
      FItems.Remove(key);
end;

procedure TSeeding.TDownloadPieceQueue.CancelRequests(APeer: IPeer);
var
  key: TDownloadKey;
  keys: TArray<TDownloadKey>;
begin
  keys := FItems.Keys.ToArray; // по идее, при таком использовании должны удаляться все элементы

  for key in keys do
    if FItems[key].Peer.HashCode = APeer.HashCode then
    begin
      FItems.Remove(key);

      if Assigned(FOnCancel) then
        FOnCancel(key[dkiPiece], key[dkiOffset], APeer);
    end;
end;

function TSeeding.TDownloadPieceQueue.CanEnqueue(APiece, AOffset, ASize: Integer;
  APeer: IPeer): Boolean;
begin
  Result := CanEnqueue(APeer) and CanEnqueue(APiece, AOffset, ASize);
end;

function TSeeding.TDownloadPieceQueue.CanEnqueue(APiece, AOffset,
  ASize: Integer): Boolean;
begin
  Result := (FItems.Count < MaxBlocksQueueSize) and not FItems.ContainsKey(
    CreateKey(APiece, AOffset, ASize)
  );
end;

function TSeeding.TDownloadPieceQueue.CanEnqueue(APeer: IPeer): Boolean;
begin
  Result := (FItems.Count < MaxBlocksQueueSize) and Assigned(APeer) and (
    Length(
      TPrelude.Filter<TDownloadKey>(FItems.Keys.ToArray,
        function (AKey: TDownloadKey): Boolean
        begin
          Result := FItems[AKey].Peer.HashCode = APeer.HashCode
        end
      )
    ) <= MaxPeerBlocksCount
  );
end;

procedure TSeeding.TDownloadPieceQueue.Timeout;
var
  keys: TArray<TDownloadKey>;
  key: TDownloadKey;
  t: TDateTime;
begin
  t := Now;

  keys := FItems.Keys.ToArray;

  for key in keys do
    if SecondsBetween(t, FItems[key].TimeStamp) > MaxPieceQueueTimeout then
    try
      if Assigned(FOnTimeout) then
        FOnTimeout(key[dkiPiece], key[dkiOffset], FItems[key].Peer);
    finally
      FItems.Remove(key);
    end;
end;

{ TSeeding.TDownloadPieceQueue.TDownloadPieceQueue }

constructor TSeeding.TDownloadPieceQueue.TDownloadPieceQueueItem.Create(
  APeer: IPeer);
begin
  Peer := APeer;
  TimeStamp := Now;
end;

{ TSeeding.TUploadPieceQueue }

procedure TSeeding.TUploadPieceQueue.CancelRequest(APeer: IPeer; APieceIndex,
  AOffset: Integer);
var
  i: Integer;
begin
  for i := FList.Count - 1 downto 0 do
    with FList[i] do
      if (Piece = APieceIndex) and (Offset = AOffset) and (Peer.HashCode = APeer.HashCode) then
        FList.Delete(i);
end;

procedure TSeeding.TUploadPieceQueue.CancelRequests(APeer: IPeer);
var
  i: Integer;
begin
  for i := FList.Count - 1 downto 0 do
    with FList[i] do
      if Peer.HashCode = APeer.HashCode then
        FList.Delete(i);
end;

function TSeeding.TUploadPieceQueue.CanEnqueue(APiece, AOffset, ASize: Integer;
  APeer: IPeer): Boolean;
var
  it: TUploadPieceQueueItem;
begin
  Assert(Assigned(APeer));

  for it in FList do
    with it do
    if (Piece         = APiece  ) and
       (Offset        = AOffset ) and
       (Size          = ASize   ) and
       (Peer.HashCode = APeer.HashCode) then
      Exit(False);

  Result := True;
end;

constructor TSeeding.TUploadPieceQueue.Create;
begin
  inherited Create;
  FList := TList<TUploadPieceQueueItem>.Create;
end;

function TSeeding.TUploadPieceQueue.Dequeue(APeer: IPeer;
  ADequeueProc: TProc<IPeer, Integer, Integer, Integer>): Boolean;
var
  i, j, k: Integer;
  it: TUploadPieceQueueItem;
begin
  Result := False;

  if GetIsEmpty then
    Exit;

  Assert(Assigned(ADequeueProc));

  i := 0;
  j := -1;
  k := 0;

  while (not GetIsEmpty) and (i < FList.Count) and (k < MaxPieceRequestCount) do
  begin
    it := FList[i];

    if ((j = -1) or (j = it.Piece)) and (it.Peer.HashCode = APeer.HashCode) then
    begin
      j := it.Piece;

      ADequeueProc(APeer, it.Piece, it.Offset, it.Size);
      FList.Delete(i);
      Inc(k);

      Result := True;
    end else
      Inc(i);
  end;
end;

destructor TSeeding.TUploadPieceQueue.Destroy;
begin
  FList.Free;
  inherited;
end;

procedure TSeeding.TUploadPieceQueue.Enqueue(APiece, AOffset, ASize: Integer;
  APeer: IPeer);
begin
  FList.Add(TUploadPieceQueueItem.Create(APeer, APiece, AOffset, ASize));
end;

function TSeeding.TUploadPieceQueue.GetIsEmpty: Boolean;
begin
  Assert(FList.Count >= 0);
  Result := FList.Count = 0;
end;

{ TSeeding.TUploadPieceQueue.TUploadPieceQueueItem }

constructor TSeeding.TUploadPieceQueue.TUploadPieceQueueItem.Create(
  APeer: IPeer; APiece, AOffset, ASize: Integer);
begin
  Peer    := APeer;
  Piece   := APiece;
  Offset  := AOffset;
  Size    := ASize;
end;

end.
