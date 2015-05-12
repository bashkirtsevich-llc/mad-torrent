unit DHT.Node;

interface

uses
  System.SysUtils, System.DateUtils,
  Socket.Synsock, Socket.SynsockHelper,
  Spring.Collections,
  Common, Common.SortedList,
  Basic.Bencoding, Basic.UniString,
  DHT.Engine, DHT.NodeID,
  IdGlobal;

type
  TNode = class(TInterfacedObject, INode)
  private
    const
      MaxFailures = 4;
    const
      IDKey   = 'id';
      NodeKey = 'node';
  private
    FEndPoint: TVarSin;
    FID: TNodeID;
    FFailedCount: Integer;
    FLastSeen: TDateTime;
    FToken: TUniString;
    function GetState: TNodeState; inline;
    function GetToken: TUniString; inline;
    procedure SetToken(const Value: TUniString); inline;
    function GetLastSeen: TDateTime; inline;
    procedure SetLastSeen(const Value: TDateTime); inline;
    function GetID: TNodeID; inline;
    function GetFailedCount: Integer; inline;
    procedure SetFailedCount(const Value: Integer); inline;
    function GetEndPoint: TVarSin; inline;
    procedure Seen; inline;

    function CompactPort: TUniString; overload; inline;
    function CompactNode: TUniString; overload; inline;
    function BencodeNode: IBencodedDictionary; overload;
  public
    class function CompactPort(ASinAddr: TVarSin): TUniString; overload; static;
    class function CompactPort(APeers: IList<TVarSin>): TUniString; overload; static;
    class function CompactNode(ANode: INode): TUniString; overload; static;
    class function CompactNode(ANodes: IList<INode>): TUniString; overload; static;
    class function BencodeNode(ANode: INode): IBencodedDictionary; overload; static;
    class function BencodeNode(ANodes: IList<INode>): IBencodedList; overload; static;

    class function CloserNodes(
      const ATarger: TNodeID;
      ACurrentNodes: TSortedList<TNodeId, TNodeId>;
      ANewNodes: IList<INode>; AMaxNodes: Integer): IList<INode>; static;
    class function FromCompactNode(ABuf: TUniString): IList<INode>; static;
    class function FromBencodedNode(ANodes: IBencodedList): IList<INode>; static;
  public
    constructor Create(const ANodeID: TNodeID; const AEndPoint: TVarSin);
    function GetHashCode: Integer; override;
  public
    function CompareTo(AOther: INode): Integer;
    function Equals(AOther: INode): Boolean; reintroduce;
  end;

implementation

{ TNode }

class function TNode.CompactPort(ASinAddr: TVarSin): TUniString;
begin
  Result.Len := 0;

  case ASinAddr.AddressFamily of
    AF_INET:
      begin
        Result := Result + Integer(ASinAddr.sin_addr.S_addr) +
                           TIdPort(ASinAddr.sin_port);
      end;

    AF_INET6:
      begin
        Result.Len := 16;
        Move(ASinAddr.sin6_addr.S6_addr[0], Result.DataPtr[0]^, 16);
        Result := Result + TIdPort(ASinAddr.sin6_port);
      end;
  end;
end;

function TNode.CompactNode: TUniString;
begin
  Result := CompactNode(Self);
//  Result := Result.Len.ToString+':'+Result;
end;

class function TNode.CompactNode(ANode: INode): TUniString;
begin
  Result.Len := 0;
  Result := Result + ANode.ID.AsUniString + TNode.CompactPort(ANode.EndPoint);
end;

class function TNode.CloserNodes(const ATarger: TNodeID;
  ACurrentNodes: TSortedList<TNodeId, TNodeId>; ANewNodes: IList<INode>;
  AMaxNodes: Integer): IList<INode>;
var
  node: INode;
  distance: TNodeID;
begin
  Result := TSprList<INode>.Create;

  for node in ANewNodes do
  begin
    if ACurrentNodes.ContainsValue(node.ID) then
      Continue;

    distance := node.ID xor ATarger;
    if ACurrentNodes.Count < AMaxNodes then
      ACurrentNodes.Add(distance, node.ID)
    else
    if distance < ACurrentNodes.Keys[ACurrentNodes.Count - 1] then
    begin
      { вымещаем дальний }
      ACurrentNodes.Delete(ACurrentNodes.Count - 1);
      ACurrentNodes.Add(distance, node.ID);
    end else
      Continue;

    Result.Add(node);
  end;
end;

class function TNode.CompactNode(ANodes: IList<INode>): TUniString;
var
  n: INode;
begin
  Result.Len := 0;

  for n in ANodes do
    Result := Result + CompactNode(n);
end;

