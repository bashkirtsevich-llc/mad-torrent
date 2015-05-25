unit Bittorrent.Tracker;

interface

uses
  System.Classes, System.SysUtils, System.TimeSpan, System.StrUtils,
  BusyObj,
  Bittorrent, Bittorrent.ThreadPool,
  Basic.UniString,
  IdHTTP, IdURI, IdGlobal, IdSSLOpenSSL;

type
  TTracker = class abstract(TBusy, ITracker)
  private
    FPool: TThreadPool;
    FLock: TObject;
    FInfoHash: TUniString;
    FAnnounceURL: string;
    FScrapeURL: string;
    FTrackerResponse: TTrackerResponse;
    FTrackerResponseText: string;

    function GetInfoHash: TUniString; inline;
    function GetAnnounceURL: string; inline;
    function GetScrapeURL: string; inline;
    function GetTrackerResponse: TTrackerResponse; inline;
    function GetTrackerResponseText: string; inline;
  protected
    procedure Lock; inline;
    procedure Unlock; inline;

    function CanAnnounce: Boolean; virtual;
    function CanScrape: Boolean; virtual;

    procedure Announce; virtual; abstract;
    procedure Scrape; virtual; abstract;

    procedure DoSync; override;
  public
    constructor Create(APool: TThreadPool; const AInfoHash: TUniString;
      const ATrackerURL: string);
    destructor Destroy; override;
  end;

  THTTPTracker = class(TTracker, IHTTPTracker)
  private
    //FSSL: TIdSSLIOHandlerSocketOpenSSL;
    //FCookies: TIdCookieManager;
    FHTTP: TIdHTTP;
    FPeerID: string;
    FKey: string;
    FPort: TIdPort;
    FUploaded: UInt64;
    FDownloaded: UInt64;
    FLeft: UInt64;
    FCorrupt: UInt64;
    FEvent: THTTPTrackerEvent;

    function GetPeerID: string; inline;
    function GetKey: string; inline;
    function GetPort: TIdPort; inline;
    function GetUploaded: UInt64; inline;
    procedure SetUploaded(const Value: UInt64); inline;
    function GetDownloaded: UInt64; inline;
    procedure SetDownloaded(const Value: UInt64); inline;
    function GetLeft: UInt64; inline;
    procedure SetLeft(const Value: UInt64); inline;
    function GetCorrupt: UInt64; inline;
    procedure SetCorrupt(const Value: UInt64); inline;
    function GetEvent: THTTPTrackerEvent; inline;
    procedure SetEvent(const Value: THTTPTrackerEvent); inline;
  protected
    function CanAnnounce: Boolean; override;
    function CanScrape: Boolean; override;

    procedure Announce; override;
    procedure Scrape; override;
  public
    constructor Create(APool: TThreadPool; const AInfoHash: TUniString;
      const ATrackerURL: string; const APeerID: string; APort: TIdPort);
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
  FPool.Exec(Integer(TTracker), function : Boolean
  begin
    if CanAnnounce then
      Announce;

    Result := False;
  end);

  FPool.Exec(Integer(TTracker), function : Boolean
  begin
    if CanScrape then
      Scrape;

    Result := False;
  end);
end;

function TTracker.GetAnnounceURL: string;
begin
  Result := FAnnounceURL;
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

function TTracker.GetScrapeURL: string;
begin
  Result := FScrapeURL;
end;

function TTracker.GetTrackerResponse: TTrackerResponse;
begin
  Result := FTrackerResponse;
end;

function TTracker.GetTrackerResponseText: string;
begin
  Result := FTrackerResponseText;
end;

procedure TTracker.Lock;
begin
  TMonitor.Enter(FLock);
end;

procedure TTracker.Unlock;
begin
  TMonitor.Exit(FLock);
end;

{ THTTPTracker }

procedure THTTPTracker.Announce;
var
  sb: TStringBuilder;
  ms: TMemoryStream;
  resp: TUniString;
