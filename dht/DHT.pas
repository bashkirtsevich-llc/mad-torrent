unit DHT;

interface

uses
  System.Generics.Collections, System.Generics.Defaults,
  System.SysUtils, System.TimeSpan, System.DateUtils,
  Spring.Collections,
  Common.ThreadPool,
  Basic.UniString, Basic.UniString.Helper,
  DHT.Engine, DHT.Listener,
  IdGlobal;

type
  IDHT = interface
  ['{37A46EAA-1587-4A73-82A8-C3123684A8D2}']
    function GetOnPeersFound: TProc<TUniString, IList<IPeer>>;
    procedure SetOnPeersFound(const Value: TProc<TUniString, IList<IPeer>>);
    function GetOnItemProcessed: TProc<TUniString, Boolean, TIdPort>;
    procedure SetOnItemProcessed(const Value: TProc<TUniString, Boolean, TIdPort>);

    procedure GetPeers(const AInfoHash: TUniString);
    procedure Announce(const AInfoHash: TUniString; APort: TIdPort;
      AAnnounceTime: Integer { через сколько минут анонсить });

    property OnPeersFound: TProc<TUniString, IList<IPeer>> read GetOnPeersFound write SetOnPeersFound;
    property OnItemProcessed: TProc<TUniString, Boolean, TIdPort> read GetOnItemProcessed write SetOnItemProcessed;
  end;

  TDHT = class(TInterfacedObject, IDHT)
  private
    type
      TDHTAction = (aAnnounce, aGetPeers);

      IDHTItem = interface
      ['{71712C13-9DC0-4411-838F-E1700632D715}']
        function GetInfoHash: TUniString;
        function GetAction: TDHTAction;
        function GetTime: TDateTime;
        function GetPort: TIdPort;

        property InfoHash: TUniString read GetInfoHash;
        property Action: TDHTAction read GetAction;
        property Time: TDateTime read GetTime;
        property Port: TIdPort read GetPort;
      end;

      TDHTItem = class(TInterfacedObject, IDHTItem)
      private
        FInfoHash: TUniString;
        FAction: TDHTAction;
        FPort: TIdPort;
        FTime: TDateTime;

        function GetInfoHash: TUniString; inline;
        function GetAction: TDHTAction; inline;
        function GetTime: TDateTime; inline;
        function GetPort: TIdPort; inline;
      public
        constructor Create(const AInfoHash: TUniString; AAction: TDHTAction;
          ATime: TDateTime; APort: TIdPort);
      end;
  private
    FDHTListener: TDHTListener;
    FDHTEngine: TDHTEngine;
    FQueue: TList<IDHTItem>;
    FOnItemProcessed: TProc<TUniString, Boolean, TIdPort>;
    FLastItem: IDHTItem;
    FLock: TObject;

    procedure Lock; inline;
    procedure Unlock; inline;

    function GetOnPeersFound: TProc<TUniString, IList<IPeer>>; inline;
    procedure SetOnPeersFound(const Value: TProc<TUniString, IList<IPeer>>); inline;
    function GetOnItemProcessed: TProc<TUniString, Boolean, TIdPort>; inline;
    procedure SetOnItemProcessed(const Value: TProc<TUniString, Boolean, TIdPort>); inline;

    procedure KickStart; inline;
    procedure FetchNext;
    procedure DHTStateChange(AState: TDHTEngine.TDHTState);

    procedure GetPeers(const AInfoHash: TUniString);
    procedure Announce(const AInfoHash: TUniString; APort: TIdPort;
      AAnnounceTime: Integer);
  public
    constructor Create(APool: TThreadPool; AListenPort: TIdPort;
      const ALocalID: TUniString);
    destructor Destroy; override;
  end;

implementation

{ TDHT }

procedure TDHT.Announce(const AInfoHash: TUniString; APort: TIdPort;
  AAnnounceTime: Integer);
var
  it: IDHTItem;
begin
  Lock;
  try
    for it in FQueue do
      if (it.Action = aAnnounce) and (it.InfoHash = AInfoHash) and (it.Port = APort) then
        Exit;

    FQueue.Add(TDHTItem.Create(AInfoHash, aAnnounce, IncMinute(Now, AAnnounceTime), APort) as IDHTItem);

    KickStart;
  finally
    Unlock;
  end;
end;

constructor TDHT.Create(APool: TThreadPool; AListenPort: TIdPort;
  const ALocalID: TUniString);
