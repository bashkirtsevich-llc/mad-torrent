unit Bittorrent.Tracker.HTTPTracker;

interface

uses
  System.Classes, System.SysUtils, System.Generics.Collections, System.StrUtils,
  Bittorrent, Bittorrent.ThreadPool, Bittorrent.Tracker,
  Basic.UniString, Basic.Bencoding,
  IdHTTP, IdURI, IdGlobal, IdSSLOpenSSL;

type
  THTTPTracker = class(TTracker, IHTTPTracker)
  private
    const
      FailureReasonKey    = 'failure reason';
      WarningMessageKey   = 'warning message';
      IntervalKey         = 'interval';
      MinIntervalKey      = 'min interval';
      TrackerIDKey        = 'tracker id';
      CompleteKey         = 'complete';
      DownloadedKey       = 'downloaded';
      IncompleteKey       = 'incomplete';
      PeersKey            = 'peers';

      PeerIDKey           = 'peer id';
      IPKey               = 'ip';
      PortKey             = 'port';
  private
    //FSSL: TIdSSLIOHandlerSocketOpenSSL;
    //FCookies: TIdCookieManager;
    FHTTP: TIdHTTP;
    FPeerID: string;
    FKey: string;
    FPort: TIdPort;
    FInterval: Int64;
    FMinInterval: Int64;
    FUploaded: UInt64;
    FDownloaded: UInt64;
    FLeft: UInt64;
    FCorrupt: UInt64;
    FLastRequest: TDateTime;
    FEvent: THTTPTrackerEvent;
    FPeers: TList<IHTTPTrackerPeerInfo>;

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
    function GetPeers: TList<IHTTPTrackerPeerInfo>; inline;

    function ParseResponse(ALen: Integer; AValue: IBencodedValue): Boolean;
  protected
    function CanAnnounce: Boolean; override;
    function CanScrape: Boolean; override;

    procedure DoAnnounce; override;
    procedure DoScrape; override;
  public
    constructor Create(APool: TThreadPool; const AInfoHash: TUniString;
      const ATrackerURL: string; const APeerID: string; APort: TIdPort);
    destructor Destroy; override;
  end;

implementation

uses
  Bittorrent.Tracker.HTTPTracker.PeerInfo;

{ THTTPTracker }

procedure THTTPTracker.DoAnnounce;
var
  sb: TStringBuilder;
  ms: TMemoryStream;
begin
  Lock;
  try
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

        BencodeParse(ms, False, ParseResponse);
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

  FLastRequest := MinDateTime;
  FPeers := TList<IHTTPTrackerPeerInfo>.Create;
end;

destructor THTTPTracker.Destroy;
begin
  FHTTP.Free;
  //FSSL.Free;
  FPeers.Free;
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

function THTTPTracker.GetPeers: TList<IHTTPTrackerPeerInfo>;
begin
  Result := FPeers;
end;

function THTTPTracker.GetPort: TIdPort;
begin
  Result := FPort;
end;

function THTTPTracker.GetUploaded: UInt64;
begin
  Result := FUploaded;
end;

function THTTPTracker.ParseResponse(ALen: Integer;
  AValue: IBencodedValue): Boolean;

  procedure ParsePeerList(const APeers: TUniString);
  var
    i: Integer;
    bytes: TIdBytes;
    host: string;
    port: TIdPort;
  begin
    Assert(APeers.Len mod 6 = 0);

    SetLength(bytes, APeers.Len);
    Move(APeers.DataPtr[0]^, bytes[0], APeers.Len);

    i := 0;
    while i < APeers.Len do
    begin
      host := BytesToIPv4Str(bytes, i);
      Inc(i, 4);

      port := LittleEndianToHost(BytesToUInt16(bytes, i));
      Inc(i, 2);

      FPeers.Add(THTTPTrackerPeerInfo.Create('', host, port) as IHTTPTrackerPeerInfo);
    end;
  end;

  procedure ParsePeers(APeersDict: IBencodedValue);
  begin
    Assert(Supports(APeersDict, IBencodedDictionary));
    FPeers.Clear;

    with APeersDict as IBencodedDictionary do
    if Supports(Items[PeersKey], IBencodedDictionary) then
    begin
      //it := Items[PeersKey] as IBencodedDictionary;
    end else
    if Supports(Items[PeersKey], IBencodedString) then
      ParsePeerList((Items[PeersKey] as IBencodedString).Value)
    else
      raise ETrackerInvalidKey.CreateFmt('Invalid key "%s"', [PeersKey]);
  end;

begin
  Assert(Supports(AValue, IBencodedDictionary));

  with AValue as IBencodedDictionary do
  if ContainsKey(FailureReasonKey) then
  begin
    Assert(Supports(Items[FailureReasonKey], IBencodedString));

    FFailureResponse := (Items[FailureReasonKey]as IBencodedString).Value;

    raise ETrackerFailure.Create(FFailureResponse);
  end else
  begin
    if ContainsKey(CompleteKey) then
    begin
      Assert(Supports(Items[CompleteKey], IBencodedInteger));
//      FComplet := (Items[CompleteKey] as IBencodedInteger).Value;
    end;

    if ContainsKey(DownloadedKey) then
    begin
      Assert(Supports(Items[DownloadedKey], IBencodedInteger));
      FDownloaded := (Items[DownloadedKey] as IBencodedInteger).Value;
    end;

    if ContainsKey(IncompleteKey) then
    begin
      Assert(Supports(Items[IncompleteKey], IBencodedInteger));
//      FIncomplete := (Items[IncompleteKey] as IBencodedInteger).Value;
    end;

    if ContainsKey(PeersKey) then
      ParsePeers(Items[PeersKey]);

    if ContainsKey(IntervalKey) then
    begin
      Assert(Supports(Items[IntervalKey], IBencodedInteger));
      FInterval := (Items[IntervalKey] as IBencodedInteger).Value;
    end;

    if ContainsKey(MinIntervalKey) then
    begin
      Assert(Supports(Items[MinIntervalKey], IBencodedInteger));
      FMinInterval := (Items[MinIntervalKey] as IBencodedInteger).Value;
    end;
  end;

  Result := True;
end;

procedure THTTPTracker.DoScrape;
var
  response: string;
begin
  Lock;
  try
    response := FHTTP.Get(FScrapeURL + '?info_hash=' + TIdURI.ParamsEncode(FInfoHash));
  finally
    Unlock;
  end;
end;

procedure THTTPTracker.SetCorrupt(const Value: UInt64);
begin
  FCorrupt := Value;
end;

procedure THTTPTracker.SetDownloaded(const Value: UInt64);
begin
  FDownloaded := Value;
end;

procedure THTTPTracker.SetEvent(const Value: THTTPTrackerEvent);
begin
  FEvent := Value;
end;

procedure THTTPTracker.SetLeft(const Value: UInt64);
begin
  FLeft := Value;
end;

procedure THTTPTracker.SetUploaded(const Value: UInt64);
begin
  FUploaded := Value;
end;

end.
