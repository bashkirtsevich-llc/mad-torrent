unit Bittorrent.Peer;

interface

uses
  System.SysUtils, System.Generics.Collections, System.Generics.Defaults,
  System.DateUtils,
  Spring.Collections,
  Bittorrent, Bittorrent.Bitfield, Bittorrent.Utils, BusyObj, Basic.UniString,
  ThreadPool,
  IdGlobal, IdContext;

type
  TPeer = class(TBusy, IPeer)
  private
    const
      KeepAliveInterval = 20;
      ConnectionTimeout = 30;
  private
    FConnection: IConnection;
    FInfoHash: TUniString;
    FBitfield: TBitField;
    FPeerID: string;
    FConnected: Boolean;
    FFlags: TPeerFlags;
    FThreadPool: TThreadPool;
    FOnConnect: TProc<IPeer, IMessage>;
    FOnChoke: TProc<IPeer>;
    FOnUnchoke: TProc<IPeer>;
    FOnInterest: TProc<IPeer>;
    FOnNotInterest: TProc<IPeer>;
    FOnBitField: TProc<TBitField>;
    FOnHave: TProc<Integer>;
    FOnRequestPiece: TProc<IPeer, Integer, Integer, Integer>;
    FOnPiece: TProc<IPeer, Integer, Integer, TUniString>;
    FOnCancel: TProc<IPeer, Integer, Integer, Integer>;
    FOnExtendedMessage: TProc<IPeer, IExtension>;
    FOnException: TProc<IPeer, Exception>;
    FLastKeepAlive: TDateTime;
    FLastResponse: TDateTime;

    FSendQueue: TQueue<IMessage>;

    FExteinsionSupports: IDictionary<string, Byte>;

    FHashCode: Integer;


    function GetBitfield: TBitField; inline;
    function GetConnected: Boolean; inline;
    function GetFlags: TPeerFlags; inline;
    function GetOnConnect: TProc<IPeer, IMessage>; inline;
    procedure SetOnConnect(Value: TProc<IPeer, IMessage>); inline;
    function GetOnChoke: TProc<IPeer>; inline;
    procedure SetOnChoke(Value: TProc<IPeer>); inline;
    function GetOnUnchoke: TProc<IPeer>; inline;
    procedure SetOnUnchoke(Value: TProc<IPeer>); inline;
    function GetOnInterest: TProc<IPeer>; inline;
    procedure SetOnInterest(Value: TProc<IPeer>); inline;
    function GetOnNotInerest: TProc<IPeer>; inline;
    procedure SetOnNotInerest(Value: TProc<IPeer>); inline;
    function GetOnBitField: TProc<TBitField>; inline;
    procedure SetOnBitField(Value: TProc<TBitField>); inline;
    function GetOnHave: TProc<Integer>; inline;
    procedure SetOnHave(Value: TProc<Integer>); inline;
    function GetOnRequest: TProc<IPeer, Integer, Integer, Integer>; inline;
    procedure SetOnRequest(Value: TProc<IPeer, Integer, Integer, Integer>); inline;
    function GetOnPiece: TProc<IPeer, Integer, Integer, TUniString>; inline;
    procedure SetOnPiece(Value: TProc<IPeer, Integer, Integer, TUniString>); inline;
    function GetOnCancel: TProc<IPeer, Integer, Integer, Integer>; inline;
    procedure SetOnCancel(Value: TProc<IPeer, Integer, Integer, Integer>); inline;
    function GetOnExtendedMessage: TProc<IPeer, IExtension>; inline;
    procedure SetOnExtendedMessage(Value: TProc<IPeer, IExtension>); inline;
    function GetOnException: TProc<IPeer, Exception>; inline;
    procedure SetOnException(Value: TProc<IPeer, Exception>); inline;

    function GetHost: string; inline;
    function GetPort: TIdPort; inline;
    function GetIPVer: TIdIPVersion; inline;
    function GetExteinsionSupports: IDictionary<string, Byte>; inline;

    // messages
    procedure KeepAlive; inline;
    procedure Interested; inline;
    procedure NotInterested; inline;
    procedure Choke; inline;
    procedure Unchoke; inline;
    procedure Request(AIndex, AOffset, ALength: Integer); inline;
    procedure SendHave(AIndex: Integer); inline;
    procedure SendBitfield(const ABitfield: TBitField); inline;
    procedure SendPiece(APieceIndex, AOffset: Integer; const ABlock: TUniString); inline;
    procedure SendExtensionMessage(AExtension: IExtension); inline;
    procedure SendPort(APort: TIdPort); inline;

    procedure ConnectOutgoing; { отправка и прием хендшейка наружу }
    procedure ConnectIncoming; { прием и отправка хендшейка извне }
  protected
    procedure DoSync; override;
  private
    procedure DoHandleMessage(AMessage: IMessage); inline;

    procedure DoChoke; inline;
    procedure DoUnchoke; inline;
    procedure DoInterested; inline;
    procedure DoNotInterested; inline;
    procedure DoHave(APieceIndex: Integer); inline;
    procedure DoBitfield(const ABitField: TBitField); inline;
    procedure DoRequest(APieceIndex, AOffset, ASize: Integer); inline;
    procedure DoPiece(APieceIndex, AOffset: Integer; const ABlock: TUniString); inline;
    procedure DoCancel(APieceIndex, AOffset, ASize: Integer); inline;
    procedure DoPort(APoert: TIdPort); inline;
    procedure DoExtended(AExtension: IExtension); inline;
  public
    constructor Create(AThreadPoolEx: TThreadPool; const AHost: string;
      APort: TIdPort; const AInfoHash: TUniString; const APeerID: string;
      AIPVer: TIdIPVersion = Id_IPv4); overload;
    constructor Create(AThreadPoolEx: TThreadPool; AConnection: IConnection;
      const APeerID: string); overload;
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
  try
    msg := FConnection.ReceiveMessage(True);
    { проверки }
    Assert(Assigned(msg));
    Assert(Supports(msg, IHandshakeMessage));

    if Assigned(FOnConnect) then
      FOnConnect(Self, msg);

    with msg as IHandshakeMessage do
    begin
      FConnection.SendMessage(THandshakeMessage.Create(InfoHash, FPeerID, True, False, True) as IMessage);
      FInfoHash.Assign(InfoHash);
      FPeerID := PeerID;
    end;

    FConnected        := True; { успешно! }
    FLastResponse     := UtcNow;
  except
    FConnection.Disconnect;
    raise Exception.Create('Invalid peer');
  end;
