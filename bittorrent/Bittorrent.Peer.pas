unit Bittorrent.Peer;

interface

uses
  System.SysUtils, System.Generics.Collections, System.Generics.Defaults,
  System.DateUtils, System.Hash,
  Basic.UniString,
  Common.BusyObj, Common.ThreadPool, Common.Prelude,
  Bittorrent, Bittorrent.Bitfield,
  IdGlobal, IdContext;

type
  TPeer = class(TBusy, IPeer)
  private
    const
      MaxSendQueueSize  = 500;
      MaxRecvQueueSize  = 100;
      KeepAliveInterval = 5;
      ConnectionTimeout = 60;
  protected
    FLock: TObject;
    FShutdown: Boolean;
    FInfoHash: TUniString;
    FOurClientID: TUniString;
    FClientID: TUniString;
    FConnection: IConnection;
    FBitfield: TBitField;
    FExtensionSupports: TArray<TExtensionItem>;
    FConnectionEstablished: Boolean;
    FFlags: TPeerFlags;
    FThreadPool: TThreadPool;
    FOnConnect: TProc<IPeer, IMessage>;
    FOnDisonnect: TProc<IPeer>;
    FOnChoke: TProc<IPeer>;
    FOnUnchoke: TProc<IPeer>;
    FOnInterest: TProc<IPeer>;
    FOnNotInterest: TProc<IPeer>;
    FOnStart: TProc<IPeer, TUniString, TBitField>;
    FOnHave: TProc<IPeer, Integer>;
    FOnRequestPiece: TProc<IPeer, Integer, Integer, Integer>;
    FOnPiece: TProc<IPeer, Integer, Integer, TUniString>;
    FOnCancel: TProc<IPeer, Integer, Integer>;
    FOnPort: TProc<IPeer, TIdPort>;
    FOnExtendedMessage: TProc<IPeer, IExtension>;
    FOnException: TProc<IPeer, Exception>;
    FOnUpdateCounter: TProc<IPeer, UInt64, UInt64>;
    FLastKeepAlive: TDateTime;
    FLastResponse: TDateTime;

    FLastRecvSize,
    FLastSentSize: UInt64;

    FSendQueue: TQueue<IMessage>;

    FHashCode: Integer;
  private
    function GetInfoHash: TUniString; inline;
    function GetClientID: TUniString; inline;
    function GetBitfield: TBitField; inline;
    function GetExtensionSupports: TArray<TExtensionItem>;
    function GetConnectionEstablished: Boolean; inline;
    function GetConnectionConnected: Boolean; inline;
    function GetFlags: TPeerFlags; inline;
    function GetOnConnect: TProc<IPeer, IMessage>; inline;
    procedure SetOnConnect(Value: TProc<IPeer, IMessage>); inline;
    function GetOnDisonnect: TProc<IPeer>; inline;
    procedure SetOnDisconnect(Value: TProc<IPeer>); inline;
    function GetOnChoke: TProc<IPeer>; inline;
    procedure SetOnChoke(Value: TProc<IPeer>); inline;
    function GetOnUnchoke: TProc<IPeer>; inline;
    procedure SetOnUnchoke(Value: TProc<IPeer>); inline;
    function GetOnInterest: TProc<IPeer>; inline;
    procedure SetOnInterest(Value: TProc<IPeer>); inline;
    function GetOnNotInerest: TProc<IPeer>; inline;
    procedure SetOnNotInerest(Value: TProc<IPeer>); inline;
    function GetOnStart: TProc<IPeer, TUniString, TBitField>; inline;
    procedure SetOnStart(Value: TProc<IPeer, TUniString, TBitField>); inline;
    function GetOnHave: TProc<IPeer, Integer>; inline;
    procedure SetOnHave(Value: TProc<IPeer, Integer>); inline;
    function GetOnRequest: TProc<IPeer, Integer, Integer, Integer>; inline;
    procedure SetOnRequest(Value: TProc<IPeer, Integer, Integer, Integer>); inline;
    function GetOnPiece: TProc<IPeer, Integer, Integer, TUniString>; inline;
    procedure SetOnPiece(Value: TProc<IPeer, Integer, Integer, TUniString>); inline;
    function GetOnCancel: TProc<IPeer, Integer, Integer>; inline;
    procedure SetOnCancel(Value: TProc<IPeer, Integer, Integer>); inline;
    function GetOnPort: TProc<IPeer, TIdPort>; inline;
    procedure SetOnPort(Value: TProc<IPeer, TIdPort>); inline;
    function GetOnExtendedMessage: TProc<IPeer, IExtension>;
    procedure SetOnExtendedMessage(Value: TProc<IPeer, IExtension>);
    function GetOnException: TProc<IPeer, Exception>; inline;
    procedure SetOnException(Value: TProc<IPeer, Exception>); inline;
    function GetOnUpdateCounter: TProc<IPeer, UInt64, UInt64>; inline;
    procedure SetOnUpdateCounter(Value: TProc<IPeer, UInt64, UInt64>); inline;

    function GetHost: string; inline;
    function GetPort: TIdPort; inline;
    function GetIPVer: TIdIPVersion; inline;
    function GetConnectionType: TConnectionType; inline;
    function GetBytesSent: UInt64; inline;
    function GetBytesReceived: UInt64; inline;
    function GetRate: Single; inline;

    procedure UpdateCounter; inline;

    procedure Lock; inline;
    procedure Unlock; inline;

    // messages
    procedure KeepAlive; inline;
    procedure Interested; inline;
    procedure NotInterested; inline;
    procedure Choke; inline;
    procedure Unchoke; inline;
    procedure Request(AIndex, AOffset, ALength: Integer); inline;
    procedure Cancel(AIndex, AOffset: Integer); inline;
    procedure SendHave(AIndex: Integer); inline;
    procedure SendBitfield(const ABitfield: TBitField); inline;
    procedure SendPiece(APieceIndex, AOffset: Integer;
      const ABlock: TUniString); inline;
    procedure SendExtensionMessage(AExtension: IExtension);
    procedure SendPort(APort: TIdPort); inline;

    function GetHandshakeMessage: IMessage; inline;

    procedure Disconnect; inline;
    procedure Shutdown; inline;

    procedure ConnectOutgoing; { отправка и прием хендшейка наружу }
    procedure ConnectIncoming; { прием и отправка хендшейка извне }

    procedure RaiseInvalidPeer; inline;

    procedure DoHandleMessage(AMessage: IMessage); inline;
    procedure DoHandleHandShakeMessage(AMessage: IMessage); inline;
    procedure DoChoke; inline;
    procedure DoUnchoke; inline;
    procedure DoInterested; inline;
    procedure DoNotInterested; inline;
    procedure DoHave(APieceIndex: Integer); inline;
    procedure DoStart(const ABitField: TBitField); inline;
    procedure DoRequest(APieceIndex, AOffset, ASize: Integer); inline;
    procedure DoPiece(APieceIndex, AOffset: Integer; const ABlock: TUniString); inline;
    procedure DoCancel(APieceIndex, AOffset: Integer); inline;
    procedure DoPort(APort: TIdPort); inline;
    procedure DoExtendedMessage(AExtension: IExtension);
    procedure DoDisconnect;
  protected
    procedure DoSync; override; final;
  public
    constructor Create(AThreadPoolEx: TThreadPool; const AHost: string;
      APort: TIdPort; const AInfoHash, AClientID: TUniString;
      AIPVer: TIdIPVersion = Id_IPv4); overload;

    constructor Create(AThreadPoolEx: TThreadPool;
      AConnection: IConnection; const AOurClientID: TUniString); overload;

    destructor Destroy; override;

    function GetHashCode: Integer; override;
  end;

