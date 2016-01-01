unit Bittorrent.Connection;

interface

uses
  System.SysUtils, System.Math,
  Bittorrent,
  IdGlobal, IdTCPClient, IdComponent, IdIOHandler, IdTCPConnection, IdStack,
  IdIntercept, IdSocketHandle;

type
  TConnection = class abstract(TInterfacedObject, IConnection)
  strict private
    const
      HandshakeOutgoingTimeout  = 60000;  { 60 секунд на хендшейк }
      HandshakeIncomingTimeout  = 1000;   { 1 секунда на хендшейк }
      MessagesReadTimeout       = 1;      { 1 миллисекунда на остальные сообщения }
  private
    FConnectionType: TConnectionType;
    FOnDisconnect: TProc;
    FBytesSent,
    FBytesReceived: UInt64;

    procedure SendMessage(AMessage: IMessage); inline;
    function ReceiveMessage(AHandshake: Boolean = False): IMessage;

    function GetMsgTimeout(AHandshake: Boolean): Integer; inline;

    function GetConnectionType: TConnectionType; inline;
    function GetBytesSent: UInt64; inline;
    function GetBytesReceived: UInt64; inline;
    function GetOnDisconnect: TProc; inline;
    procedure SetOnDisconnect(Value: TProc); inline;
  strict protected
    procedure OnConnectionDiconnected(Sender: TObject);

    procedure Connect; virtual; abstract;
    procedure Disconnect; virtual; abstract;

    function ParseMessage(AIOHandler: TIdIOHandler;
      AHandshake: Boolean): IMessage; virtual;

    function GetIOHandler: TIdIOHandler; virtual; abstract;

    function GetConnected: Boolean; virtual; abstract;
    function GetHost: string; virtual; abstract;
    function GetPort: TIdPort; virtual; abstract;
    function GetIPVer: TIdIPVersion; virtual; abstract;
  strict protected
    constructor Create(AConnectionType: TConnectionType);
  public
    destructor Destroy; override;
  end;

  { соединение с внешним пиром }
  TOutgoingConnection = class(TConnection)
  strict private
    FTCPClient: TIdTCPClient;
  strict protected
    procedure Connect; override; final;
    procedure Disconnect; override; final;

    function GetIOHandler: TIdIOHandler; override; final;

    function GetConnected: Boolean; override; final;
    function GetHost: string; override; final;
    function GetPort: TIdPort; override; final;
    function GetIPVer: TIdIPVersion; override; final;
  public
    constructor Create(const AHost: string; APort: TIdPort;
      AIPVer: TIdIPVersion = Id_IPv4); reintroduce;
    destructor Destroy; override;
  end;

  { соединение извне }
  TIncomingConnection = class(TConnection)
  strict private
    FTCPConnection: TIdTCPConnection;
  strict protected
    procedure Connect; override; final;
    procedure Disconnect; override; final;

    function GetIOHandler: TIdIOHandler; override; final;

    function GetConnected: Boolean; override; final;
    function GetHost: string; override; final;
    function GetPort: TIdPort; override; final;
    function GetIPVer: TIdIPVersion; override; final;
  public
    constructor Create(ATCPConnection: TIdTCPConnection); reintroduce;
    destructor Destroy; override;
  end;

implementation

uses
  Bittorrent.Messages;

{ TConnection }

procedure TConnection.SendMessage(AMessage: IMessage);
begin
  Assert(GetConnected);

  Inc(FBytesSent, AMessage.MsgSize);
  AMessage.Send(GetIOHandler);
end;

procedure TConnection.SetOnDisconnect(Value: TProc);
begin
  FOnDisconnect := Value;
end;

constructor TConnection.Create(AConnectionType: TConnectionType);
begin
  inherited Create;

  FConnectionType := AConnectionType;
  FBytesSent      := 0;
  FBytesReceived  := 0;
end;

destructor TConnection.Destroy;
begin
  if Assigned(FOnDisconnect) then
    FOnDisconnect;

  inherited;
end;

function TConnection.GetBytesReceived: UInt64;
begin
  Result := FBytesReceived;
end;

function TConnection.GetBytesSent: UInt64;
begin
  Result := FBytesSent;
end;

function TConnection.GetConnectionType: TConnectionType;
begin
  Result := FConnectionType;