class function TNode.BencodeNode(ANode: INode): IBencodedDictionary;
begin
  Result := BencodedDictionary;
  Result.Add(BencodeString(IDKey), BencodeString(ANode.ID.AsUniString));
  Result.Add(BencodeString(NodeKey), BencodeString(ANode.EndPoint.Serialize));
end;

function TNode.BencodeNode: IBencodedDictionary;
begin
  Result := BencodeNode(Self);
end;

class function TNode.CompactPort(APeers: IList<TVarSin>): TUniString;
var
  s: TVarSin;
begin
  Result.Len := 0;

  for s in APeers do
    Result := Result + CompactPort(s);

//  Result := Result.Len.ToString+':'+Result;
end;

function TNode.CompareTo(AOther: INode): Integer;
begin
  if AOther = nil then
    Result := 1
  else
    Result := Ord(CompareDateTime(FLastSeen, AOther.LastSeen));
end;

function TNode.CompactPort: TUniString;
begin
  Result := CompactPort(FEndPoint);
//  Result := Result.Len.ToString+':'+Result;
end;

constructor TNode.Create(const ANodeID: TNodeID; const AEndPoint: TVarSin);
begin
  inherited Create;

  FEndPoint := AEndPoint;
  FID := ANodeID; { copy? }
end;

function TNode.Equals(AOther: INode): Boolean;
begin
  if AOther = nil then
    Result := False
  else
    Result := FID = AOther.ID;
end;

class function TNode.FromCompactNode(ABuf: TUniString): IList<INode>;
var
  tmp: TUniString;
  id: TNodeID;
  addr: TVarSin;
  port: TIdPort;
begin
  Result := TSprList<INode>.Create;

  tmp.Assign(ABuf);
  while tmp.Len > 0 do
  begin
    id := tmp.Copy(0, TNodeID.NodeIDLen);
    tmp.Delete(0, TNodeID.NodeIDLen);

    addr.AddressFamily := AF_INET;
    Move(tmp.DataPtr[0]^, addr.sin_addr.S_addr, 4);
    tmp.Delete(0, 4);

    Move(tmp.DataPtr[0]^, port, 2);
    addr.sin_port := {htons}(port); { там порт лежит в сетевом формате, переводить в локальный не надо, ибо sin_port должен быть в сетевом формате }
    tmp.Delete(0, 2);

    Result.Add(TNode.Create(id, addr) as INode);
  end;
end;

function TNode.GetEndPoint: TVarSin;
begin
  Result := FEndPoint;
end;

function TNode.GetFailedCount: Integer;
begin
  Result := FFailedCount;
end;

function TNode.GetHashCode: Integer;
begin
  Result := FID.AsUniString.GetHashCode;
end;

function TNode.GetID: TNodeID;
begin
  Result := FID;
end;

function TNode.GetLastSeen: TDateTime;
begin
  Result := FLastSeen;
end;

function TNode.GetState: TNodeState;
begin
  if FFailedCount >= MaxFailures then
    Exit(nsBad)
  else
  if FlastSeen = MinDateTime then
    Exit(nsUnknown);

  if MinutesBetween(UtcNow, GetLastSeen) < 15 then
    Result := nsGood
  else
    Result := nsQuestionable;
end;

function TNode.GetToken: TUniString;
begin
  Result := FToken;
end;

procedure TNode.Seen;
begin
  FFailedCount := 0;
  FLastSeen := UtcNow;
end;

procedure TNode.SetFailedCount(const Value: Integer);
begin
  FFailedCount := Value;
end;

procedure TNode.SetLastSeen(const Value: TDateTime);
begin
  FLastSeen := Value;
end;

procedure TNode.SetToken(const Value: TUniString);
begin
  FToken := Value;
end;

class function TNode.FromBencodedNode(ANodes: IBencodedList): IList<INode>;
var
  vals: IBencodedValue;
  node: INode;
  id: TUniString;
  endpoint: TVarSin;
begin
  Result := TSprList<INode>.Create;

  for vals in ANodes.Childs do
  begin
    //bad format!
    if not Supports(vals, IBencodedList) then
      Continue;

    with (vals as IBencodedDictionary) do
    begin
      endpoint.Clear;

      id := (Items[IDKey] as IBencodedString).Value;
      endpoint.Deserealize((Items[NodeKey] as IBencodedString).Value);
      node := TNode.Create(id, endpoint);

      Result.Add(node);
    end;
  end;
end;

class function TNode.BencodeNode(ANodes: IList<INode>): IBencodedList;
var
  n: INode;
begin
  Result := BencodedList;

  for n in ANodes do
    Result.Add(BencodeNode(n));
end;

end.