implementation

uses
  Bittorrent.Messages, Bittorrent.Connection;

{ TPeer }

procedure TPeer.ConnectIncoming;
var
  msg: IMessage;
begin
  { итак в критической секции }
  try
    msg := FConnection.ReceiveMessage(True);
    { проверки }
    Assert(Assigned(msg));
    DoHandleHandShakeMessage(msg);

    if Assigned(FOnConnect) then
      FOnConnect(Self, msg);

    { отсылаем ответный хендшейк, если FOnConnect не сгенерил исключение }
    FConnection.SendMessage(GetHandshakeMessage);

    FConnectionEstablished := True; { успешно! }
    FLastResponse   := Now;
    FLastKeepAlive  := Now;
  except
    FConnection.Disconnect;
    RaiseInvalidPeer;
  end;
end;

procedure TPeer.ConnectOutgoing;
var
  msg: IMessage;
begin
  FConnection.Connect;
  try
    { отсылаем хендшейк и ждем ответ }
    FConnection.SendMessage(GetHandshakeMessage);

    msg := FConnection.ReceiveMessage(True);
    Assert(Assigned(msg));
    DoHandleHandShakeMessage(msg);

    if Assigned(FOnConnect) then
      FOnConnect(Self, msg);

    FConnectionEstablished := True; { успешно! }
    FLastResponse   := Now;
    FLastKeepAlive  := FLastResponse;
  except
    FConnection.Disconnect;
    RaiseInvalidPeer;
  end;
