unit Bittorrent.Seeding;

interface

uses
  System.SysUtils, System.Generics.Collections, System.Generics.Defaults,
  System.Math, System.DateUtils, System.Hash,
  Basic.UniString,
  Bittorrent, Bittorrent.Bitfield, Bittorrent.Utils, Bittorrent.ThreadPool,
  BusyObj, Common.SortedList,
  IdGlobal, IdStack, IdURI;

type
  { собственно раздача. одна раздача -- один торрент-файл }
  TSeeding = class(TBusy, ISeeding)
  private
    const
      MaxIdleTime          = 1;   { минут }
      MaxPieceQueueSize    = 256; { максимальное кол-во запросов }
      { это значение необходимо рассчитывать, т.к. размер куска может быть разным (32 куска по 32 кб = 1 мегабайт) }
      MaxPeerPiecesCount   = 8;   { максимальное кол-во кусков, запрашиваемых с одного пира за раз }
      MaxPieceQueueTimeout = 10;  { секунд (тоже зависит от скорости) }

    type
      IPieceQueue = interface
      ['{2A153346-D39E-48CE-9D84-7FFD5186C83A}']
        procedure CancelRequests(APeer: IPeer);
      end;

      IDownloadPieceQueue = interface(IPieceQueue)
      ['{21E227E7-EDCF-4CB0-9F4E-4E2861E39E85}']
        function GetAsBitfield: TBitField;

        function CanEnqueue(APeer: IPeer = nil): Boolean;
        procedure Enqueue(APiece: Integer; APeer: IPeer); { поставить в очередь }
        procedure Dequeue(APiece: Integer);
        procedure Touch(APiece: Integer); { пир прислал часть куска, обновить время }
        procedure Timeout; { выбросить всё ненужное по таймауту }

        property AsBitfield: TBitField read GetAsBitfield;
      end;

      IUploadPieceQueue = interface(IPieceQueue)
      ['{21E227E7-EDCF-4CB0-9F4E-4E2861E39E85}']
        function GetIsEmpty: Boolean;

        procedure Enqueue(APiece, AOffset, ASize: Integer; APeer: IPeer); { поставить в очередь }
        procedure Dequeue(APeer: IPeer;
          ADequeueProc: TProc<IPeer, {piece}Integer, {offset}Integer, {size}Integer>);
        procedure Reject(APeer: IPeer); { отменить все запросы от пира (например он отключился) }

        property IsEmpty: Boolean read GetIsEmpty;
      end;

      TPieceQueue = class abstract(TInterfacedObject, IPieceQueue)
      protected
        procedure CancelRequests(APeer: IPeer); virtual; abstract;
      end;

      TDownloadPieceQueue = class(TPieceQueue, IDownloadPieceQueue)
      private
        type
          TDownloadPieceQueueItem = record
            Peer: IPeer;
            Piece: Integer;
            TimeStamp: TDateTime;

            constructor Create(APeer: IPeer; APiece: Integer);
          end;
      private
        FBitField: TBitField;
        FList: TList<TDownloadPieceQueueItem>;
        FOnTimeout: TProc<Integer, IPeer>;

        function GetAsBitfield: TBitField; inline;
        function CanEnqueue(APeer: IPeer = nil): Boolean;
        procedure Enqueue(APiece: Integer; APeer: IPeer); inline;
        procedure Dequeue(APiece: Integer);
        procedure Touch(APiece: Integer);
        procedure Timeout;
      protected
        procedure CancelRequests(APeer: IPeer); override;
      public
        constructor Create(APieceCount: Integer; AOnTimeout: TProc<Integer, IPeer>);
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
        procedure Enqueue(APiece, AOffset, ASize: Integer; APeer: IPeer); inline;
        procedure Dequeue(APeer: IPeer; ADequeueProc: TProc<IPeer, Integer, Integer, Integer>);
        procedure Reject(APeer: IPeer);
      protected
        procedure CancelRequests(APeer: IPeer); override;
      public
        constructor Create;
        destructor Destroy; override;
      end;
  private
    FLastRequest: TDateTime;
    FLock: TObject;
    FMetafile: IMetaFile;
    FMetafileMap: TSortedList<Integer, TUniString>;
    FMetadataSize: Integer;
    FInfoHash: TUniString;
    FFileSystem: IFileSystem;
    FDownloadPath: string;
    FDownloadQueue: IDownloadPieceQueue; // список кусков, которые мы запросили (чтобы не запрашивать повторно)
    FUploadQueue: IUploadPieceQueue; // список кусков, которые с нас запросили
    FPiecePicker: IPiecePicker;
    FThreadPool: TThreadPool;
    FPeers: TList<IPeer>; // их бы сортировать по скорости и количеству отдаваемго
    FTrackers: TList<ITracker>;
    FPieces: TDictionary<Integer, IPiece>;
    FStates: TSeedingStates;
    FClientVersion: string;
    FListenPort: TIdPort;
    FBitField: TBitField; // то, что мы имеем
    FOnMetadataLoaded: TProc<TUniString>;
    FHashErrorCount: Integer;
  private
    function GetLastRequest: TDateTime; inline;
    function GetPeers: TList<IPeer>; inline;
    function GetTrackers: TList<ITracker>; inline;
    function GetInfoHash: TUniString; inline;
    function GetBitfield: TBitField; inline;
    function GetMetafile: IMetaFile; inline;
    function GetFileSystem: IFileSystem; inline;
    function GetState: TSeedingStates; inline;
    function GetHashErrorCount: Integer; inline;
    function GetPercentComplete: Double; inline;
    function GetDownloadPath: string; inline;
    function GetOnMetadataLoaded: TProc<TUniString>; inline;
    procedure SetOnMetadataLoaded(Value: TProc<TUniString>); inline;
    procedure OnPeerExtendedMessage(APeer: IPeer; AMessage: IExtension);

    procedure AddPeer(const AHost: string; APort: TIdPort; APeerID: string;
      AIPVer: TIdIPVersion = Id_IPv4); overload;
    procedure AddPeer(APeer: IPeer; AHSMessage: IHandshakeMessage); overload;
    procedure AddTracker(const ATrackerURL, APeerID: string; AListenPort: TIdPort);
    procedure Touch; inline;
    procedure Delete(ADeleteFiles: Boolean = False); inline;

    { обработчики событий пира }
    procedure OnPeerConnect(APeer: IPeer; AMessage: IMessage);
    procedure OnPeerException(APeer: IPeer; AException: Exception);

    procedure OnPeerRequest(APeer: IPeer; APieceIndex, AOffset, ASize: Integer);
    procedure OnPeerPiece(APeer: IPeer; AIndex, AOffset: Integer; AData: TUniString);
    procedure OnPeerChoke(APeer: IPeer);
    procedure OnPeerInterest(APeer: IPeer);

    procedure Lock; inline;
    procedure Unlock; inline;

    procedure InitMetadata(AMetafile: IMetaFile);

    procedure ApplyPeerCallbacks(APeer: IPeer);
  protected
    procedure DoSync; override;
  public
    constructor Create(const ADownloadPath: string; AThreadPoolEx: TThreadPool;
      AInfoHash: TUniString; AClientVersion: string; AListenPort: TIdPort); overload;
    constructor Create(const ADownloadPath: string; AThreadPoolEx: TThreadPool;
      AMetafile: IMetaFile; AClientVersion: string; AListenPort: TIdPort); overload;
    destructor Destroy; override;
  end;

