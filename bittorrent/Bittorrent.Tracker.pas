unit Bittorrent.Tracker;

interface

uses
  System.Classes, System.SysUtils, System.TimeSpan,
  Bittorrent,
  IdURI;

type
  TTracker = class abstract(TInterfacedObject, ITracker)
  private
    FCanAnnounce: Boolean;
    FCanScrape: Boolean;
    FComplete: Integer;
    FDownloaded: Integer;
    FFailureMessage: string;
    FIncomplete: Integer;
    FMinUpdateInterval: TTimeSpan;
    FStatus: TTrackerState;
    FUpdateInterval: TTimeSpan;
    FURI: TIdURI;
    FWarningMessage: string;

    FBeforeAnnounce: TProc<ITracker>;
//    FAnnounceComplete: TProc<ITracker, IAnnounceResponseEventArgs>;
    FBeforeScrape: TProc<ITracker>;
//    FScrapeComplete: TProc<ITracker, IScrapeResponseEventArgs>;

    function GetCanAnnounce: Boolean; inline;
    function GetCanScrape: Boolean; inline;
    function GetComplete: Integer; inline;
    function GetDownloaded: Integer; inline;
    function GetFailureMessage: string; inline;
    function GetIncomplete: Integer; inline;
    function GetMinUpdateInterval: TTimeSpan; inline;
    function GetStatus: TTrackerState; inline;
    function GetUpdateInterval: TTimeSpan; inline;
    function GetURI: TIdURI; inline;
    function GetWarningMessage: string; inline;

    function GetBeforeAnnounce: TProc<ITracker>; inline;
    procedure SetBeforeAnnounce(Value: TProc<ITracker>); inline;
//    function GetAnnounceComplete: TProc<ITracker, IAnnounceResponseEventArgs>; inline;
//    procedure SetAnnounceComplete(Value: TProc<ITracker, IAnnounceResponseEventArgs>); inline;
    function GetBeforeScrape: TProc<ITracker>; inline;
    procedure SetBeforeScrape(Value: TProc<ITracker>); inline;
//    function GetAnnounceComplete: TProc<ITracker, IScrapeResponseEventArgs>; inline;
//    procedure SetAnnounceComplete(Value: TProc<ITracker, IScrapeResponseEventArgs>); inline;

  protected
//    procedure Announce(AParameters: IAnnounceParameters; AState: Tobject); virtual; abstract;
//    procedure Scrape(AParameters: IScrapeParameters; AState: Tobject); virtual; abstract;
//    procedure RaiseBeforeAnnounce; virtual;
  public

  end;

implementation

{ TTracker }

function TTracker.GetBeforeAnnounce: TProc<ITracker>;
begin
  Result := FBeforeAnnounce;
end;

function TTracker.GetBeforeScrape: TProc<ITracker>;
begin
  Result := FBeforeScrape;
end;

function TTracker.GetCanAnnounce: Boolean;
begin
  Result := FCanAnnounce;
end;

function TTracker.GetCanScrape: Boolean;
begin
  Result := FCanScrape;
end;

function TTracker.GetComplete: Integer;
begin
  Result := FComplete;
end;

function TTracker.GetDownloaded: Integer;
begin
  Result := FDownloaded;
end;

function TTracker.GetFailureMessage: string;
begin
  Result := FFailureMessage;
end;

function TTracker.GetIncomplete: Integer;
begin
  Result := FIncomplete;
end;

function TTracker.GetMinUpdateInterval: TTimeSpan;
begin
  Result := FMinUpdateInterval;
end;

function TTracker.GetStatus: TTrackerState;
begin
  Result := FStatus;
end;

function TTracker.GetUpdateInterval: TTimeSpan;
begin
  Result := FUpdateInterval;
end;

function TTracker.GetURI: TIdURI;
begin
  Result := FURI;
end;

function TTracker.GetWarningMessage: string;
begin
  Result := FWarningMessage;
end;

procedure TTracker.SetBeforeAnnounce(Value: TProc<ITracker>);
begin
  FBeforeAnnounce := Value;
end;

procedure TTracker.SetBeforeScrape(Value: TProc<ITracker>);
begin
  FBeforeScrape := Value;
end;

end.