end;

constructor TPeer.Create(AThreadPoolEx: TThreadPool; AConnection: IConnection;
  const AOurClientID: TUniString);
begin
  inherited Create;

  FLock             := TObject.Create;
  FShutdown         := False;

  FLastRecvSize     := 0;
  FLastSentSize     := 0;

  FConnection       := AConnection;
  FConnection.OnDisconnect := DoDisconnect;

  FOurClientID      := AOurClientID;

  FThreadPool       := AThreadPoolEx;
  FConnectionEstablished := False;

  FFlags            := [pfWeChoke, pfTheyChoke];
  FHashCode         := THashBobJenkins.GetHashValue(AConnection.Host + ':' + AConnection.Port.ToString);
  FSendQueue        := TQueue<IMessage>.Create;
end;

constructor TPeer.Create(AThreadPoolEx: TThreadPool; const AHost: string;
  APort: TIdPort; const AInfoHash, AClientID: TUniString; AIPVer: TIdIPVersion);
begin
  Create(AThreadPoolEx, TOutgoingConnection.Create(AHost, APort, AIPVer), AClientID);

  FInfoHash.Assign(AInfoHash);
  FClientID.Assign(AClientID);
end;

destructor TPeer.Destroy;
begin
  if (FConnection.ConnectionType = ctOutgoing) and FConnection.Connected then
    FConnection.Disconnect;

  FSendQueue.Free;
  FLock.Free;
  inherited;
end;

procedure TPeer.Disconnect;
begin
  FConnection.Disconnect;
  FConnectionEstablished := False;
end;

function TPeer.GetClientID: TUniString;
begin
  Result := FClientID;
end;

function TPeer.GetConnectionConnected: Boolean;
begin
  Result := FConnection.Connected;
end;

function TPeer.GetConnectionEstablished: Boolean;
begin
  Result := FConnectionEstablished;
end;

function TPeer.GetConnectionType: TConnectionType;
begin
  Result := FConnection.ConnectionType;
end;

function TPeer.GetExtensionSupports: TArray<TExtensionItem>;
begin
  Result := FExtensionSupports;
end;

function TPeer.GetFlags: TPeerFlags;
begin
  Result := FFlags;
end;

function TPeer.GetBitfield: TBitField;
begin
  Result := FBitfield;
end;

function TPeer.GetBytesReceived: UInt64;
begin
  Result := FConnection.BytesReceived;
end;

function TPeer.GetBytesSent: UInt64;
begin
  Result := FConnection.BytesSent;
end;

function TPeer.GetHandshakeMessage: IMessage;
begin
  Result := THandshakeMessage.Create(FInfoHash, FOurClientID, True, False, True);
