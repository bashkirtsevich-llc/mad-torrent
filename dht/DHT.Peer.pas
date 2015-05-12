unit DHT.Peer;

interface

uses
  System.SysUtils, System.Generics.Defaults,
  Socket.Synsock, Socket.SynsockHelper,
  Basic.UniString, Basic.Bencoding,
  Spring.Collections,
  DHT.Engine,
  IdGlobal;

type
  TPeer = class(TInterfacedObject, IPeer)
  private
    FCleanedUpCount: Integer;
    FConnectionUri: TVarSin;
    //encryption: TEncryptionTypes;
    FFailedConnectionAttempts: Integer;
    FLocalPort: TIdPort;
    FTotalHashFails: Integer;
    FIsSeeder: Boolean;
    FPeerId: string;
    FRepeatedHashFails: Integer;
    FLastConnectionAttempt: TDateTime;
    function CompactPeer: TUniString; inline;
    procedure HashedPiece(ASucceeded: Boolean);

    function GetConnectionUri: TVarSin; inline;
    function GetCleanedUpCount: Integer; inline;
    procedure SetCleanedUpCount(const Value: Integer); inline;
    function GetTotalHashFails: Integer; inline;
    procedure SetTotalHashFails(const Value: Integer); inline;
    function GetPeerId: string; inline;
    procedure SetPeerId(const Value: string); inline;
    function GetIsSeeder: Boolean; inline;
    procedure SetIsSeeder(const Value: Boolean); inline;
    function GetFailedConnectionAttempts: Integer; inline;
    procedure SetFailedConnectionAttempts(const Value: Integer); inline;
    function GetLocalPort: TIdPort; inline;
    procedure SetLocalPort(const Value: TIdPort); inline;
    function GetLastConnectionAttempt: TDateTime; inline;
    procedure SetLastConnectionAttempt(const Value: TDateTime); inline;
    function GetRepeatedHashFails: Integer; inline;
  public
    constructor Create(APeerID: string; AConnectionUri: TVarSin);
    function Equals(AOther: IPeer): Boolean; reintroduce;
    function GetHashCode: Integer; override;
    function ToString: string; override;

    class function Decode(APeers: IBencodedList): IList<IPeer>; overload; static;
    class function Decode(APeers: TUniString): IList<IPeer>; overload; static;
    class function DecodeFromDict(ADict: IBencodedDictionary): IPeer; static;
    class function Encode(APeers: IList<IPeer>): IBencodedList; static;
  end;

implementation

{ TPeer }

function TPeer.CompactPeer: TUniString;
begin
  Result := FConnectionUri.Serialize;
end;

constructor TPeer.Create(APeerID: string; AConnectionUri: TVarSin);
begin
  inherited Create;

  Assert(not AConnectionUri.IsIPEmpty, 'AConnectionUri not defined');

  FConnectionUri := AConnectionUri;
//  encryption = encryption;
  FpeerId := APeerID;
end;

class function TPeer.Decode(APeers: IBencodedList): IList<IPeer>;
var
  value: IBencodedValue;
  p: IPeer;
begin
  Result := TSprList<IPeer>.Create;

  for value in APeers.Childs do
  try
    if Supports(value, IBencodedDictionary) then
      Result.Add(DecodeFromDict(value as IBencodedDictionary))
    else
    if Supports(value, IBencodedString) then
      for p in Decode((value as IBencodedString).Value) do
        Result.Add(p);
  except
    // If something is invalid and throws an exception, ignore it
    // and continue decoding the rest of the peers
  end;
end;

class function TPeer.Decode(APeers: TUniString): IList<IPeer>;
var
  uri: TVarSin;
  tmp: TUniString;
begin
  // "Compact Response" peers are encoded in network byte order.
  // IP's are the first four bytes
  // Ports are the following 2 bytes

  Assert(APeers.Len mod 6 = 0, 'Invalid peers length');

  Result := TSprList<IPeer>.Create;
  tmp := APeers.Copy;

  while tmp.Len > 0 do
  begin
    uri.Clear;
    uri.AddressFamily := AF_INET;

    Move(tmp.DataPtr[0]^, uri.sin_addr.S_addr, 4);
    tmp.Delete(0, 4);
    Move(tmp.DataPtr[0]^, uri.sin_port, 2);
    tmp.Delete(0, 2);

    Result.Add(TPeer.Create('', uri{, EncryptionTypes.All}));
  end;