begin
  inherited Create;

  FQueue        := TList<IDHTItem>.Create;
  FLastItem     := nil;
  FLock         := TObject.Create;

  FDHTListener  := TDHTListener.Create(AListenPort);
  FDHTEngine    := TDHTEngine.Create(APool, FDHTListener, ALocalID);
  {$IFDEF PUBL_UTIL}
  FDHTEngine.TimeOut := TTimeSpan.FromSeconds(1);
  {$ENDIF}
  FDHTEngine.OnStateChanged := DHTStateChange;
  FDHTEngine.Start;
end;

destructor TDHT.Destroy;
begin
  FDHTEngine.Free;
  FDHTListener.Free;
  FQueue.Free;
  FLock.Free;

  inherited;
end;

procedure TDHT.DHTStateChange(AState: TDHTEngine.TDHTState);
begin
  if AState = sReady then
    FetchNext;
end;

procedure TDHT.FetchNext;
var
  i: Integer;
  it: IDHTItem;
begin
  Lock;
  try
    repeat // ковыряем, пока не найдем запись
      if FQueue.Count = 0 then
      begin
        FLastItem := nil;
        Exit;
      end;

      if Assigned(FLastItem) then
      begin
        it := nil;

        for i := 0 to FQueue.Count - 1 do
          if ((FLastItem.Action = aAnnounce) and
              (FQueue[i].Action = aGetPeers)) or

             ((FLastItem.Action = aGetPeers) and
              (CompareDateTime(Now, FQueue[i].Time) >= 0)) then
          begin
            it := FQueue[i];
            FQueue.Delete(i);
            Break;
          end;
      end else
        it := FQueue.First;

      if Assigned(it) then
      begin
        case it.Action of
          aAnnounce: FDHTEngine.Announce(it.InfoHash, it.Port);
          aGetPeers: FDHTEngine.GetPeers(it.InfoHash);
        end;

        if Assigned(FOnItemProcessed) then
          FOnItemProcessed(it.InfoHash, it.Action = aAnnounce, it.Port);
      end;

      FLastItem := it;
    until Assigned(FLastItem);
  finally
    Unlock;
  end;
end;

function TDHT.GetOnItemProcessed: TProc<TUniString, Boolean, TIdPort>;
begin
  Result := FOnItemProcessed;
end;

function TDHT.GetOnPeersFound: TProc<TUniString, IList<IPeer>>;
begin
  Result := FDHTEngine.OnPeersFound;
end;

procedure TDHT.GetPeers(const AInfoHash: TUniString);
var
  it: IDHTItem;
begin
  Lock;
  try
    for it in FQueue do
      if (it.Action = aGetPeers) and (it.InfoHash = AInfoHash) then
        Exit;

    FQueue.Add(TDHTItem.Create(AInfoHash, aAnnounce, MinDateTime, 0) as IDHTItem);

    KickStart;
  finally
    Unlock;
  end;
end;

procedure TDHT.KickStart;
begin
  if FDHTEngine.State = sReady then
    FetchNext;
end;

procedure TDHT.Lock;
begin
  TMonitor.Enter(FLock);
end;

procedure TDHT.SetOnItemProcessed(
  const Value: TProc<TUniString, Boolean, TIdPort>);
begin
  FOnItemProcessed := Value;
end;

procedure TDHT.SetOnPeersFound(const Value: TProc<TUniString, IList<IPeer>>);
begin
  FDHTEngine.OnPeersFound := Value;
end;

procedure TDHT.Unlock;
begin
  TMonitor.Exit(FLock);
end;

{ TDHT.TDHTItem }

constructor TDHT.TDHTItem.Create(const AInfoHash: TUniString;
  AAction: TDHTAction; ATime: TDateTime; APort: TIdPort);
begin
  FInfoHash.Assign(AInfoHash);
  FAction := AAction;
  FTime := ATime;
  FPort := APort;
end;

function TDHT.TDHTItem.GetAction: TDHTAction;
begin
  Result := FAction;
end;

function TDHT.TDHTItem.GetInfoHash: TUniString;
begin
  Result := FInfoHash;
end;

function TDHT.TDHTItem.GetPort: TIdPort;
begin
  Result := FPort;
end;

function TDHT.TDHTItem.GetTime: TDateTime;
begin
  Result := FTime;
end;

end.