end;

procedure TPeer.ConnectOutgoing;
var
  msg: IMessage;
begin
  FConnection.Connect;
  try
    FConnection.SendMessage(THandshakeMessage.Create(FInfoHash, FPeerID, True, False, True) as IMessage);

    msg := FConnection.ReceiveMessage(True);
    { проверки }
    Assert(Assigned(msg));
    Assert(Supports(msg, IHandshakeMessage));

    if Assigned(FOnConnect) then
      FOnConnect(Self, msg);

    FConnected      := True; { успешно! }
    FLastResponse   := UtcNow;
    FLastKeepAlive  := UtcNow;
  except
    on E: Exception do
    begin
      FConnection.Disconnect;
      raise Exception.Create('Invalid peer');
    end;
  end;
end;

constructor TPeer.Create(AThreadPoolEx: TThreadPool; AConnection: IConnection;
  const APeerID: string);
var
  tmp: TUniString;
begin
  inherited Create;

  FConnection       := AConnection;

  FThreadPool       := AThreadPoolEx;
  FConnected        := False;

  FFlags            := [pfWeChoke, pfTheyChoke];
  FPeerID           := APeerID;

  tmp               := AConnection.Host;
  tmp               := tmp + AConnection.Port;
  FHashCode         := BobJenkinsHash(tmp.DataPtr[0]^, tmp.Len, 0);

  FSendQueue        := TQueue<IMessage>.Create;
end;

constructor TPeer.Create(AThreadPoolEx: TThreadPool; const AHost: string;
  APort: TIdPort; const AInfoHash: TUniString; const APeerID: string; AIPVer: TIdIPVersion);
begin
  Create(AThreadPoolEx, TOutgoingConnection.Create(AHost, APort, AIPVer), APeerID);

  FInfoHash.Assign(AInfoHash);