end;

function TPeer.GetHashCode: Integer;
begin
  Result := FHashCode;
end;

function TPeer.GetHost: string;
begin
  Result := FConnection.Host;
end;

function TPeer.GetInfoHash: TUniString;
begin
  Result := FInfoHash;
end;

function TPeer.GetIPVer: TIdIPVersion;
begin
  Result := FConnection.IPVer;
end;

function TPeer.GetOnStart: TProc<IPeer, TUniString, TBitField>;
begin
  Result := FOnStart;
end;

function TPeer.GetOnCancel: TProc<IPeer, Integer, Integer>;
begin
  Result := FOnCancel;
end;

function TPeer.GetOnChoke: TProc<IPeer>;
begin
  Result := FOnChoke;
end;

function TPeer.GetOnConnect: TProc<IPeer, IMessage>;
begin
  Result := FOnConnect;
end;

function TPeer.GetOnDisonnect: TProc<IPeer>;
begin
  Result := FOnDisonnect;
end;

function TPeer.GetOnException: TProc<IPeer, Exception>;
begin
  Result := FOnException;
end;

function TPeer.GetOnExtendedMessage: TProc<IPeer, IExtension>;
begin
  Result := FOnExtendedMessage;
end;

function TPeer.GetOnHave: TProc<IPeer, Integer>;
begin
  Result := FOnHave;
end;

function TPeer.GetOnInterest: TProc<IPeer>;
begin
  Result := FOnInterest;
end;

function TPeer.GetOnNotInerest: TProc<IPeer>;
begin
  Result := FOnNotInterest;
end;

function TPeer.GetOnPiece: TProc<IPeer, Integer, Integer, TUniString>;
begin
  Result := FOnPiece;
end;

function TPeer.GetOnPort: TProc<IPeer, TIdPort>;
begin
  Result := FOnPort;
end;

function TPeer.GetOnRequest: TProc<IPeer, Integer, Integer, Integer>;
begin
  Result := FOnRequestPiece;
end;

function TPeer.GetOnUnchoke: TProc<IPeer>;
begin
  Result := FOnUnchoke;
end;

function TPeer.GetOnUpdateCounter: TProc<IPeer, UInt64, UInt64>;
begin
  Result := FOnUpdateCounter;
end;

function TPeer.GetPort: TIdPort;
begin
  Result := FConnection.Port;
end;

function TPeer.GetRate: Single;
begin
  Result := GetBytesSent / GetBytesReceived;
end;

procedure TPeer.DoHandleHandShakeMessage(AMessage: IMessage);
begin
  Assert(Supports(AMessage, IHandshakeMessage));

  with AMessage as IHandshakeMessage do
  begin
    case FConnection.ConnectionType of
      ctOutgoing: Assert(FInfoHash = InfoHash);
      ctIncoming: FInfoHash.Assign(InfoHash);
    end;

    FClientID.Assign(PeerID);
  end;
end;

procedure TPeer.SendBitfield(const ABitfield: TBitField);
begin
  Enter;
  try
    FSendQueue.Enqueue(TBitfieldMessage.Create(ABitfield));
  finally
    Leave;
  end;
end;

procedure TPeer.SendExtensionMessage(AExtension: IExtension);
var
  it: TExtensionItem;
begin
  Enter;
  try
    {TODO -oMAD -cMedium : вносить хендшейковский идентификатор в список}
    if Supports(AExtension, IExtensionHandshake) then
      FSendQueue.Enqueue(TExtensionMessage.Create(TExtensionMessage.HandshakeMsgID,
        AExtension))
    else
      for it in FExtensionSupports do
        if it.Name.Equals(AExtension.SupportName) then
        begin
          FSendQueue.Enqueue(TExtensionMessage.Create(it.MsgID, AExtension));
          Break;
        end;
  finally
    Leave;
  end;
end;

procedure TPeer.SendHave(AIndex: Integer);
begin
  Enter;
  try
    FSendQueue.Enqueue(THaveMessage.Create(AIndex));
  finally
    Leave;
  end;
