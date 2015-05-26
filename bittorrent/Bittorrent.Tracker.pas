unit Bittorrent.Tracker;

interface

uses
  System.Classes, System.SysUtils, System.StrUtils,
  System.Generics.Collections,
  BusyObj,
  Bittorrent, Bittorrent.ThreadPool,
  Basic.UniString;

type
  TTracker = class abstract(TBusy, ITracker)
  private
    FLock: TObject;
    FOnAnnounce: TProc<ITracker>;
    FOnScrape: TProc<ITracker>;

    function GetInfoHash: TUniString; inline;
    function GetAnnounceURL: string; inline;
    function GetScrapeURL: string; inline;
    function GetFailureResponse: string; inline;
    function GetOnAnnounce: TProc<ITracker>; inline;
    procedure SetOnAnnounce(const Value: TProc<ITracker>); inline;
    function GetOnScrape: TProc<ITracker>; inline;
    procedure SetOnScrape(const Value: TProc<ITracker>); inline;

    procedure Announce;
    procedure Scrape;
  protected
    FPool: TThreadPool;
    FInfoHash: TUniString;
    FAnnounceURL: string;
    FScrapeURL: string;
    FFailureResponse: string;

    procedure Lock; inline;
    procedure Unlock; inline;

    function CanAnnounce: Boolean; virtual;
    function CanScrape: Boolean; virtual;

    procedure DoAnnounce; virtual; abstract;
    procedure DoScrape; virtual; abstract;
  protected
    procedure DoSync; override;
  public
    constructor Create(APool: TThreadPool; const AInfoHash: TUniString;
      const ATrackerURL: string);
    destructor Destroy; override;
  end;

implementation

{ TTracker }

constructor TTracker.Create(APool: TThreadPool; const AInfoHash: TUniString;
  const ATrackerURL: string);
var
  i: Integer;
  s: string;
begin
  inherited Create;

  FPool := APool;
  FLock := TObject.Create;
  FInfoHash.Assign(AInfoHash);
  FAnnounceURL := ATrackerURL;

  i := ATrackerURL.LastIndexOf('/');
  s := System.StrUtils.IfThen(i + 9 <= ATrackerURL.Length, ATrackerURL.Substring(i + 1, 8));
  if s.ToLower = 'announce' then
    FScrapeURL := ATrackerURL.Substring(1, i) + 'scrape' + ATrackerURL.Substring(i + 9, ATrackerURL.Length - i - 9);
end;

destructor TTracker.Destroy;
begin
  FLock.Free;
  inherited;
end;

procedure TTracker.DoSync;
begin
  if CanAnnounce then
    Announce;

  if CanScrape then
    Scrape;
end;

function TTracker.GetAnnounceURL: string;
begin
  Result := FAnnounceURL;
end;

procedure TTracker.Announce;
begin
  FPool.Exec(Integer(TTracker), function : Boolean
  begin
    Assert(CanAnnounce);

    DoAnnounce;

    if Assigned(FOnAnnounce) then
      FOnAnnounce(Self);

    Result := False;
  end);
end;

function TTracker.CanAnnounce: Boolean;
begin
  Result := not FAnnounceURL.IsEmpty;
end;

function TTracker.CanScrape: Boolean;
begin
  Result := not FScrapeURL.IsEmpty;
end;

function TTracker.GetInfoHash: TUniString;
begin
  Result := FInfoHash;
end;

function TTracker.GetOnAnnounce: TProc<ITracker>;
begin
  Result := FOnAnnounce;
end;

function TTracker.GetOnScrape: TProc<ITracker>;
begin
  Result := FOnScrape;
end;

function TTracker.GetScrapeURL: string;
begin
  Result := FScrapeURL;
end;

function TTracker.GetFailureResponse: string;
begin
  Result := FFailureResponse;
end;

procedure TTracker.Lock;
begin
  TMonitor.Enter(FLock);
end;

procedure TTracker.Scrape;
begin
  FPool.Exec(Integer(TTracker), function : Boolean
  begin
    Assert(CanScrape);

    DoScrape;

    if Assigned(FOnScrape) then
      FOnScrape(Self);

    Result := False;
  end);
end;

procedure TTracker.SetOnAnnounce(const Value: TProc<ITracker>);
begin
  FOnAnnounce := Value;
end;

procedure TTracker.SetOnScrape(const Value: TProc<ITracker>);
begin
  FOnScrape := Value;
end;

procedure TTracker.Unlock;
begin
  TMonitor.Exit(FLock);
end;

end.
