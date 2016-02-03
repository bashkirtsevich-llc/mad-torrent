unit Bittorrent.Tracker.HTTP;

interface

uses
  System.Classes, System.SysUtils, System.StrUtils,
  Basic.Bencoding, Basic.UniString,
  Common.ThreadPool,
  Bittorrent, Bittorrent.Tracker,
  IdGlobal, IdHTTP, IdStack, IdURI;

type
  THTTPTracker = class(TWebTracker, IHTTPTracker)
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

      FilesKey            = 'files';
      FlagsKey            = 'flags';
      MinRespinseIntervalKey = 'min_request_interval';
      NameKey             = 'name';

      PeerIDLen           = 20;
  private
    FScrapeURL: string;
    FPeerID: TUniString;

    FCompleted: Integer;
    FDownloaded: Integer;
    FIncompleted: Integer;

    function ConvertScrapeURL(const AURL: string): string; inline;

    procedure HTTPRequest(ACallback: TProc<TIdHTTP>);

    function ParseAnnounceResponse(ALen: Integer; AValue: IBencodedValue): Boolean;
    function ParseScrapeResponse(ALen: Integer; AValue: IBencodedValue): Boolean;
  protected
    procedure DoAnnounce; override; final;
    procedure DoRetrack; override; final;
  public
    constructor Create(AThreadPool: TThreadPool; const AInfoHash: TUniString;
      AAnnouncePort: TIdPort; AAnnounceInterval, ARetrackInterval: Integer;
      ATrackerURL: string; const APeerID: TUniString); reintroduce;
  end;

implementation

{ THTTPTracker }

function THTTPTracker.ConvertScrapeURL(const AURL: string): string;
var
  i: Integer;
  s: string;
begin
  i := AURL.LastIndexOf('/');
  s := System.StrUtils.IfThen(i + 9 <= AURL.Length, AURL.Substring(i + 1, 8));
  if s.ToLower = 'announce' then
    Result := AURL.Substring(1, i) + 'scrape' + AURL.Substring(i + 9, AURL.Length - i - 9)
  else
    Result := string.Empty;
end;

constructor THTTPTracker.Create(AThreadPool: TThreadPool;
  const AInfoHash: TUniString; AAnnouncePort: TIdPort; AAnnounceInterval,
  ARetrackInterval: Integer; ATrackerURL: string; const APeerID: TUniString);
begin
  inherited Create(AThreadPool, AInfoHash, AAnnouncePort, AAnnounceInterval,
    ARetrackInterval, ATrackerURL);

  FScrapeURL := ConvertScrapeURL(ATrackerURL);
  FPeerID.Assign(APeerID);
end;

procedure THTTPTracker.DoAnnounce;
var
  sb: TStringBuilder;
  ms: TMemoryStream;
begin
  try
    HTTPRequest(procedure (AHTTP: TIdHTTP)
    begin
      sb := TStringBuilder.Create(FTrackerURL);
      try
        // урл может содержать в себе параметр (.../ann.php?uk=blablabla)
        sb.Append(System.StrUtils.IfThen(FTrackerURL.Contains('?'), '&', '?'))
          .Append('info_hash='  ).Append(TIdURI.ParamsEncode(FInfoHash, IndyTextEncoding_8Bit))
          .Append('&peer_id='   ).Append(TIdURI.ParamsEncode(FPeerID, IndyTextEncoding_8Bit))
          .Append('&port='      ).Append(FAnnouncePort)
          .Append('&uploaded='  ).Append(FBytesUploaded)
          .Append('&downloaded=').Append(FBytesDownloaded)
          .Append('&left='      ).Append(FBytesLeft)
          .Append('&corrupt='   ).Append(FBytesCorrupt)
          //.Append('&key='       ).Append(TIdURI.ParamsEncode(FKey, IndyTextEncoding_8Bit))
          //.Append('&event='     ).Append(FTrackerState.AsString)
          .Append('&numwant='   ).Append(200)
          .Append('&compact='   ).Append(1)
          .Append('&no_peer_id=').Append(1);

        ms := TMemoryStream.Create;
        try
          AHTTP.Get(sb.ToString, ms);

          BencodeParse(ms, False, ParseAnnounceResponse);
        finally
          ms.Free;
        end;
      finally
        sb.Free;
      end;
    end);
  except
    FAnnounceInterval := 60;
  end;

  inherited DoAnnounce;
end;

procedure THTTPTracker.DoRetrack;
var
  sb: TStringBuilder;
  ms: TMemoryStream;
begin
  if not FScrapeURL.IsEmpty then
  try
    HTTPRequest(procedure (AHTTP: TIdHTTP)
    begin
      sb := TStringBuilder.Create(FScrapeURL);
      try
        // урл может содержать в себе параметр (.../scrape.php?uk=blablabla)
        sb.Append(System.StrUtils.IfThen(FTrackerURL.Contains('?'), '&', '?'))
          .Append('info_hash='  ).Append(TIdURI.ParamsEncode(FInfoHash, IndyTextEncoding_8Bit));

        ms := TMemoryStream.Create;
        try
          AHTTP.Get(sb.ToString, ms);

          BencodeParse(ms, False, ParseScrapeResponse);
        finally
          ms.Free;
        end;
      finally
        sb.Free;
      end;
    end);
  except
  end;

  inherited DoRetrack;
end;

procedure THTTPTracker.HTTPRequest(ACallback: TProc<TIdHTTP>);
var
  http: TIdHTTP;