end;

procedure TPeer.Cancel(AIndex, AOffset: Integer);
begin
  Enter;
  try
    {TODO -oMAD -cMedium : Добавить 3-й параметр}
    FSendQueue.Enqueue(TCancelMessage.Create(AIndex, AOffset, 0));
  finally
    Leave;
  end;
end;

procedure TPeer.Choke;
begin
  Enter;
  try
    FSendQueue.Enqueue(TChokeMessage.Create);
    FFlags := FFlags + [pfWeChoke];
  finally
    Leave;
  end;
end;

procedure TPeer.Interested;
begin
  Enter;
  try
    FSendQueue.Enqueue(TInterestedMessage.Create);
    FFlags := FFlags + [pfWeInterested];
  finally
    Leave;
  end;
end;

procedure TPeer.KeepAlive;
begin
  Enter;
  try
    FSendQueue.Enqueue(TKeepAliveMessage.Create);
  finally
    Leave;
  end;
end;

procedure TPeer.Lock;
begin
  _AddRef;
  TMonitor.Enter(FLock);
end;

procedure TPeer.NotInterested;
begin
  Enter;
  try
    FSendQueue.Enqueue(TNotInterestedMessage.Create);
    FFlags := FFlags - [pfWeInterested];
  finally
    Leave;
  end;
end;

procedure TPeer.SendPiece(APieceIndex, AOffset: Integer;
  const ABlock: TUniString);
begin
  Enter;
  try
    FSendQueue.Enqueue(TPieceMessage.Create(APieceIndex, AOffset, ABlock));
  finally
    Leave;
  end;
end;

procedure TPeer.SendPort(APort: TIdPort);
begin
  Enter;
  try
    FSendQueue.Enqueue(TPortMessage.Create(APort));
  finally
    Leave;
  end;
end;

procedure TPeer.RaiseInvalidPeer;
begin
  raise EPeerInvalidPeer.Create('Invalid peer');
end;

procedure TPeer.Request(AIndex, AOffset, ALength: Integer);
begin
  Enter;
  try
    FSendQueue.Enqueue(TRequestMessage.Create(AIndex, AOffset, ALength));
  finally
    Leave;
  end;
end;

procedure TPeer.Unchoke;
begin
  Enter;
  try
    FSendQueue.Enqueue(TUnchokeMessage.Create);
    FFlags := FFlags - [pfWeChoke];
  finally
    Leave;
  end;
end;

procedure TPeer.Unlock;
begin
  TMonitor.Exit(FLock);
  _Release;
end;

procedure TPeer.UpdateCounter;
var
  dDelta, uDelta: UInt64;
begin
  dDelta := FConnection.BytesReceived - FLastRecvSize;
  uDelta := FConnection.BytesSent     - FLastSentSize;

  FLastRecvSize := FConnection.BytesReceived;
  FLastSentSize := FConnection.BytesSent;

  if Assigned(FOnUpdateCounter) then
    FOnUpdateCounter(Self, dDelta, uDelta);
end;

procedure TPeer.SetOnStart(Value: TProc<IPeer, TUniString, TBitField>);
begin
  FOnStart := Value;
end;

procedure TPeer.SetOnCancel(Value: TProc<IPeer, Integer, Integer>);
begin
  FOnCancel := Value;
end;

procedure TPeer.SetOnChoke(Value: TProc<IPeer>);
begin
  FOnChoke := Value;
end;

procedure TPeer.SetOnConnect(Value: TProc<IPeer, IMessage>);
begin
  FOnConnect := Value;
end;

procedure TPeer.SetOnDisconnect(Value: TProc<IPeer>);
begin
  FOnDisonnect := Value;
end;

procedure TPeer.SetOnException(Value: TProc<IPeer, Exception>);
begin
  FOnException := Value;
end;

procedure TPeer.SetOnExtendedMessage(Value: TProc<IPeer, IExtension>);
begin
  FOnExtendedMessage := Value;