end;

class function TPeer.DecodeFromDict(ADict: IBencodedDictionary): IPeer;
var
  peerId: string;
  connectionUri: TVarSin;
begin
  { в каком формате приходят к нам значения? }
  if ADict.ContainsKey('peer id') then
    peerId := (ADict['peer id'] as IBencodedString).Value.AsString
  else
  // HACK: Some trackers return "peer_id" instead of "peer id"
  if ADict.ContainsKey('peer_id') then
    peerId := (ADict['peer_id'] as IBencodedString).Value.AsString
  else
    peerId := '';

  connectionUri.Clear;
  Result := TPeer.Create(peerId, connectionUri{, EncryptionTypes.All});
end;

class function TPeer.Encode(APeers: IList<IPeer>): IBencodedList;
var
  p: IPeer;
begin
  Result := BencodedList;
  for p in APeers do
    Result.Add(BencodeString(p.CompactPeer));
end;

function TPeer.Equals(AOther: IPeer): Boolean;
begin
  if not Assigned(AOther) then
    Exit(False);

  if (FPeerId = '') and (AOther.PeerId = '') then
    Result := FConnectionUri.sin_addr.S_addr = AOther.ConnectionUri.sin_addr.S_addr
  else
    Result := FPeerId = AOther.PeerId;
end;

function TPeer.GetCleanedUpCount: Integer;
begin
  Result := FCleanedUpCount;
end;

function TPeer.GetConnectionUri: TVarSin;
begin
  Result := FConnectionUri;
end;

function TPeer.GetFailedConnectionAttempts: Integer;
begin
  Result := FFailedConnectionAttempts;
end;

function TPeer.GetHashCode: Integer;
begin
  Result := BobJenkinsHash(FConnectionUri.sin_addr.S_addr, 4, 0);
end;

function TPeer.GetIsSeeder: Boolean;
begin
  Result := FIsSeeder;
end;

function TPeer.GetLastConnectionAttempt: TDateTime;
begin
  Result := FLastConnectionAttempt;
end;

function TPeer.GetLocalPort: TIdPort;
begin
  Result := FLocalPort;
end;

function TPeer.GetPeerId: string;
begin
  Result := FPeerId;
end;

function TPeer.GetRepeatedHashFails: Integer;
begin
  Result := FRepeatedHashFails;
end;

function TPeer.GetTotalHashFails: Integer;
begin
  Result := FTotalHashFails;
end;

procedure TPeer.HashedPiece(ASucceeded: Boolean);
begin
  if ASucceeded and (FRepeatedHashFails > 0) then
    Dec(FRepeatedHashFails);

  if not ASucceeded then
  begin
    Inc(FRepeatedHashFails);
    Inc(FTotalHashFails);
  end;
end;

procedure TPeer.SetCleanedUpCount(const Value: Integer);
begin
  FCleanedUpCount := Value;
end;

procedure TPeer.SetFailedConnectionAttempts(const Value: Integer);
begin
  FFailedConnectionAttempts := Value;
end;

procedure TPeer.SetIsSeeder(const Value: Boolean);
begin
  FIsSeeder := Value;
end;

procedure TPeer.SetLastConnectionAttempt(const Value: TDateTime);
begin
  FLastConnectionAttempt := Value;
end;

procedure TPeer.SetLocalPort(const Value: TIdPort);
begin
  FLocalPort := Value;
end;

procedure TPeer.SetPeerId(const Value: string);
begin
  FPeerId := Value;
end;

procedure TPeer.SetTotalHashFails(const Value: Integer);
begin
  FTotalHashFails := Value;
end;

function TPeer.ToString: string;
begin
  Result := FConnectionUri.ToString;
end;

end.