begin
  Assert(Assigned(ACallback));

  try
    http := TIdHTTP.Create(nil);
    try
      ACallback(http);
    finally
      http.Free;
    end;
  except
    FAnnounceInterval := 60;
  end;
end;

function THTTPTracker.ParseAnnounceResponse(ALen: Integer;
  AValue: IBencodedValue): Boolean;

  procedure ParsePeerList(ADict: IBencodedDictionary);
  begin
    {TODO -oMAD -cMajor : реализовать}
    (*peers: (dictionary model) The value is a list of dictionaries, each with the following keys:
        peer id : peer's self-selected ID, as described above for the tracker request (string)
        ip      : peer's IP address either IPv6 (hexed) or IPv4 (dotted quad) or DNS name (string)
        port    : peer's port number (integer)*)
  end;

  procedure ParsePeerString(const APeers: TUniString);
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

      GStack.IncUsage;
      try
        port := GStack.NetworkToHost(BytesToUInt16(bytes, i));
      finally
        GStack.DecUsage;
      end;
      Inc(i, 2);

      ResponsePeerInfo(host, port);
    end;
  end;

  procedure ParsePeers(APeers: IBencodedValue); inline;
  begin
    Assert(Supports(APeers, IBencodedList) or
      Supports(APeers, IBencodedString));

    if Supports(APeers, IBencodedList) then
      ParsePeerList(APeers as IBencodedDictionary)
    else
    if Supports(APeers, IBencodedString) then
      ParsePeerString((APeers as IBencodedString).Value);
  end;

begin
  Assert(Supports(AValue, IBencodedDictionary));

  with AValue as IBencodedDictionary do
  if ContainsKey(FailureReasonKey) then
  begin
    Assert(Supports(Items[FailureReasonKey], IBencodedString));

    raise ETrackerFailure.Create((Items[FailureReasonKey]as IBencodedString).Value);
  end else
  begin
    Assert(ContainsKey(PeersKey));
    ParsePeers(Items[PeersKey]);

    Assert(ContainsKey(IntervalKey) and Supports(Items[IntervalKey], IBencodedInteger));
    FAnnounceInterval := (Items[IntervalKey] as IBencodedInteger).Value;

    (* опциональная хрень, для пиров, которые не могут реаннонсить медленнее, чем указано в «IntervalKey»
    Assert(ContainsKey(MinIntervalKey) and Supports(Items[MinIntervalKey], IBencodedInteger));
    FMinInterval := (Items[MinIntervalKey] as IBencodedInteger).Value;*)
  end;

  Result := False;
end;

function THTTPTracker.ParseScrapeResponse(ALen: Integer;
  AValue: IBencodedValue): Boolean;

  procedure ParseFiles(AFilesDict: IBencodedDictionary);
  begin
    Assert(AFilesDict.ContainsKey(FInfoHash) and Supports(AFilesDict[FInfoHash], IBencodedDictionary));

    with AFilesDict[FInfoHash] as IBencodedDictionary do
    begin
      Assert(ContainsKey(CompleteKey) and ContainsKey(DownloadedKey) and ContainsKey(IncompleteKey));

      Assert(Supports(Items[CompleteKey], IBencodedInteger));
      FCompleted := (Items[CompleteKey] as IBencodedInteger).Value;

      Assert(Supports(Items[DownloadedKey], IBencodedInteger));
      FDownloaded := (Items[DownloadedKey] as IBencodedInteger).Value;

      Assert(Supports(Items[IncompleteKey], IBencodedInteger));
      FIncompleted := (Items[IncompleteKey] as IBencodedInteger).Value;

//      optional
//      if ContainsKey(NameKey) then
//      begin
//        Assert(Assert(Items[NameKey], IBencodedString));
//        {}
//      end;
    end;
  end;

  procedure ParseFlags(AFlagsDict: IBencodedDictionary);
  begin
    if AFlagsDict.ContainsKey(MinRespinseIntervalKey) then
    begin
      Assert(Supports(AFlagsDict[MinRespinseIntervalKey], IBencodedInteger));
      FRetrackInterval := (AFlagsDict[MinRespinseIntervalKey] as IBencodedInteger).Value;
    end;
  end;

begin
  (*
    Single Request
    Request:
    http://tracker/scrape?hash_id=xxxxxxxxxxxxxxxxxxxx

    Reply:
    d5:filesd20:xxxxxxxxxxxxxxxxxxxxd8:completei2e10:downloadedi0e10:incompletei4e
    4:name12:xxxxxxxxxxxxee5:flagsd20:min_request_intervali3600eee

    This tells us that torrent with hash 'xxxxxxxxxxxxxxxxxxxx' has 2 seeders, and 4 leechers. The torrent has been downloaded 0 times, and its name is xxxxxxxxxxxx. A scrape will not occur until at least 3600 seconds, or 60 minutes.
  *)
  Assert(Supports(AValue, IBencodedDictionary));

  { parse "files" dict }
  Assert((AValue as IBencodedDictionary).ContainsKey(FilesKey) and
    Supports((AValue as IBencodedDictionary)[FilesKey], IBencodedDictionary));

  ParseFiles((AValue as IBencodedDictionary)[FilesKey] as IBencodedDictionary);

  { parse "flags" dict }
  if (AValue as IBencodedDictionary).ContainsKey(FlagsKey) then
  begin
    Assert(Supports((AValue as IBencodedDictionary)[FlagsKey], IBencodedDictionary));

    ParseFlags((AValue as IBencodedDictionary)[FlagsKey] as IBencodedDictionary);
  end;

  Result := False;
end;

end.