implementation

uses
  Bittorrent.Peer, Bittorrent.Messages, Bittorrent.Extensions, Bittorrent.Piece,
  Bittorrent.MetaFile, Bittorrent.PiecePicker, Bittorrent.FileSystem,
  Bittorrent.Tracker.HTTPTracker;

{ TSeeding }

procedure TSeeding.AddPeer(const AHost: string; APort: TIdPort; APeerID: string;
  AIPVer: TIdIPVersion);
var
  peer: IPeer;
begin
  Lock;
  try
    for peer in FPeers do
      if (peer.Host   = AHost ) and
         (peer.Port   = APort ) and
         (peer.IPVer  = AIPVer) then
        Exit;

    peer := TPeer.Create(FThreadPool, AHost, APort, GetInfoHash, APeerID, AIPVer);
    FPeers.Add(peer);
    ApplyPeerCallbacks(peer);
  finally
    Unlock;
  end;
end;

procedure TSeeding.AddPeer(APeer: IPeer; AHSMessage: IHandshakeMessage);
var
  peer: IPeer;
begin
  Lock;
  try
    { вынести в отдельную ф-ю }
    for peer in FPeers do
      if (peer.Host   = APeer.Host ) and  { внешний порт каждый раз разный, поэтому не проверяем }
         (peer.IPVer  = APeer.IPVer) then
        raise Exception.Create('Peer already connected');

    FPeers.Add(APeer);
    ApplyPeerCallbacks(APeer);
    OnPeerConnect(APeer, AHSMessage);
  finally
    Unlock;
  end;