end;

function TConnection.GetMsgTimeout(AHandshake: Boolean): Integer;
var
  ct: TConnectionType;
begin
  if AHandshake then
  begin
    ct := GetConnectionType;
    Assert(ct in [ctOutgoing, ctIncoming]);

    case ct of
      ctOutgoing: Result := HandshakeOutgoingTimeout;
      ctIncoming: Result := HandshakeIncomingTimeout;
    else
                  Result := 0;
    end;
  end else
    Result := MessagesReadTimeout;
end;

function TConnection.GetOnDisconnect: TProc;
begin
  Result := FOnDisconnect;
end;

procedure TConnection.OnConnectionDiconnected(Sender: TObject);
begin
  if Assigned(FOnDisconnect) then
    FOnDisconnect;
end;

function TConnection.ParseMessage(AIOHandler: TIdIOHandler;
  AHandshake: Boolean): IMessage;
begin
  Result := TFixedMessage.ParseMessage(AIOHandler, AHandshake);
end;

function TConnection.ReceiveMessage(AHandshake: Boolean): IMessage;
var
  h: TIdIOHandler;
begin
  Assert(GetConnected);

  h := GetIOHandler;
  h.CheckForDataOnSource(GetMsgTimeout(AHandshake));

  if h.InputBufferIsEmpty then
    Result := nil
  else
  begin
    Result := ParseMessage(h, AHandshake);
    Inc(FBytesReceived, Result.MsgSize);
  end;
end;

{ TOutgoingConnection }

procedure TOutgoingConnection.Connect;
begin
  if not GetConnected then
    FTCPClient.Connect;
end;

constructor TOutgoingConnection.Create(const AHost: string; APort: TIdPort;
  AIPVer: TIdIPVersion);
begin
  inherited Create(ctOutgoing);

  FTCPClient := TIdTCPClient.Create(nil);

  with FTCPClient do
  begin
    ConnectTimeout  := 60000;
    ReadTimeout     := 60000; { можно ли в 0 сбросить? }

    OnDisconnected  := OnConnectionDiconnected;

    IPVersion := AIPVer;
    Port      := APort;

    TIdStack.IncUsage;
    try
      Host    := GStack.ResolveHost(AHost, AIPVer); // резольфим имя хоста в IP адрес
    finally
      TIdStack.DecUsage;
    end;
  end;
end;

destructor TOutgoingConnection.Destroy;
begin
  inherited;
  FTCPClient.Free;
end;

procedure TOutgoingConnection.Disconnect;
begin
  if GetConnected then
    FTCPClient.Disconnect;
end;

function TOutgoingConnection.GetConnected: Boolean;
begin
  Result := FTCPClient.Connected;
end;

function TOutgoingConnection.GetHost: string;
begin
  Result := FTCPClient.Host;
end;

function TOutgoingConnection.GetIOHandler: TIdIOHandler;
begin
  Result := FTCPClient.IOHandler;
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

constructor TIncomingConnection.Create(ATCPConnection: TIdTCPConnection);
begin
  inherited Create(ctIncoming);

  FTCPConnection := ATCPConnection;
  FTCPConnection.OnDisconnected := OnConnectionDiconnected;
end;

destructor TIncomingConnection.Destroy;
begin
  if GetConnected then
    Disconnect;

  FTCPConnection.Free;
  inherited;
end;

procedure TIncomingConnection.Disconnect;
begin
  FTCPConnection.Disconnect;
end;

function TIncomingConnection.GetConnected: Boolean;
begin
  // надо подсмотреть в инди, как там реализована проверка соединения
  Result := FTCPConnection.Connected and GetIOHandler.Opened;
end;

function TIncomingConnection.GetHost: string;
begin
  Result := FTCPConnection.Socket.Binding.PeerIP;
end;

function TIncomingConnection.GetIOHandler: TIdIOHandler;
begin
  Result := FTCPConnection.IOHandler;
end;

function TIncomingConnection.GetIPVer: TIdIPVersion;
begin
  Result := FTCPConnection.Socket.Binding.IPVersion;
end;

function TIncomingConnection.GetPort: TIdPort;
begin
  Result := FTCPConnection.Socket.Binding.PeerPort;
end;

end.
