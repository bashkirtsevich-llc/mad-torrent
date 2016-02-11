unit Bittorrent.Server;

interface

uses
  System.SysUtils, System.Classes,
  Bittorrent,
  IdServerIOHandler, IdServerIOHandlerStack, IdSocketHandle, IdThread,
  IdTCPConnection, IdIOHandler, IdGlobal;

type
  TServer = class(TInterfacedObject, IServer)
  private
    FListenerThreads: TThreadList;
    FBindings: TIdSocketHandles;
    FIOHandler: TIdServerIOHandler;
    FActive: Boolean;
    FOnConnect: TProc<IConnection>;
    FUseNagle: Boolean;

    function GetListenPort: TIdPort; inline;
    procedure SetListenPort(const Value: TIdPort); inline;
    function GetActive: Boolean; inline;
    procedure SetActive(const Value: Boolean);
    function GetOnConnect: TProc<IConnection>; inline;
    procedure SetOnConnect(const Value: TProc<IConnection>); inline;
    function GetBindings: TIdSocketHandles; inline;
    procedure SetBindings(const Value: TIdSocketHandles); inline;
    function GetUseNagle: Boolean; inline;
    procedure SetUseNagle(const Value: Boolean); inline;

    procedure StartListening;
    procedure StopListening;

    procedure Startup;
    procedure Shutdown;
  public
    constructor Create; reintroduce;
    destructor Destroy; override;
  end;

implementation

uses
  Bittorrent.Connection;

type
  TListenerThread = class(TIdThread)
  private
    FOnPeerConnect: TProc<TIdTCPConnection>;
  protected
    FIOHandler: TIdServerIOHandler;
    FBinding: TIdSocketHandle;

    procedure AfterRun; override;
    procedure Run; override;
  public
    constructor Create(AIOHandler: TIdServerIOHandler;
      ABinding: TIdSocketHandle); reintroduce;

    property Binding: TIdSocketHandle read FBinding;
    property OnPeerConnect: TProc<TIdTCPConnection> read FOnPeerConnect write FOnPeerConnect;
  End;

{ TServer }

constructor TServer.Create;
begin
  inherited Create;

  FActive := False;
  FUseNagle := True;
  FBindings := TIdSocketHandles.Create(nil);
  FListenerThreads := TThreadList.Create;
  FIOHandler := TIdServerIOHandlerStack.Create(nil);
end;

destructor TServer.Destroy;
begin
  SetActive(False);
  IdDisposeAndNil(FIOHandler);
  FreeAndNil(FBindings);
  FreeAndNil(FListenerThreads);

  inherited;
end;

function TServer.GetActive: Boolean;
begin
  Result := FActive;
end;

function TServer.GetBindings: TIdSocketHandles;
begin
  Result := FBindings;
end;

function TServer.GetListenPort: TIdPort;
begin
  Result := FBindings.DefaultPort;
end;

function TServer.GetOnConnect: TProc<IConnection>;
begin
  Result := FOnConnect;
end;

function TServer.GetUseNagle: Boolean;
begin
  Result := FUseNagle;
end;

procedure TServer.SetActive(const Value: Boolean);
begin
  if Value <> FActive then
  begin
    if Value then
    begin
      //CheckOkToBeActive;
      try
        Startup;
      except
        FActive := True;
        SetActive(False); // allow descendants to clean up
        raise;
      end;

      FActive := True;
    end else
    begin
      // Must set to False here. Shutdown() implementations call property setters that check this
      FActive := False;
      Shutdown;
    end;
  end;
end;

procedure TServer.SetBindings(const Value: TIdSocketHandles);
begin
  FBindings.Assign(Value);
end;

procedure TServer.SetListenPort(const Value: TIdPort);
begin
  FBindings.DefaultPort := Value;
end;

procedure TServer.SetOnConnect(const Value: TProc<IConnection>);
begin
  FOnConnect := Value;
end;

procedure TServer.SetUseNagle(const Value: Boolean);
begin
  FUseNagle := Value;
end;

procedure TServer.Shutdown;
begin
  StopListening;

  FIOHandler.Shutdown;
end;