end;

procedure TSeeding.AddTracker(const ATrackerURL, APeerID: string;
  AListenPort: TIdPort);
var
  tr: ITracker;
  uri: TIdURI;
begin
  Lock;
  try
    for tr in FTrackers do
      if tr.AnnounceURL = ATrackerURL then
        raise Exception.Create('Tracker already added');

    uri := TIdURI.Create(ATrackerURL);
    try
      if uri.Protocol.ToLower = 'http' then
        FTrackers.Add(THTTPTracker.Create(FThreadPool, FInfoHash, ATrackerURL,
          APeerID, AListenPort) as ITracker)
      else
        raise ETrackerInvalidProtocol.CreateFmt('Unknown tracker uri protocol (%s)', [uri.Protocol]);
    finally
      uri.Free;
    end;
  finally
    Unlock;
  end;
end;

procedure TSeeding.ApplyPeerCallbacks(APeer: IPeer);
begin
  APeer.OnConnect         := OnPeerConnect;
  APeer.OnException       := OnPeerException;
  APeer.OnRequest         := OnPeerRequest;
  APeer.OnPiece           := OnPeerPiece;
  APeer.OnChoke           := OnPeerChoke;
  APeer.OnInterest        := OnPeerInterest;
  APeer.OnExtendedMessage := OnPeerExtendedMessage;
end;

constructor TSeeding.Create(const ADownloadPath: string;
  AThreadPoolEx: TThreadPool; AMetafile: IMetaFile; AClientVersion: string;
  AListenPort: TIdPort);
begin
  Create(ADownloadPath, AThreadPoolEx, AMetafile.InfoHash, AClientVersion, AListenPort);
  InitMetadata(AMetafile);
end;

constructor TSeeding.Create(const ADownloadPath: string;
  AThreadPoolEx: TThreadPool; AInfoHash: TUniString; AClientVersion: string;
  AListenPort: TIdPort);
begin
  inherited Create;

  FThreadPool := AThreadPoolEx;
  FLock         := TObject.Create;

  FPeers        := System.Generics.Collections.TList<IPeer>.Create;
  FTrackers     := System.Generics.Collections.TList<ITracker>.Create;

  FPieces       := System.Generics.Collections.TDictionary<Integer, IPiece>.Create;
  FPiecePicker  := TRarestPicker.Create;

  FStates       := [ssActive];
  FInfoHash.Assign(AInfoHash);

  FDownloadPath := ADownloadPath;
  FClientVersion:= AClientVersion;
  FListenPort   := AListenPort;

  FLastRequest  := UtcNow;

  FMetafileMap  := TSortedList<Integer, TUniString>.Create(
    TDelegatedComparer<Integer>.Create(
      function (const Left, Right: Integer): Integer
      begin
        Result  := Left - Right;
      end) as IComparer<Integer>
  );
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
end;

destructor TSeeding.Destroy;
begin
  FTrackers.Free;
  FPeers.Free;
  FPieces.Free;
  FLock.Free;
  FMetafileMap.Free;
  inherited;
end;

function TSeeding.GetBitfield: TBitField;
begin
  Result := FBitField;
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

function TSeeding.GetLastRequest: TDateTime;
begin
  Result := FLastRequest;
end;

function TSeeding.GetMetafile: IMetaFile;
begin
  Result := FMetafile;
end;

function TSeeding.GetOnMetadataLoaded: TProc<TUniString>;
begin
  Result := FOnMetadataLoaded;
end;

function TSeeding.GetPeers: System.Generics.Collections.TList<IPeer>;
begin
  Result := FPeers;
end;