end;

procedure TPeer.SetOnHave(Value: TProc<IPeer, Integer>);
begin
  FOnHave := Value;
end;

procedure TPeer.SetOnInterest(Value: TProc<IPeer>);
begin
  FOnInterest := Value;
end;

procedure TPeer.SetOnNotInerest(Value: TProc<IPeer>);
begin
  FOnNotInterest := Value;
end;

procedure TPeer.SetOnPiece(Value: TProc<IPeer, Integer, Integer, TUniString>);
begin
  FOnPiece := Value;
end;

procedure TPeer.SetOnPort(Value: TProc<IPeer, TIdPort>);
begin
  FOnPort := Value;
end;

procedure TPeer.SetOnRequest(Value: TProc<IPeer, Integer, Integer, Integer>);
begin
  FOnRequestPiece := Value;
end;

procedure TPeer.SetOnUnchoke(Value: TProc<IPeer>);
begin
  FOnUnchoke := Value;
end;

procedure TPeer.SetOnUpdateCounter(Value: TProc<IPeer, UInt64, UInt64>);
begin
  FOnUpdateCounter := Value;
end;

procedure TPeer.Shutdown;
begin
  Lock;
  try
    Disconnect;
    FShutdown := True;
  finally
    Unlock;
  end;
end;

procedure TPeer.DoStart(const ABitField: TBitField);
begin
  FBitfield := ABitField;

  if Assigned(FOnStart) then
    FOnStart(Self, FInfoHash, ABitField);
end;

procedure TPeer.DoCancel(APieceIndex, AOffset: Integer);
begin
  if Assigned(FOnCancel) then
    FOnCancel(Self, APieceIndex, AOffset);
end;

procedure TPeer.DoChoke;
begin
  FFlags := FFlags + [pfTheyChoke];

  if Assigned(FOnChoke) then
    FOnChoke(Self);
end;

procedure TPeer.DoDisconnect;
begin
  if Assigned(FOnDisonnect) then
    FOnDisonnect(Self);
end;

procedure TPeer.DoExtendedMessage(AExtension: IExtension);
var
  hs: IExtensionHandshake;
begin
  if Supports(AExtension, IExtensionHandshake, hs) then
    FExtensionSupports := TPrelude.Map<string, TExtensionItem>(
      hs.Supports.Keys.ToArray, function (AName: string): TExtensionItem
      begin
        Result := TExtensionItem.Create(AName, hs.Supports[AName]);
      end);

  if Assigned(FOnExtendedMessage) then
    FOnExtendedMessage(Self, AExtension);
end;

procedure TPeer.DoHandleMessage(AMessage: IMessage);
begin
  Assert(Supports(AMessage, IFixedMessage));

  case (AMessage as IFixedMessage).MessageID of
    idChoke         :  { нас зачокали }
      DoChoke;
    idUnchoke       :  { нас расчокали }
      DoUnchoke;
    idInterested    :  { нами заинтересовались }
      DoInterested;
    idNotInterested :  { мы больше не интересны }
      DoNotInterested;
    idHave          :  { подтверждение передачи куска }
      with (AMessage as IHaveMessage) do
        DoHave(PieceIndex);
    idBitfield      :  { список кусков, которые он имеет }
      with (AMessage as IBitfieldMessage) do
        DoStart(BitField);
    idRequest       :  { с нас запросили куск/блок }
      with (AMessage as IRequestMessage) do
        DoRequest(PieceIndex, Offset, Size);
    idPiece         :  { прислали блок/кусок }
      with (AMessage as IPieceMessage) do
        DoPiece(PieceIndex, Offset, Block);
    idCancel        :  { отменяет свой запрос }
      with (AMessage as ICancelMessage) do
        DoCancel(PieceIndex, Offset);
    idPort          :
      with (AMessage as IPortMessage) do
        DoPort(Port);
    idExtended      :
      with (AMessage as IExtensionMessage) do
        DoExtendedMessage(Extension);
  else
    raise Exception.Create('Unknown message');
  end;
