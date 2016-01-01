unit DHT.Peer;

interface

uses
  System.Classes, System.SysUtils, System.Generics.Defaults,
  Basic.UniString, Basic.Bencoding,
  Common.Prelude,
  DHT, DHT.Common,
  IdGlobal, IdStack, IdIPAddress;

type
  TPeer = class(TInterfacedObject, IPeer)
  private
    FHost: string;
    FPort: TIdPort;
    function GetHost: string; inline;
    function GetPort: TIdPort; inline;

    function GetCompactAddress: TUniString; inline;
  public
    constructor Create(const AHost: string; APort: TIdPort);

    class function Decode(APeers: IBencodedList): TArray<IPeer>; static;
    class function FromCompactPeer(APeerInfo: TUniString): IPeer; static;
    class function DecodeFromDict(ADict: IBencodedDictionary): IPeer; static;
  end;

implementation

{ TPeer }

function TPeer.GetCompactAddress: TUniString;
var
  buff: TIdBytes;
  ip: TIdIPAddress;
begin
  ip := TIdIPAddress.MakeAddressObject(FHost);

  if Assigned(ip) then
  try
    buff := ip.HToNBytes;

    Result.Len := Length(buff);
    Move(buff[0], Result.DataPtr[0]^, Length(buff));
  finally
    ip.Free;
  end else
    Result.Len := 0;
end;

constructor TPeer.Create(const AHost: string; APort: TIdPort);
begin
  inherited Create;

  FHost := AHost;
  FPort := APort;
end;

class function TPeer.Decode(APeers: IBencodedList): TArray<IPeer>;
var
  value: IBencodedValue;
  d: IBencodedDictionary;
  s: IBencodedString;
begin
  SetLength(Result, 0);

  for value in APeers.Childs do
  try
    if Supports(value, IBencodedDictionary, d) then
      TAppender.Append<IPeer>(Result, DecodeFromDict(d))
    else
    if Supports(value, IBencodedString, s) then
      TAppender.Append<IPeer>(Result, FromCompactPeer(s.Value))
    else
      raise EDHTException.Create('Invalid peers list items');
  except
    // If something is invalid and throws an exception, ignore it
    // and continue decoding the rest of the peers
  end;
end;

class function TPeer.DecodeFromDict(ADict: IBencodedDictionary): IPeer;
//var
//  peerId: string;
//  connectionUri: TVarSin;
begin
//  { в каком формате приходят к нам значения? }
//  if ADict.ContainsKey('peer id') then
//    peerId := (ADict['peer id'] as IBencodedString).Value.AsString
//  else
//  // HACK: Some trackers return "peer_id" instead of "peer id"
//  if ADict.ContainsKey('peer_id') then
//    peerId := (ADict['peer_id'] as IBencodedString).Value.AsString
//  else
//    peerId := '';
//
//  connectionUri.Clear;
//  Result := TPeer.Create(peerId, connectionUri{, EncryptionTypes.All});
end;

class function TPeer.FromCompactPeer(APeerInfo: TUniString): IPeer;
var
  ip: TIdIPAddress;
  port: TIdPort;
begin
  // "Compact Response" peers are encoded in network byte order.
  // IP's are the first four bytes
  // Ports are the following 2 bytes

  Assert(APeerInfo.Len = SizeOf(Cardinal) + SizeOf(TIdPort));

  GStack.IncUsage;
  try
    ip := TIdIPAddress.Create;
    try
      // нужна поддержка IPv6
      ip.AddrType := Id_IPv4;
      ip.IPv4 := GStack.NetworkToHost(LongWord(
        APeerInfo.Copy(0, Cardinal.Size).AsInteger
      ));
      port := GStack.NetworkToHost(Word(
        APeerInfo.Copy(Cardinal.Size, SizeOf(TIdPort)).AsWord
      ));

      Result := TPeer.Create(ip.IPAsString, port);
    finally
      ip.Free;
    end;
  finally
    GStack.DecUsage;
  end;
end;

function TPeer.GetHost: string;
begin
  Result := FHost;
end;

function TPeer.GetPort: TIdPort;
begin
  Result := FPort;
end;

end.
