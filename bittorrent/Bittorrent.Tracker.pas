unit Bittorrent.Tracker;

interface

uses
  System.Classes, System.SysUtils, System.DateUtils, System.Generics.Collections,
  Common.BusyObj, Common.ThreadPool,
  Basic.UniString,
  Bittorrent,
  IdGlobal;

type
  TTRacker = class abstract(TBusy, ITracker)
  private
    FThreads: TThreadPool;
    FLastAnnounce: TDateTime;
    FLastRetrack: TDateTime;
    FOnResponsePeerInfo: TProc<string, TIdPort>;

    function GetInfoHash: TUniString; inline;
    function GetAnnouncePort: TIdPort; inline;
    function GetAnnounceInterval: Integer; inline;
    function GetRetrackInterval: Integer; inline;
    function GetOnResponsePeerInfo: TProc<string, TIdPort>; inline;
    procedure SetOnResponsePeerInfo(const Value: TProc<string, TIdPort>); inline;
  protected
    FInfoHash: TUniString;
    FAnnouncePort: TIdPort;
    FAnnounceInterval: Integer;
    FRetrackInterval: Integer;

    procedure DoAnnounce; virtual;
    procedure DoRetrack; virtual;

    procedure ResponsePeerInfo(const AHost: string; APort: TIdPort); inline;
    procedure DoSync; override; final;

    constructor Create(AThreadPool: TThreadPool; const AInfoHash: TUniString;
      AAnnouncePort: TIdPort; AAnnounceInterval, ARetrackInterval: Integer); reintroduce;
  end;

  TStatTracker = class abstract(TTRacker, IStatTracker)
  private
    function GetBytesUploaded: Int64; inline;
    procedure SetBytesUploaded(const Value: Int64); inline;
    function GetBytesDownloaded: Int64; inline;
    procedure SetBytesDownloaded(const Value: Int64); inline;
    function GetBytesLeft: Int64; inline;
    procedure SetBytesLeft(const Value: Int64); inline;
    function GetBytesCorrupt: Int64; inline;
    procedure SetBytesCorrupt(const Value: Int64); inline;
  protected
    FBytesUploaded: Int64;
    FBytesDownloaded: Int64;
    FBytesLeft: Int64;
    FBytesCorrupt: Int64;
  end;

  TWebTracker = class abstract(TStatTracker, IWebTracker)
  private
    function GetTrackerURL: string; inline;
  protected
    FTrackerURL: string;

    constructor Create(AThreadPool: TThreadPool; const AInfoHash: TUniString;
      AAnnouncePort: TIdPort; AAnnounceInterval, ARetrackInterval: Integer;
      ATrackerURL: string); reintroduce;
  end;

implementation

{ TTRacker }

constructor TTRacker.Create(AThreadPool: TThreadPool;
  const AInfoHash: TUniString; AAnnouncePort: TIdPort; AAnnounceInterval,
  ARetrackInterval: Integer);
begin
  inherited Create;

  FThreads          := AThreadPool;

  FInfoHash.Assign(AInfoHash);
  FAnnouncePort     := AAnnouncePort;
  FAnnounceInterval := AAnnounceInterval;
  FRetrackInterval  := ARetrackInterval;
  FLastAnnounce     := MinDateTime;
  FLastRetrack      := MinDateTime;
end;

procedure TTRacker.DoAnnounce;
begin
  FLastAnnounce := Now;
end;

procedure TTRacker.DoRetrack;
begin
  FLastRetrack := Now;
end;

procedure TTRacker.DoSync;
begin
  Enter;

  FThreads.Exec(function : Boolean
  begin
    if SecondsBetween(Now, FLastAnnounce) >= FAnnounceInterval then
      DoAnnounce;

    if SecondsBetween(Now, FLastRetrack) >= FRetrackInterval then
      DoRetrack;

    Sleep(100); // дабы не создавать излишнюю нагрузку на проц

    Leave;

    Result := False;
  end);
end;

function TTRacker.GetAnnounceInterval: Integer;
begin
  Result := FAnnounceInterval;
end;

function TTRacker.GetAnnouncePort: TIdPort;
begin
  Result := FAnnouncePort;
end;

function TTRacker.GetInfoHash: TUniString;
begin
  Result := FInfoHash;
end;

function TTRacker.GetOnResponsePeerInfo: TProc<string, TIdPort>;
begin
  Result := FOnResponsePeerInfo;
end;

function TTRacker.GetRetrackInterval: Integer;
begin
  Result := FRetrackInterval;
end;

procedure TTRacker.ResponsePeerInfo(const AHost: string; APort: TIdPort);
begin
  if Assigned(FOnResponsePeerInfo) then
    FOnResponsePeerInfo(AHost, APort);
end;

procedure TTRacker.SetOnResponsePeerInfo(const Value: TProc<string, TIdPort>);
begin
  FOnResponsePeerInfo := Value;
end;

{ TStatTracker }

function TStatTracker.GetBytesCorrupt: Int64;
begin
  Result := FBytesCorrupt;
end;

function TStatTracker.GetBytesDownloaded: Int64;
begin
  Result := FBytesDownloaded;
end;

function TStatTracker.GetBytesLeft: Int64;
begin
  Result := FBytesLeft;
end;

function TStatTracker.GetBytesUploaded: Int64;
begin
  Result := FBytesUploaded;
end;

procedure TStatTracker.SetBytesCorrupt(const Value: Int64);
begin
  FBytesCorrupt := Value;
end;

procedure TStatTracker.SetBytesDownloaded(const Value: Int64);
begin
  FBytesDownloaded := Value;
end;

procedure TStatTracker.SetBytesLeft(const Value: Int64);
begin
  FBytesLeft := Value;
end;

procedure TStatTracker.SetBytesUploaded(const Value: Int64);
begin
  FBytesUploaded := Value;
end;

{ TWebTracker }

constructor TWebTracker.Create(AThreadPool: TThreadPool;
  const AInfoHash: TUniString; AAnnouncePort: TIdPort; AAnnounceInterval,
  ARetrackInterval: Integer; ATrackerURL: string);
begin
  inherited Create(AThreadPool, AInfoHash, AAnnouncePort, AAnnounceInterval,
    ARetrackInterval);

  FTrackerURL := ATrackerURL;
end;

function TWebTracker.GetTrackerURL: string;
begin
  Result := FTrackerURL;
end;

end.
