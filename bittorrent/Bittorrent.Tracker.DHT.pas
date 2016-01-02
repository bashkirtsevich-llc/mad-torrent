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
    procedure OnTaskCompleted(ATask: ITask; AArgs: ICompleteEventArgs);
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

  FAnnounceTask.OnCompleted := OnTaskCompleted;
  FAnnounceTask.OnPeersFound := procedure (APeers: TArray<IPeer>)
  begin
    TPrelude.Foreach<IPeer>(APeers, procedure (APeer: IPeer)
    begin
      with APeer do
        ResponsePeerInfo(Host, Port);
    end);
  end;
  FGetPeersTask.OnCompleted := OnTaskCompleted;
end;

procedure TDHTTracker.DoAnnounce;
begin

end;

procedure TDHTTracker.DoRetrack;
begin

end;

procedure TDHTTracker.OnTaskCompleted(ATask: ITask; AArgs: ICompleteEventArgs);
begin
  ATask.Reset;
end;

end.