end;

destructor TPeer.Destroy;
begin
  FSendQueue.Free;
  inherited;
end;

function TPeer.GetConnected: Boolean;
begin
  Result := FConnected;
end;

function TPeer.GetExteinsionSupports: IDictionary<string, Byte>;
begin
  Result := FExteinsionSupports;
end;

function TPeer.GetFlags: TPeerFlags;
begin
  Result := FFlags;
end;

function TPeer.GetBitfield: TBitField;
begin
  Result := FBitfield;
end;

function TPeer.GetHashCode: Integer;
begin
  Result := FHashCode;
end;

function TPeer.GetHost: string;
begin
  Result := FConnection.Host;
end;

function TPeer.GetIPVer: TIdIPVersion;
begin
  Result := FConnection.IPVer;
end;

function TPeer.GetOnBitField: TProc<TBitField>;
begin
  Result := FOnBitField;
end;

function TPeer.GetOnCancel: TProc<IPeer, Integer, Integer, Integer>;
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

function TPeer.GetOnException: TProc<IPeer, Exception>;
begin
  Result := FOnException;
end;

function TPeer.GetOnExtendedMessage: TProc<IPeer, IExtension>;
begin
  Result := FOnExtendedMessage;
end;

function TPeer.GetOnHave: TProc<Integer>;
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

function TPeer.GetOnRequest: TProc<IPeer, Integer, Integer, Integer>;
begin
  Result := FOnRequestPiece;
end;

function TPeer.GetOnUnchoke: TProc<IPeer>;
begin
  Result := FOnUnchoke;
end;

function TPeer.GetPort: TIdPort;
begin
  Result := FConnection.Port;
end;

procedure TPeer.SendBitfield(const ABitfield: TBitField);
begin
  Enter;
  try
    FSendQueue.Enqueue(TBitfieldMessage.Create(ABitfield) as IMessage);
  finally
    Leave;
  end;
end;

procedure TPeer.SendExtensionMessage(AExtension: IExtension);
begin
  Enter;
  try
    FSendQueue.Enqueue(TExtensionMessage.Create(FExteinsionSupports, AExtension) as IMessage);
  finally
    Leave;
  end;
end;

procedure TPeer.SendHave(AIndex: Integer);
begin
  Enter;
  try
    FSendQueue.Enqueue(THaveMessage.Create(AIndex) as IMessage);
  finally
    Leave;
  end;
end;

procedure TPeer.Choke;
begin
  Enter;
  try
    FSendQueue.Enqueue(TChokeMessage.Create as IMessage);
    FFlags := FFlags + [pfWeChoke];
  finally
    Leave;
  end;
end;

procedure TPeer.Interested;
begin
  Enter;
  try
    FSendQueue.Enqueue(TInterestedMessage.Create as IMessage);
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

procedure TPeer.NotInterested;
begin
  Enter;
  try
    FSendQueue.Enqueue(TNotInterestedMessage.Create as IMessage);
    FFlags := FFlags - [pfWeInterested];
  finally
    Leave;
  end;
end;

procedure TPeer.SendPiece(APieceIndex, AOffset: Integer; const ABlock: TUniString);
begin
  Enter;
  try
    FSendQueue.Enqueue(TPieceMessage.Create(APieceIndex, AOffset, ABlock) as IMessage);
  finally
    Leave;
  end;
end;

procedure TPeer.SendPort(APort: TIdPort);
begin
  Enter;
  try
    FSendQueue.Enqueue(TPortMessage.Create(APort) as IMessage);
  finally
    Leave;
  end;
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
    FSendQueue.Enqueue(TUnchokeMessage.Create as IMessage);
    FFlags := FFlags - [pfWeChoke];
  finally
    Leave;
  end;
end;

procedure TPeer.SetOnBitField(Value: TProc<TBitField>);
begin
  FOnBitField := Value;
end;

procedure TPeer.SetOnCancel(Value: TProc<IPeer, Integer, Integer, Integer>);
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

procedure TPeer.SetOnException(Value: TProc<IPeer, Exception>);
begin
  FOnException := Value;
end;

