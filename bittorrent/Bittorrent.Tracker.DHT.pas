unit Bittorrent.Tracker.DHT;

interface

uses
  System.Classes, System.SysUtils,
  Basic.UniString,
  Common.ThreadPool, Common.Prelude,
  DHT,
  Bittorrent, Bittorrent.Tracker,
  IdGlobal;

type
  TDHTTracker = class(TTRacker, IDHTTracker)
  private
    const
      DefaultAnnounceInterval = 25*60;
      DefaultRetrackInterval = 60;
  private
    FAnnounceTask: IAnnounceTask;
    FGetPeersTask: IGetPeersTask;
    procedure OnPeersFound(APeers: TArray<IPeer>);
    procedure HandleTaskLoop(ATask: IFindPeersTask);
  protected
    procedure DoAnnounce; override; final;
    procedure DoRetrack; override; final;
  public
    constructor Create(AThreadPool: TThreadPool; AAnnounceTask: IAnnounceTask;
      AGetPeersTask: IGetPeersTask); reintroduce;
  end;

implementation

{ TDHTTracker }

constructor TDHTTracker.Create(AThreadPool: TThreadPool;
  AAnnounceTask: IAnnounceTask; AGetPeersTask: IGetPeersTask);
begin
  inherited Create(AThreadPool, AAnnounceTask.InfoHash, AAnnounceTask.Port,
    DefaultAnnounceInterval, DefaultRetrackInterval);

  FAnnounceTask := AAnnounceTask;
  FGetPeersTask := AGetPeersTask;

  FAnnounceTask.OnPeersFound := OnPeersFound;
  FGetPeersTask.OnPeersFound := OnPeersFound;
end;

procedure TDHTTracker.DoAnnounce;
begin
  HandleTaskLoop(FAnnounceTask);
end;

procedure TDHTTracker.DoRetrack;
begin
  HandleTaskLoop(FGetPeersTask);
end;

procedure TDHTTracker.HandleTaskLoop(ATask: IFindPeersTask);
var
  b: Boolean;
begin
  b := True;

  ATask.OnCompleted := procedure (t: ITask; e: ICompleteEventArgs)
  begin
    b := False;
    t.Reset;
  end;

  while b do
    if not ATask.Busy then
      ATask.Sync
    else
      Sleep(1);
end;

procedure TDHTTracker.OnPeersFound(APeers: TArray<IPeer>);
begin
  TPrelude.Foreach<IPeer>(APeers, procedure (APeer: IPeer)
  begin
    with APeer do
      ResponsePeerInfo(Host, Port);
  end);
end;

end.
