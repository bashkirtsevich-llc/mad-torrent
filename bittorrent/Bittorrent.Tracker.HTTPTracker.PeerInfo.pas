unit Bittorrent.Tracker.HTTPTracker.PeerInfo;

interface

uses
  Bittorrent,
  Basic.UniString,
  IdGlobal;

type
  THTTPTrackerPeerInfo = class(TInterfacedObject, IHTTPTrackerPeerInfo)
  private
    FPeerID: TUniString;
    FHost: string;
    FPort: TIdPort;

    function GetPeerID: TUniString; inline;
    function GetHost: string; inline;
    function GetPort: TIdPort; inline;
  public
    constructor Create(const APeerID: TUniString; const AHost: string;
      APort: TIdPort);
  end;

implementation

{ THTTPTrackerPeerInfo }

constructor THTTPTrackerPeerInfo.Create(const APeerID: TUniString;
  const AHost: string; APort: TIdPort);
begin
  inherited Create;

  FPeerID.Assign(APeerID);
  FHost := AHost;
  FPort := APort;
end;

function THTTPTrackerPeerInfo.GetHost: string;
begin
  Result := FHost;
end;

function THTTPTrackerPeerInfo.GetPeerID: TUniString;
begin
  Result := FPeerID;
end;

function THTTPTrackerPeerInfo.GetPort: TIdPort;
begin
  Result := FPort;
end;

end.