end;

procedure TPeer.DoHave(APieceIndex: Integer);
begin
  Assert(not FBitfield[APieceIndex]);

  { отмечаем в маске }
  FBitfield[APieceIndex] := True;

  if Assigned(FOnHave) then
    FOnHave(Self, APieceIndex);
end;

procedure TPeer.DoInterested;
begin
  if not (pfTheyInterested in FFlags) then
  begin
    { надо блочить пира, если он несколько раз подряд шлет Interested }
    FFlags := FFlags + [pfTheyInterested];

    if Assigned(FOnInterest) then
      FOnInterest(Self);
  end;
end;

procedure TPeer.DoNotInterested;
begin
  if pfTheyInterested in FFlags then
  begin
    FFlags := FFlags - [pfTheyInterested];

    if Assigned(FOnNotInterest) then
      FOnNotInterest(Self);
  end;
end;

procedure TPeer.DoPiece(APieceIndex, AOffset: Integer; const ABlock: TUniString);
begin
  if Assigned(FOnPiece) then
    FOnPiece(Self, APieceIndex, AOffset, ABlock);
end;

procedure TPeer.DoPort(APort: TIdPort);
begin
  if Assigned(FOnPort) then
    FOnPort(Self, APort);
end;

procedure TPeer.DoRequest(APieceIndex, AOffset, ASize: Integer);
begin
  if Assigned(FOnRequestPiece) then
    FOnRequestPiece(Self, APieceIndex, AOffset, ASize);
end;

procedure TPeer.DoSync;
begin
  Enter;

  if not FShutdown then
    FThreadPool.Exec(function : Boolean
  var
    msg: IMessage;
    i: Integer;
    t: TDateTime;
  begin
    Lock;
    try
      if GetConnectionConnected and GetConnectionEstablished then
      begin
        t := Now;
        if SecondsBetween(t, FLastKeepAlive) >= KeepAliveInterval then
        begin
          KeepAlive;
          FLastKeepAlive := t;
        end;

        { долго молчит -- отпинываем }
        if SecondsBetween(t, FLastResponse) >= ConnectionTimeout then
        begin
          FConnection.Disconnect;
          raise EPeerConnectionTimeout.Create('Connection timeout');
        end;

        { выплёвываем очередь сообщений в сеть (не даем отправить более MaxSendQueueSize сообщений) }
        i := 0;
        while (FSendQueue.Count > 0) and (i < MaxSendQueueSize) and GetConnectionConnected do
        begin
          FConnection.SendMessage(FSendQueue.Dequeue);
          Inc(i);
        end;

        { пытаемся принять MaxRecvQueueSize сообщений }
        i := 0;
        while (i < MaxRecvQueueSize) and GetConnectionConnected do
        begin
          msg := FConnection.ReceiveMessage;
          if Assigned(msg) then
            DoHandleMessage(msg)
          else
            Break;

          Inc(i);
        end;

        { обновить время последнего ответа }
        if i > 0 then // small optimization against frequent call's of UtcNow
          FLastResponse := t;

        UpdateCounter; // обновляем счетчик трафика
      end else
      if not FShutdown then
      case FConnection.ConnectionType of { контолируем соединение }
        ctIncoming:
          if GetConnectionConnected and not GetConnectionEstablished then
            ConnectIncoming; // к нам подключились -- начинаем диалог

        ctOutgoing:
          if not GetConnectionConnected or not GetConnectionEstablished then
            ConnectOutgoing; // мы цепляемся
      end;
    except
      on E: Exception do
      begin
        if Assigned(FOnException) then
          FOnException(Self, E);
      end;
    end;

    Leave;
    Unlock;

    Result := False;
  end);
end;

procedure TPeer.DoUnchoke;
begin
  FFlags := FFlags - [pfTheyChoke];

  if Assigned(FOnUnchoke) then
    FOnUnchoke(Self);
end;

end.