begin
  Lock;
  try
    Assert(CanAnnounce);

    sb := TStringBuilder.Create(FAnnounceURL);
    try
      // урл может содержать в себе параметр (.../ann.php?uk=blablabla)
      sb.Append(System.StrUtils.IfThen(FAnnounceURL.Contains('?'), '&', '?'))
        .Append('info_hash='  ).Append(TIdURI.ParamsEncode(FInfoHash))
        .Append('&peer_id='   ).Append(TIdURI.ParamsEncode(FPeerID))
        .Append('&port='      ).Append(FPort)
        .Append('&uploaded='  ).Append(FUploaded)
        .Append('&downloaded=').Append(FDownloaded)
        .Append('&left='      ).Append(FLeft)
        .Append('&corrupt='   ).Append(FCorrupt)
        .Append('&key='       ).Append(FKey)
        .Append('&event='     ).Append(FEvent.ToString) // по идее тоже должен быть результатом ParamsEncode(FEvent.ToString)
        .Append('&numwant='   ).Append(200)
        .Append('&compact='   ).Append(1)
        .Append('&no_peer_id=').Append(1);

      ms := TMemoryStream.Create;
      try
        FHTTP.Get(sb.ToString, ms);

        ms.Position := 0;
        resp.Len := ms.Size;
        ms.Read(resp.DataPtr[0]^, ms.Size);
      finally
        ms.Free;
      end;
    finally
      sb.Free;
    end;
  finally
    Unlock;
  end;
end;

constructor THTTPTracker.Create(APool: TThreadPool; const AInfoHash: TUniString;
  const ATrackerURL: string; const APeerID: string; APort: TIdPort);
var
  tmp: TUniString;
begin
  inherited Create(APool, AInfoHash, ATrackerURL);

  //FSSL  := TIdSSLIOHandlerSocketOpenSSL.Create(nil);
  FHTTP := TIdHTTP.Create(nil);
  //FHTTP.IOHandler := FSSL;

  FPeerID := APeerID;
  FPort := APort;

  tmp.Len := 4{8?};
  tmp.FillRandom;
  FKey := tmp.ToHexString;
end;

destructor THTTPTracker.Destroy;
begin
  FHTTP.Free;
  //FSSL.Free;
  inherited;
end;

function THTTPTracker.CanAnnounce: Boolean;
begin
  Result := inherited CanAnnounce;
end;

function THTTPTracker.CanScrape: Boolean;
begin
  Result := inherited CanScrape;
end;

function THTTPTracker.GetCorrupt: UInt64;
begin
  Result := FCorrupt;
end;

function THTTPTracker.GetDownloaded: UInt64;
begin
  Result := FDownloaded;
end;

function THTTPTracker.GetEvent: THTTPTrackerEvent;
begin
  Result := FEvent;
end;

function THTTPTracker.GetKey: string;
begin
  Result := FKey;
end;

function THTTPTracker.GetLeft: UInt64;
begin
  Result := FLeft;
end;

function THTTPTracker.GetPeerID: string;
begin
  Result := FPeerID;
end;

function THTTPTracker.GetPort: TIdPort;
begin
  Result := FPort;
end;

function THTTPTracker.GetUploaded: UInt64;
begin
  Result := FUploaded;
end;

procedure THTTPTracker.Scrape;
var
  response: string;
begin
  Lock;
  try
    Assert(CanScrape);

    response := FHTTP.Get(FScrapeURL + '?info_hash=' + TIdURI.ParamsEncode(FInfoHash));
  finally
    Unlock;
  end;
end;

procedure THTTPTracker.SetCorrupt(const Value: UInt64);
begin
  Lock;
  try
    FCorrupt := Value;
  finally
    Unlock;
  end;
end;

procedure THTTPTracker.SetDownloaded(const Value: UInt64);
begin
  Lock;
  try
    FDownloaded := Value;
  finally
    Unlock;
  end;
end;

procedure THTTPTracker.SetEvent(const Value: THTTPTrackerEvent);
begin
  Lock;
  try
    FEvent := Value;
  finally
    Unlock;
  end;
end;

procedure THTTPTracker.SetLeft(const Value: UInt64);
begin
  Lock;
  try
    FLeft := Value;
  finally
    Unlock;
  end;
end;

procedure THTTPTracker.SetUploaded(const Value: UInt64);
begin
  Lock;
  try
    FUploaded := Value;
  finally
    Unlock;
  end;
end;

end.
