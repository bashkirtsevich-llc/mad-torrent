unit Bittorrent.Connection;

interface

uses
  System.SysUtils,
  Bittorrent,
  IdGlobal, IdTCPClient, IdTCPConnection, IdComponent, IdIOHandler;

type
  TConnection = class abstract(TInterfacedObject, IConnection)
  private
    const
      HandshakeReadTimeout  = 10000;  { 10 секунд на хендшейк }
      MessagesReadTimeout   = 1;      { 1 миллисекунда на остальные сообщения }
  private
    FOnDisconnect: TProc;
    FBytesSend,
    FBytesReceived: UInt64;

    procedure OnConnectionDiconnected(Sender: TObject);

    procedure Disconnect; inline;

    procedure SendMessage(AMessage: IMessage); inline;
    function ReceiveMessage(AHandshake: Boolean = False): IMessage;

    function GetConnected: Boolean; inline;
    function GetConnectionType: TConnectionType; inline;
    function GetBytesSend: UInt64; inline;
    function GetBytesReceived: UInt64; inline;
    function GetOnDisconnect: TProc; inline;
    procedure SetOnDisconnect(Value: TProc); inline;
  protected
    FTCPConnection: TIdTCPConnection;
    FConnectionType: TConnectionType;

    procedure Connect; virtual; abstract;
    function GetHost: string; virtual;
    function GetPort: TIdPort; virtual;
    function GetIPVer: TIdIPVersion; virtual;
  public
    constructor Create(AConnection: TIdTCPConnection);
    destructor Destroy; override;
  end;

  { соединение с внешним пиром }
  TOutgoingConnection = class abstract(TConnection)
  private
    FTCPClient: TIdTCPClient;
  protected
    procedure Connect; override;
    function GetHost: string; override;
    function GetPort: TIdPort; override;
    function GetIPVer: TIdIPVersion; override;
  public
    constructor Create(const AHost: string; APort: TIdPort;
      AIPVer: TIdIPVersion = Id_IPv4);
    destructor Destroy; override;
  end;

  { соединение извне }
  TIncomingConnection = class abstract(TConnection)
  protected
    procedure Connect; override;
  public
    constructor Create(AConnection: TIdTCPConnection);
  end;

implementation

uses
  Bittorrent.Messages;

{ TConnection }

procedure TConnection.SendMessage(AMessage: IMessage);
begin
  Inc(FBytesSend, AMessage.MsgSize);
  AMessage.Send(FTCPConnection.IOHandler);
end;

procedure TConnection.SetOnDisconnect(Value: TProc);
begin
  FOnDisconnect := Value;
end;

constructor TConnection.Create(AConnection: TIdTCPConnection);
begin
  inherited Create;

  FBytesSend      := 0;
  FBytesReceived  := 0;

  FTCPConnection := AConnection;
  FTCPConnection.OnDisconnected := OnConnectionDiconnected;
end;

destructor TConnection.Destroy;
begin
  if Assigned(FOnDisconnect) then
    FOnDisconnect;

  FTCPConnection.OnDisconnected := nil;
  inherited;
end;

procedure TConnection.Disconnect;
begin
  if GetConnected then
    FTCPConnection.Disconnect;
end;

function TConnection.GetBytesReceived: UInt64;
begin
  Result := FBytesReceived;
end;

function TConnection.GetBytesSend: UInt64;
begin
  Result := FBytesSend;
end;

function TConnection.GetConnected: Boolean;
begin
  // проверять состояние соединения
  Result := FTCPConnection.Connected;
end;

function TConnection.GetConnectionType: TConnectionType;
begin
  Result := FConnectionType;
end;

function TConnection.GetHost: string;
begin
  Result := FTCPConnection.Socket.Host;
end;

function TConnection.GetIPVer: TIdIPVersion;
begin
  Result := FTCPConnection.Socket.IPVersion;
end;

function TConnection.GetOnDisconnect: TProc;
begin
  Result := FOnDisconnect;
end;

function TConnection.GetPort: TIdPort;
begin
  Result := FTCPConnection.Socket.Port;
end;

procedure TConnection.OnConnectionDiconnected(Sender: TObject);
begin
  if Assigned(FOnDisconnect) then
    FOnDisconnect;
end;

function TConnection.ReceiveMessage(AHandshake: Boolean): IMessage;
begin
  // Readable -- достать из очереди очередной пакет (false, если ничего не удалось вытянуть)
  // IOHandler.InputBufferIsEmpty -- буфер для чтения не пуст
  with FTCPConnection do
    if ((AHandshake and IOHandler.Readable(HandshakeReadTimeout)) or
        IOHandler.Readable(MessagesReadTimeout)) or
        not IOHandler.InputBufferIsEmpty then
    begin
      if AHandshake then
        Result := THandshakeMessage.CreateFromIOHandler(IOHandler) as IMessage
      else
        Result := TFixedMessage.ParseMessage(IOHandler) as IMessage;

      Inc(FBytesReceived, Result.MsgSize);
    end else
      Result := nil;
end;

{ TOutgoingConnection }

procedure TOutgoingConnection.Connect;
begin
  if not GetConnected then
    TIdTCPClient(FTCPConnection).Connect;
end;

constructor TOutgoingConnection.Create(const AHost: string; APort: TIdPort;
  AIPVer: TIdIPVersion);
begin
  FTCPClient := TIdTCPClient.Create(nil);

  inherited Create(FTCPClient);

  FConnectionType := ctOutgoing;

  with FTCPClient do
  begin
    ConnectTimeout  := 5000;
    ReadTimeout     := 5000; { можно ли в 0 сбросить? }

    IPVersion := AIPVer;
    Host      := AHost;
    Port      := APort;
  end;
end;

destructor TOutgoingConnection.Destroy;
begin
  inherited;
  FTCPClient.Free;
end;

function TOutgoingConnection.GetHost: string;
begin
  Result := FTCPClient.Host;
end;

function TOutgoingConnection.GetIPVer: TIdIPVersion;
begin
  Result := FTCPClient.IPVersion;
end;

function TOutgoingConnection.GetPort: TIdPort;
begin
  Result := FTCPClient.Port;
end;

{ TIncomingConnection }

procedure TIncomingConnection.Connect;
begin
  { нечего делать, мы уже подключены }
end;

constructor TIncomingConnection.Create(AConnection: TIdTCPConnection);
begin
  inherited Create(AConnection);
  FConnectionType := ctIncoming;
end;

end.
