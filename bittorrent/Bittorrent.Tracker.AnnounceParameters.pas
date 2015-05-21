unit Bittorrent.Tracker.AnnounceParameters;

interface

uses
  Bittorrent,
  Basic.UniString,
  IdGlobal;

type
  TAnnounceParameters = class(TInterfacedObject, IAnnounceParameters)
  private
    FBytesDownloaded: UInt64;
    FBytesLeft: UInt64;
    FBytesUploaded: UInt64;
    FSeedingState: TSeedingState;
    FInfoHash: TUniString;
    FIPAddress: string;
    FPeerID: TUniString;
    FPort: TIdPort;
    FRequireEncryption: Boolean;
    FSupportsEncryption: Boolean;

    function GetBytesDownloaded: UInt64; inline;
    function GetBytesLeft: UInt64; inline;
    function GetBytesUploaded: UInt64; inline;
    function GetSeedingState: TSeedingState; inline;
    function GetInfoHash: TUniString; inline;
    function GetIPAddress: string; inline;
    function GetPeerID: TUniString; inline;
    function GetPort: TIdPort; inline;
    function GetRequireEncryption: Boolean; inline;
    function GetSupportsEncryption: Boolean; inline;
  public
    constructor Create(const ABytesDownloaded, ABytesLeft, ABytesUploaded: UInt64;
      ASeedingState: TSeedingState; const AInfoHash: TUniString;
      const AIPAddress: string; const APeerID: TUniString; APort: TIdPort;
      ARequireEncryption, ASupportsEncryption: Boolean);
  end;

implementation

{ TAnnounceParameters }

constructor TAnnounceParameters.Create(const ABytesDownloaded, ABytesLeft,
  ABytesUploaded: UInt64; ASeedingState: TSeedingState;
  const AInfoHash: TUniString; const AIPAddress: string;
  const APeerID: TUniString; APort: TIdPort; ARequireEncryption,
  ASupportsEncryption: Boolean);
begin
  inherited Create;

  FBytesDownloaded := ABytesDownloaded;
  FBytesLeft := ABytesLeft;
  FBytesUploaded := ABytesUploaded;
  FSeedingState := ASeedingState;
  FInfoHash.Assign(AInfoHash);
  FIPAddress := AIPAddress;
  FPeerID.Assign(APeerID);
  FPort := APort;
  FRequireEncryption := ARequireEncryption;
  FSupportsEncryption := ASupportsEncryption;
end;

function TAnnounceParameters.GetBytesDownloaded: UInt64;
begin
  Result := FBytesDownloaded;
end;

function TAnnounceParameters.GetBytesLeft: UInt64;
begin
  Result := FBytesLeft;
end;

function TAnnounceParameters.GetBytesUploaded: UInt64;
begin
  Result := FBytesUploaded;
end;

function TAnnounceParameters.GetInfoHash: TUniString;
begin
  Result := FInfoHash;
end;

function TAnnounceParameters.GetIPAddress: string;
begin
  Result := FIPAddress;
end;

function TAnnounceParameters.GetPeerID: TUniString;
begin
  Result := FPeerID
end;

function TAnnounceParameters.GetPort: TIdPort;
begin

end;

function TAnnounceParameters.GetRequireEncryption: Boolean;
begin

end;

function TAnnounceParameters.GetSeedingState: TSeedingState;
begin
  Result := FSeedingState;
end;

function TAnnounceParameters.GetSupportsEncryption: Boolean;
begin

end;

end.