function TSeeding.GetPercentComplete: Double;
begin
  with FBitField do
    Result := CheckedCount / Len * 100;
end;

function TSeeding.GetState: TSeedingStates;
begin
  Result := FStates;
end;

function TSeeding.GetTrackers: TList<ITracker>;
begin
  Result := FTrackers;
end;

procedure TSeeding.InitMetadata(AMetafile: IMetaFile);
begin
  FMetafile     := AMetafile;
  FMetadataSize := AMetafile.MetadataSize;
  FStates       := FStates + [ssHaveMetadata];
  FFileSystem   := TFileSystem.Create(AMetafile, FDownloadPath);
  FBitField     := FFileSystem.CheckFiles; { проверять файлы надо только в том случае, если раздача сохраняется поверх существующих файлов (проверка на больших раздачах долгая) }
  FDownloadQueue:= TDownloadPieceQueue.Create(AMetafile.PiecesCount, nil); { надо обрабатывать событие таймаута }
  FUploadQueue  := TUploadPieceQueue.Create;

  if FBitField.AllTrue then
    FStates := FStates + [ssCompleted] - [ssDownloading] { всё загружено }
  else
    FStates := FStates + [ssDownloading] - [ssCompleted]; { загружается }

  FLastRequest  := UtcNow;
end;

procedure TSeeding.Lock;
begin
  System.TMonitor.Enter(FLock);
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
    Assert(Supports(AMessage, IHandshakeMessage));

    if (AMessage as IHandshakeMessage).SupportsDHT then
      (APeer as IPeer).SendPort(12345); { наш порт входящих соединений (DHT port) }

    if (AMessage as IHandshakeMessage).SupportsExtendedMessaging then
    begin
      if Assigned(FMetafile) then
        (APeer as IPeer).SendExtensionMessage(TExtensionHandshake.Create(FClientVersion,
          FListenPort, FMetafile.MetadataSize) as IExtension)
      else
        (APeer as IPeer).SendExtensionMessage(TExtensionHandshake.Create(FClientVersion,
          FListenPort, 0) as IExtension);
    end;

    { сразу отправляем ему bitfield, если есть }
    if ssHaveMetadata in FStates then
      APeer.SendBitfield(FBitField);
  finally
    Unlock;
  end;
end;

procedure TSeeding.OnPeerException(APeer: IPeer; AException: Exception);
begin
  { сетевая ошибка -- выбрасываем из списка пиров }
  Lock;
  try
    FPeers.Remove(APeer);
    {if Assigned(FOnPeerError) then
      FOnPeerError(APeerSelf);}
  finally
    Unlock;
  end;
end;

procedure TSeeding.OnPeerExtendedMessage(APeer: IPeer; AMessage: IExtension);
var
  hs: IExtensionHandshake;
  md: IExtensionMetadata;
  i, j: Integer;
  tmp: TUniString;
  it: IPeer;