procedure TPeer.SetOnExtendedMessage(Value: TProc<IPeer, IExtension>);
begin
  FOnExtendedMessage := Value;
end;

procedure TPeer.SetOnHave(Value: TProc<Integer>);
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

procedure TPeer.SetOnRequest(Value: TProc<IPeer, Integer, Integer, Integer>);
begin
  FOnRequestPiece := Value;
end;

procedure TPeer.SetOnUnchoke(Value: TProc<IPeer>);
begin
  FOnUnchoke := Value;
end;

procedure TPeer.DoBitfield(const ABitField: TBitField);
begin
  FBitfield := ABitField;

  if Assigned(FOnBitfield) then
    FOnBitfield(FBitfield);
end;

procedure TPeer.DoCancel(APieceIndex, AOffset, ASize: Integer);
begin
  if Assigned(FOnCancel) then
    FOnCancel(Self, APieceIndex, AOffset, ASize);
end;

procedure TPeer.DoChoke;
begin
  FFlags := FFlags + [pfTheyChoke];

  if Assigned(FOnChoke) then
    FOnChoke(Self);
end;

procedure TPeer.DoExtended(AExtension: IExtension);
begin
  if Supports(AExtension, IExtensionHandshake) then
    FExteinsionSupports := (AExtension as IExtensionHandshake).Supports;

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
        DoBitfield(Bits);
    idRequest       :  { с нас запросили куск/блок }
      with (AMessage as IRequestMessage) do
        DoRequest(PieceIndex, Offset, Size);
    idPiece         :  { прислали блок/кусок }
      with (AMessage as IPieceMessage) do
        DoPiece(PieceIndex, Offset, Block);
    idCancel        :  { отменяет свой запрос }
      with (AMessage as ICancelMessage) do
        DoCancel(PieceIndex, Offset, Size);
    idPort          :  { для ДХТ и чего-то там еще }
      with (AMessage as IPortMessage) do
        DoPort(Port);
    idExtended      :
      with (AMessage as IExtensionMessage) do
        DoExtended(Extension);
  else
    raise Exception.Create('Unknown message');
  end;
end;

procedure TPeer.DoHave(APieceIndex: Integer);
begin
  { отмечаем в маске и выбрасываем из очереди на отдачу }
  FBitfield[APieceIndex] := True;

  if Assigned(FOnHave) then
    FOnHave(APieceIndex);
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

procedure TPeer.DoPiece(APieceIndex, AOffset: Integer;
  const ABlock: TUniString);
begin
  if Assigned(FOnPiece) then
    FOnPiece(Self, APieceIndex, AOffset, ABlock);
end;

procedure TPeer.DoPort(APoert: TIdPort);
begin

end;

procedure TPeer.DoRequest(APieceIndex, AOffset, ASize: Integer);
begin
  if Assigned(FOnRequestPiece) then
    FOnRequestPiece(Self, APieceIndex, AOffset, ASize);
end;

procedure TPeer.DoSync;
begin
  Enter;

  FThreadPool.Exec(function : Boolean
  var
    msg: IMessage;
  begin
    try
      { контолируем соединение }
      if not GetConnected then
      begin
        if FConnection.ConnectionType = ctOutgoing then
          ConnectOutgoing
        else
          ConnectIncoming;
      end else
      begin
        if SecondsBetween(UtcNow, FLastKeepAlive) >= KeepAliveInterval then
        begin
          KeepAlive;
          FLastKeepAlive := UtcNow;
        end;

        { долго молчит -- отпинываем }
        if SecondsBetween(UtcNow, FLastResponse) >= ConnectionTimeout then
        begin
          FConnection.Disconnect;
          raise Exception.Create('Connection timeout');
        end;

        if FSendQueue.Count > 0 then
        begin
          FConnection.SendMessage(FSendQueue.Dequeue);
          { add to "WaitResponse" queue }
        end;

        msg := FConnection.ReceiveMessage;
        if Assigned(msg) then
        begin
          DoHandleMessage(msg);
          { обновить время последнего ответа }
          FLastResponse := UtcNow;
        end;
      end;
    except
      on E: Exception do
      begin
        if Assigned(FOnException) then
          FOnException(Self, E);
      end;
    end;

    Leave;
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
