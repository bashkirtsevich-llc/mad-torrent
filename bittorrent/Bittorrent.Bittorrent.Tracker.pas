unit Shareman.Bittorrent.Tracker;

interface

uses
  System.Classes, System.SysUtils, System.StrUtils,
  Basic.UniString, Basic.Bencoding,
  Common.HTTP, Common.ThreadPool,
  Shareman, Shareman.Tracker, Shareman.Bittorrent,
  IdGlobal, IdURI, IdStack;

type
  TBTTracker = class(TTRacker)
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

      PeerIDLen           = 20;
  private
    FAnnounceInterval: Integer;
    FPeerID: TUniString;
    FKey: TUniString;

    function ParseAnnounceResponse(ALen: Integer; AValue: IBencodedValue): Boolean;
    function ParseScrapeResponse(ALen: Integer; AValue: IBencodedValue): Boolean;
  protected
    function GetScrapeURL(const AURL: string): string; override;
    function DoScrape: Boolean; override;
    function DoAnnounce: Boolean; override;
    function GetAnnounceInterval: Integer; override;
  public
    constructor Create(AThreadPoolEx: TThreadPool; const AURL: string;
      const AInfoHash: TUniString; APort: TIdPort;
      const APeerID: TUniString); reintroduce;
  end;

implementation

{ TBTTracker }

constructor TBTTracker.Create(AThreadPoolEx: TThreadPool; const AURL: string;
  const AInfoHash: TUniString; APort: TIdPort; const APeerID: TUniString);
begin
  inherited Create(AThreadPoolEx, AURL, AInfoHash, APort);

  FAnnounceInterval := 0;
  FPeerID.Assign(APeerID);
  Assert(FPeerID.Len = PeerIDLen);
  FKey := TUniString.FromRandom(4);
end;

function TBTTracker.DoAnnounce: Boolean;
var
  http: TNewIdHTTP;
  sb: TStringBuilder;
  ms: TMemoryStream;
begin
  try
    http := TNewIdHTTP.Create(nil);
    try
      sb := TStringBuilder.Create(FAnnounceURL);
      try
        // урл может содержать в себе параметр (.../ann.php?uk=blablabla)
        sb.Append(System.StrUtils.IfThen(FAnnounceURL.Contains('?'), '&', '?'))
          .Append('info_hash='  ).Append(TIdURI.ParamsEncode(FInfoHash, IndyTextEncoding_8Bit))
          .Append('&peer_id='   ).Append(TIdURI.ParamsEncode(FPeerID, IndyTextEncoding_8Bit))
          .Append('&port='      ).Append(FPort)
          .Append('&uploaded='  ).Append(FUploaded)
          .Append('&downloaded=').Append(FDownloaded)
          .Append('&left='      ).Append(FLeft)
          .Append('&corrupt='   ).Append(FCorrupt)
          .Append('&key='       ).Append(TIdURI.ParamsEncode(FKey, IndyTextEncoding_8Bit))
          //.Append('&event='     ).Append(FTrackerState.AsString)
          .Append('&numwant='   ).Append(200)
          .Append('&compact='   ).Append(1)
          .Append('&no_peer_id=').Append(1);

        ms := TMemoryStream.Create;
        try
          http.Get(sb.ToString, ms);

          BencodeParse(ms, False, ParseAnnounceResponse);

          Result := True;
        finally
          ms.Free;
        end;
      finally
        sb.Free;
      end;
    finally
      http.Free;
    end;
  except
    FAnnounceInterval := 60;
    Result := False;
  end;
end;

function TBTTracker.DoScrape: Boolean;
var
  http: TNewIdHTTP;
  ms: TMemoryStream;
begin
  try
    http := TNewIdHTTP.Create(nil);
    try
      ms := TMemoryStream.Create;
      try
        http.Get(FScrapeURL + '?info_hash=' + TIdURI.ParamsEncode(FInfoHash), ms);

        BencodeParse(ms, False, ParseScrapeResponse);;

        Result := True;
      finally
        ms.Free;
      end;
    finally
      http.Free;
    end;
  except
    Result := False;
  end;
end;

function TBTTracker.GetAnnounceInterval: Integer;
begin
  Result := FAnnounceInterval;
end;

function TBTTracker.GetScrapeURL(const AURL: string): string;
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

function TBTTracker.ParseAnnounceResponse(ALen: Integer;
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
        port := GStack.NetworkToHost(BytesToWord(bytes, i));
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

function TBTTracker.ParseScrapeResponse(ALen: Integer;
  AValue: IBencodedValue): Boolean;
begin
  Result := False;
end;

end.