begin
  Lock;
  try
    //Assert(Supports(APeer, IPeer));

    if Supports(AMessage, IExtensionHandshake, hs) then
    begin
      {$REGION 'handshake'}
      if (hs.MetadataSize > 0) and not(ssHaveMetadata in FStates) then
      begin
        { prepare for loading metadata }
        Assert(APeer.ExteinsionSupports.ContainsKey(TExtensionMetadata.GetClassSupportName));

        FMetadataSize := hs.MetadataSize;
        { request all metadata pieces }
        i := 0;
        j := 0;

        while j < FMetadataSize do
        begin
          if not FMetafileMap.ContainsKey(i) then
            APeer.SendExtensionMessage(TExtensionMetadata.Create(mmtRequest, i) as IExtensionMetadata);

          Inc(i);
          Inc(j, TExtensionMetadata.BlockSize);
        end;
      end;
      {$ENDREGION}

      // coment
      APeer.SendExtensionMessage(TExtensionComment.Create(cmtRequest) as IExtensionComment);
    end else
    if Supports(AMessage, IExtensionMetadata, md) then
    begin
      {$REGION 'metadata'}
      { receive, store }
      case md.MessageType of
        mmtRequest:
          begin
            { they ask us }
            tmp := FMetafile.Metadata;
            { проверка правильности указания куска }
            Assert(md.Piece * TExtensionMetadata.BlockSize <= tmp.Len);
            (APeer as IPeer).SendExtensionMessage(TExtensionMetadata.Create(
              mmtData,
              md.Piece,
              tmp.Copy(md.Piece * TExtensionMetadata.BlockSize,
                  Min(TExtensionMetadata.BlockSize,
                      tmp.Len - md.Piece * TExtensionMetadata.BlockSize))
            ));
          end;

        mmtData:
          begin
            FMetafileMap.Add(md.Piece, md.Metadata);
            { check infohash }
            tmp.Len := 0;

            for i in FMetafileMap.Keys do
              tmp := tmp + FMetafileMap[i].Value;

            if tmp.Len = FMetadataSize then
            begin
              if SHA1(tmp) = FInfoHash then
              begin
                { hurray! metafile successfully loaded }
                InitMetadata(TMetaFile.Create(tmp) as IMetaFile);

                { отправляем bitfield всем! }
                for it in FPeers do
                  it.SendBitfield(FBitField);

                if Assigned(FOnMetadataLoaded) then
                  FOnMetadataLoaded(tmp);
              end else
              begin
                { sad :( }
                FMetafileMap.Clear;
                FMetadataSize := 0;
              end;
            end;
          end;

        mmtReject: { peer dont have this piece }
          begin
          end;
      end;
      {$ENDREGION}
    end else
    if Supports(AMessage, IExtensionComment) then
    begin
      Sleep(0);
    end;
  finally
    Unlock;
  end;
end;

procedure TSeeding.OnPeerInterest(APeer: IPeer);
begin
  Lock;
  try
    { смотрим, интересен ли он нам }
    { если мы полный источник или у него есть что-то для нас интересное -- расчокиваем }
    { наверное логично было бы проверять (APeer.Bitfield and not FHaveMask).TrueCount >= n }
    if (ssCompleted in FStates) or not (not APeer.Bitfield and FBitField).AllFalse then
      APeer.Unchoke;
  finally
    Unlock;
  end;
end;

procedure TSeeding.OnPeerPiece(APeer: IPeer; AIndex, AOffset: Integer;
  AData: TUniString);
var
  dat: TUniString;
  p: IPiece;
  it: IPeer;
begin
  Lock;
  try
    dat := AData; // напрямую дельфи не хочет работать, попросту падает компилятор
    Assert(dat.Len <= TPiece.BlockLength);

    if FPieces.ContainsKey(AIndex) then
    begin
      p := FPieces[AIndex];
      p.AddBlock(AOffset, dat);
    end else
    begin
      // newpiece
      p := TPiece.Create(AIndex, FMetafile.PieceLength[AIndex], AOffset, dat);
      FPieces.Add(AIndex, p);
    end;

    if p.Completed then
    begin
      try
        FFileSystem.PieceWrite(p);
      except
        on E: EFileSystemWriteException do
        begin
          FStates := [ssError];
          FPieces.Clear;
          raise;
        end;

        on E: EFileSystemCheckException do
        begin
          { выбрасываем кусок }
          FPieces.Remove(AIndex);
          Inc(FHashErrorCount);
          Exit;
        end;

        on E: Exception do
        begin
          FStates := [ssError];
          FPieces.Clear;
          raise;
        end;
      end;

      FBitField[AIndex] := True; { делаем отметку, что кусок загружен }
      FDownloadQueue.Dequeue(AIndex); { выбрасываем из буфера закачек }

      for it in FPeers do
        {if it.HaveMask[AIndex] then  (типа разослать только тем, у кого есть кусок?)}
        it.SendHave(AIndex);

      FPieces.Remove(AIndex);

      { всё загружено? }
      if FBitField.AllTrue then
      begin
        FStates := FStates + [ssCompleted] - [ssDownloading];

        { мы всё загрузили, нам больше никто не интересен }
        for it in FPeers do
          if pfWeInterested in it.Flags then
            it.NotInterested;
      end;
    end else
      FDownloadQueue.Touch(AIndex); { продлеваем жизнь запрашиваемому куску }
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

    { добавляем в очередь на отправку }
    //DebugOutput(Format('add peer request piece=%d offset=%d size=%d', [APieceIndex, AOffset, ASize]));
    FUploadQueue.Enqueue(APieceIndex, AOffset, ASize, APeer);
  finally
    Unlock;
  end;
end;

procedure TSeeding.SetOnMetadataLoaded(Value: TProc<TUniString>);
begin
  FOnMetadataLoaded := Value;
end;

procedure TSeeding.Touch;
begin
  Lock;
  try
    FLastRequest := UtcNow;
    FStates := FStates + [ssActive];
  finally
    Unlock;
  end;
end;

procedure TSeeding.DoSync;
var
  peer: IPeer;
  tr: ITracker;
  want: TBitField;
  haveMD,
  weLoad,
  alive: Boolean;
begin
  Lock;
  try
    if not(ssActive in FStates) then
      Exit;

    haveMD  := ssHaveMetadata in FStates;
    weLoad  := ssDownloading  in FStates;
    alive   := False;

    if haveMD and weLoad then
    begin
      { вынести бы в ф-ю, чтобы каждый раз не мозолить }
      want := not FBitField;
      want := want and not FDownloadQueue.AsBitfield;
    end;

    for tr in FTrackers do
      if not tr.Busy then
      begin

        tr.Sync;
      end;

    for peer in FPeers do
      if not peer.Busy then
      begin
        { соединение (хендшейк пройден) установлено успешно и у нас есть метаданные }
        if peer.Connected and haveMD then
        begin
          { мы чето качаем }
          if weLoad then
          begin
            { он нам интересен, просим нас раздушить }
            if not (pfWeInterested in peer.Flags) and
                   (peer.Bitfield.Len > 0) and
                   (TBitField(want and peer.Bitfield).CheckedCount > 0) then
              peer.Interested;

            Assert(Assigned(FDownloadQueue));
            FDownloadQueue.Timeout; { проверка таймаута }

            { мы не зачоканы -- он готов нам отдавать }
            if (not (pfTheyChoke in peer.Flags)) and FDownloadQueue.CanEnqueue(peer) then
            begin
              FPiecePicker.PickPiece(peer, FPeers, want,
                procedure (APieceIndex: Integer)
                var
                  offset, size, len: Integer;
                begin
                  FDownloadQueue.Enqueue(APieceIndex, peer);

                  offset:= 0;
                  size  := FMetafile.PieceLength[APieceIndex];

                  while size > 0 do
                  begin
                    len := Min(TPiece.BlockLength, size);
                    peer.Request(APieceIndex, offset, len);

                    Inc(offset, len);
                    Dec(size  , len);
                  end;
                end);
            end;

            alive := True;
          end;
          { раздаем, если есть что }
          FUploadQueue.Dequeue(peer, procedure (APeer: IPeer; APiece, AOffset, ASize: Integer)
          var
            p: IPiece;
            data: TUniString;
          begin
            data.Len := 0;

            p := FFileSystem.Piece[APiece];
            Assert(Assigned(p));

            data := p.Data.Copy(AOffset, ASize);

            APeer.SendPiece(APiece, AOffset, data);
            //DebugOutput(Format('send piece=%d offset=%d size=%d', [APiece, AOffset, ASize]));

            alive := True;
          end);
        end;

        { здесь нужно проверять всякие рейтинги и т.д.
          Если с нас запрашивают больше, чем отдают -- душим }
        peer.Sync;
      end;

    if haveMD then
      FFileSystem.ClearCaches;

    if alive then
      Touch
    else
    if MinutesBetween(UtcNow, FLastRequest) >= MaxIdleTime then
      { ничего не качаем и ничего не раздаем -- переводим раздачу в пассивный режим }
      FStates := FStates - [ssActive];
  finally
    Unlock;
  end;
end;

procedure TSeeding.Unlock;
begin
  System.TMonitor.Exit(FLock);
end;

{ TSeeding.TDownloadPieceQueue }

constructor TSeeding.TDownloadPieceQueue.Create(APieceCount: Integer;
  AOnTimeout: TProc<Integer, IPeer>);
begin
  inherited Create;

  FList       := System.Generics.Collections.TList<TDownloadPieceQueueItem>.Create;
  FBitField   := TBitfield.Create(APieceCount);
  FOnTimeout  := AOnTimeout;
end;

procedure TSeeding.TDownloadPieceQueue.Dequeue(APiece: Integer);
var
  it: TDownloadPieceQueueItem;
begin
  for it in FList do
    if it.Piece = APiece then
    begin
      FList.Remove(it);
      FBitField[APiece] := False;
      Break;
    end;
end;

destructor TSeeding.TDownloadPieceQueue.Destroy;
begin
  FList.Free;
  inherited;
end;

procedure TSeeding.TDownloadPieceQueue.Enqueue(APiece: Integer; APeer: IPeer);
begin
  Assert(CanEnqueue(APeer));
  FList.Add(TDownloadPieceQueueItem.Create(APeer, APiece));
  FBitField[APiece] := True;
end;

function TSeeding.TDownloadPieceQueue.GetAsBitfield: TBitField;
begin
  Result := FBitField;
end;

procedure TSeeding.TDownloadPieceQueue.CancelRequests(APeer: IPeer);
var
  i: Integer;
begin
  for i := FList.Count - 1 downto 0 do
    with FList[i] do
      if Peer.HashCode = APeer.HashCode then
        FList.Delete(i);
end;

function TSeeding.TDownloadPieceQueue.CanEnqueue(APeer: IPeer): Boolean;
var
  it: TDownloadPieceQueueItem;
  i: Integer;
begin
  Result := FList.Count < MaxPieceQueueSize;

  if Result and Assigned(APeer) then
  begin
    i := 0;

    for it in FList do
      if it.Peer.HashCode = APeer.HashCode then
      begin
        Inc(i);

        if i >= MaxPeerPiecesCount then
          Exit(False);
      end;
  end;
end;

procedure TSeeding.TDownloadPieceQueue.Timeout;
var
  it: TDownloadPieceQueueItem;
begin
  for it in FList do
    if SecondsBetween(UtcNow, it.TimeStamp) > MaxPieceQueueTimeout then
    begin
      FList.Remove(it);
      FBitField[it.Piece] := False;

      if Assigned(FOnTimeout) then
        FOnTimeout(it.Piece, it.Peer);

      Break;
    end;
end;

procedure TSeeding.TDownloadPieceQueue.Touch(APiece: Integer);
var
  it, it2: TDownloadPieceQueueItem;
begin
  for it in FList do
    if it.Piece = APiece then
    begin
      it2 := it;
      it2.TimeStamp := UtcNow;

      FList.Remove(it);
      FList.Add(it2);

      Break;
    end;
end;

{ TSeeding.TDownloadPieceQueue.TDownloadPieceQueue }

constructor TSeeding.TDownloadPieceQueue.TDownloadPieceQueueItem.Create(
  APeer: IPeer; APiece: Integer);
begin
  Peer := APeer;
  Piece := APiece;
  TimeStamp := UtcNow;
end;

{ TSeeding.TUploadPieceQueue }

procedure TSeeding.TUploadPieceQueue.CancelRequests(APeer: IPeer);
var
  i: Integer;
begin
  for i := FList.Count downto 0 do
    with FList[i] do
      if Peer.HashCode = APeer.HashCode then
        FList.Delete(i);
end;

constructor TSeeding.TUploadPieceQueue.Create;
begin
  inherited Create;
  FList := TList<TUploadPieceQueueItem>.Create;
end;

procedure TSeeding.TUploadPieceQueue.Dequeue(APeer: IPeer;
  ADequeueProc: TProc<IPeer, Integer, Integer, Integer>);
var
  it: TUploadPieceQueueItem;
  i, j: Integer;
begin
  if GetIsEmpty then
    Exit;

  Assert(Assigned(ADequeueProc));

  i := 0;
  j := -1;
  while i < FList.Count do
  begin
    { отдаем ему кусок целиком }
    it := FList[i];

    if (it.Peer.HashCode = APeer.HashCode) and ((j = -1) or (j = it.Piece)) then
    begin
      j := it.Piece;

      ADequeueProc(it.Peer, it.Piece, it.Offset, it.Size);
      FList.Delete(i);
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
  Result := FList.Count = 0;
end;

procedure TSeeding.TUploadPieceQueue.Reject(APeer: IPeer);
var
  i: Integer;
begin
  for i := FList.Count - 1 downto 0 do
    if FList[i].Peer.HashCode = APeer.HashCode then
      FList.Delete(i);
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
