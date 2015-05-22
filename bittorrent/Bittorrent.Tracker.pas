unit Bittorrent.Tracker;

interface

uses
  System.Classes, System.SysUtils, System.TimeSpan, System.StrUtils,
  Bittorrent,
  Basic.UniString,
  IdHTTP, IdURI;

type
  TTracker = class abstract(TInterfacedObject, ITracker)
  private
    FInfoHash: TUniString;
    FAnnounceURL: string;
    FScrapeURL: string;
    FTrackerResponse: TTrackerResponse;
    FTrackerResponseText: string;

    function GetInfoHash: TUniString; inline;
    function GetAnnounceURL: string; inline;
    function GetScrapeURL: string; inline;
    function GetCanAnnounce: Boolean; inline;
    function GetCanScrape: Boolean; inline;
    function GetTrackerResponse: TTrackerResponse; inline;
    function GetTrackerResponseText: string; inline;
  protected
    procedure Announce; virtual; abstract;
    procedure Scrape; virtual; abstract;
  public
    constructor Create(const AInfoHash: TUniString; const ATrackerURL: string);
  end;

  THTTPTracker = class(TTracker)
  private
    FHTTP: TIdHTTP;
  protected
    procedure Announce; override;
  public
    constructor Create(const AInfoHash: TUniString; const ATrackerURL: string);
    destructor Destroy; override;
  end;

implementation

{ TTracker }

constructor TTracker.Create(const AInfoHash: TUniString; const ATrackerURL: string);
var
  i: Integer;
  s: string;
begin
  inherited Create;

  FInfoHash.Assign(AInfoHash);
  FAnnounceURL := ATrackerURL;

  i := ATrackerURL.LastIndexOf('/');
  s := System.StrUtils.IfThen(i + 9 <= ATrackerURL.Length, ATrackerURL.Substring(i + 1, 8));
  if s.ToLower = 'announce' then
    FScrapeURL := ATrackerURL.Substring(1, i) + 'scrape' + ATrackerURL.Substring(i + 9, ATrackerURL.Length - i - 9);
end;

function TTracker.GetAnnounceURL: string;
begin
  Result := FAnnounceURL;
end;

function TTracker.GetCanAnnounce: Boolean;
begin
  Result := not FAnnounceURL.IsEmpty {and interval...};
end;

function TTracker.GetCanScrape: Boolean;
begin
  Result := not FScrapeURL.IsEmpty {and interval...};
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

{ THTTPTracker }

procedure THTTPTracker.Announce;
var
  sb: TStringBuilder;
begin
  Assert(GetCanAnnounce);

  sb := TStringBuilder.Create(FAnnounceURL);
  try
{ http://tracker.ru/announce
    ?info_hash=%1a%93%87s%26r%0d%a9%e6%89%1c%12%8a%3e%ec%c0%20%a0%82T
    &peer_id=-UT3230-%21pv0%7c%894%ad%8fI%de%f0
    &port=62402
    &uploaded=0
    &downloaded=0
    &left=0
    &corrupt=0
    &key=F883F9B9
    &event=started
    &numwant=200
    &compact=1
    &no_peer_id=1 }

    sb.Append('?info_hash=').Append(TIdURI.URLEncode(FInfoHash))
      .Append('&peer_id=').Append(FPeerID)
      .Append('&port=').Append(FPort)
      .Append('&uploaded=').Append(FDownloaded)
    ;
    FHTTP.Get(sb.ToString);
  finally
    sb.Free;
  end;
end;

constructor THTTPTracker.Create(const AInfoHash: TUniString;
  const ATrackerURL: string);
begin
  inherited Create(AInfoHash, ATrackerURL);

  FHTTP := TIdHTTP.Create(nil);
end;

destructor THTTPTracker.Destroy;
begin
  FHTTP.Free;
  inherited;
end;

end.