procedure TServer.StartListening;
var
  threads: TList;
  tr: TListenerThread;
  i: Integer;
  binding: TIdSocketHandle;
begin
  threads := FListenerThreads.LockList;
  try
    // Set up any sockets that are not already listening
    i := threads.Count;
    try
      while i < FBindings.Count do
      begin
        binding := FBindings[i];
        binding.AllocateSocket;
        // do not overwrite if the default. This allows ReuseSocket to be set per binding
        {if FReuseSocket <> rsOSDependent then begin
          LBinding.ReuseSocket := FReuseSocket;
        end;}
        binding.Bind;
        binding.UseNagle := FUseNagle;

        Inc(i);
      end;
    except
      Dec(i); // the one that failed doesn't need to be closed

      while i >= 0 do
      begin
        FBindings[i].CloseSocket;
        Dec(i);
      end;

      raise;
    end;

    // Set up any threads that are not already running
    for i := threads.Count to FBindings.Count - 1 do
    begin
      binding := FBindings[i];
      binding.Listen(15);

      tr := TListenerThread.Create(FIOHandler, binding);
      try
        tr.OnPeerConnect := procedure (AConnection: TIdTCPConnection)
        begin
          TThread.CreateAnonymousThread(procedure
          begin
            if Assigned(FOnConnect) then
              FOnConnect(TIncomingConnection.Create(AConnection));
          end).Start;
        end;

        tr.Name := 'Server Listener #' + IntToStr(i + 1); {do not localize}
        tr.Priority := tpTimeCritical;

        threads.Add(tr);
      except
        binding.CloseSocket;
        FreeAndNil(tr);
        raise;
      end;
      tr.Start;
    end;
  finally
    FListenerThreads.UnlockList;
  end;
end;

procedure TServer.Startup;
begin
  // Set up bindings
  if FBindings.Count = 0 then
  begin
    // Binding object that supports both IPv4 and IPv6 on the same socket...
    FBindings.Add; // IPv4 or IPv6 by default

    {$IFNDEF IdIPv6}
      {$IFDEF CanCreateTwoBindings}
    if GStack.SupportsIPv6 then
      // maybe add a property too, so the developer can switch it on/off
      FBindings.Add.IPVersion := Id_IPv6;
      {$ENDIF}
    {$ENDIF}
  end;

  FIOHandler.Init;
  //FIOHandler.SetScheduler(); ???

  StartListening;
end;

procedure TServer.StopListening;
var
  threads: TList;
  thread: TListenerThread;
begin
  threads := FListenerThreads.LockList;
  try
    while threads.Count > 0 do
    begin
      thread := TListenerThread(threads[0]);

      // Stop listening
      thread.Terminate;
      thread.Binding.CloseSocket;

      // Tear down Listener thread
      thread.WaitFor;
      thread.Free;
      threads.Delete(0); // RLebeau 2/17/2006
    end;
  finally
    FListenerThreads.UnlockList;
  end;
end;

{ TListenerThread }

procedure TListenerThread.AfterRun;
begin
  inherited;
  FBinding.CloseSocket;
end;

constructor TListenerThread.Create(AIOHandler: TIdServerIOHandler;
  ABinding: TIdSocketHandle);
begin
  inherited Create;
  FIOHandler := AIOHandler;
  FBinding := ABinding;
end;

procedure TListenerThread.Run;
var
  LIOHandler: TIdIOHandler;
  peer: TIdTCPConnection;
begin
  Assert(Assigned(FIOHandler));

  peer := nil;
  try
    // the user to reject connections before they are accepted.  Somehow
    // expose an event here for the user to decide with...

    LIOHandler := FIOHandler.Accept(FBinding, Self, nil);

    if not Assigned(LIOHandler) then
    begin
      // Listening has finished
      Stop;
      Abort;
    end else
    begin
      // We have accepted the connection and need to handle it
      peer := TIdTCPConnection.Create(nil);
      peer.IOHandler := LIOHandler;
      peer.ManagedIOHandler := True;
    end;

    if Assigned(FOnPeerConnect) then
      FOnPeerConnect(peer);
  except
    FreeAndNil(peer);
  end;
end;

end.
