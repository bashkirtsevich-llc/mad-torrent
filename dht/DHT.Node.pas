unit DHT.Node;

interface

uses
  System.SysUtils, System.DateUtils,
  Common.SortedList, Common.Prelude,
  Basic.Bencoding, Basic.UniString,
  DHT, DHT.NodeID, DHT.Common,
  IdGlobal, IdIPAddress, IdStack;

type
  TNode = class(TInterfacedObject, INode)
  private
    const
      MaxFailures = 4;
      IDKey       = 'id';
      NodeKey     = 'node';
  private
    FHost: string;
    FPort: TIdPort;
    FID: TNodeID;
    FFailedCount: Integer;
    FLastSeen: TDateTime;
    FToken: TUniString;
    function GetHost: string; inline;
    function GetPort: TIdPort; inline;
    function GetID: TNodeID; inline;
    function GetCompactAddress: TUniString; inline;
    function GetCompact: TUniString; inline;
    function GetState: TNodeState; inline;
    function GetToken: TUniString; inline;
    procedure SetToken(const Value: TUniString); inline;
    function GetLastSeen: TDateTime; inline;
    procedure SetLastSeen(const Value: TDateTime); inline;
    function GetFailedCount: Integer; inline;
    procedure SetFailedCount(const Value: Integer); inline;
    procedure Seen; inline;
  public
    class function CloserNodes(const ATarget: TNodeID;
      ACurrentNodes: TSortedList<TNodeId, TNodeId>;
      ANewNodes: TArray<INode>; AMaxNodes: Integer): TArray<INode>; static;

    class function FromCompactNode(ABuf: TUniString): TArray<INode>; static;
  public
    constructor Create(const ANodeID: TNodeID; const AHost: string;
      APort: TIdPort);
    function GetHashCode: Integer; override;
  public
    function CompareTo(AOther: INode): Integer;
    function Equals(AOther: INode): Boolean; reintroduce;
  end;

implementation

{ TNode }

class function TNode.CloserNodes(const ATarget: TNodeID;
  ACurrentNodes: TSortedList<TNodeId, TNodeId>; ANewNodes: TArray<INode>;
  AMaxNodes: Integer): TArray<INode>;
var
  node: INode;
  distance: TNodeID;
begin
  SetLength(Result, 0);

  for node in ANewNodes do
    if not ACurrentNodes.ContainsValue(node.ID) then
    begin
      distance := node.ID xor ATarget;

      if ACurrentNodes.Count < AMaxNodes then
        ACurrentNodes.Add(distance, node.ID)
      else
      if (ACurrentNodes.Count > 0) and (distance < ACurrentNodes.Last.Key) then
      begin
        { вымещаем дальний }
        ACurrentNodes.Delete(ACurrentNodes.Count - 1);
        ACurrentNodes.Add(distance, node.ID);
      end else
        Continue;

      TAppender.Append<INode>(Result, node);
    end;
end;

function TNode.CompareTo(AOther: INode): Integer;
begin
  if AOther = nil then
    Result := 1
  else
    Result := Ord(CompareDateTime(FLastSeen, AOther.LastSeen));
end;

constructor TNode.Create(const ANodeID: TNodeID; const AHost: string;
  APort: TIdPort);
begin
  inherited Create;

  FHost := AHost;
  FPort := APort;
  FID := ANodeID; { copy? }
end;

function TNode.Equals(AOther: INode): Boolean;
begin
  if AOther = nil then
    Result := False
  else
    Result := FID = AOther.ID;
end;

class function TNode.FromCompactNode(ABuf: TUniString): TArray<INode>;
const
  ItemLength = TNodeID.NodeIDLen + SizeOf(Cardinal) + SizeOf(TIdPort);
var
  i: Integer;
  ip: TIdIPAddress;
  port: TIdPort;
begin
  if ABuf.Len mod ItemLength <> 0 then
    raise EInvalidCompactNodesFormat.Create('Invalid compact nodes format');

  SetLength(Result, 0);

  GStack.IncUsage;
  try
    i := 0;
    while i < ABuf.Len do
    begin
      ip := TIdIPAddress.Create;
      try
        // нужна поддержка IPv6
        ip.AddrType := Id_IPv4;
        ip.IPv4 := GStack.NetworkToHost(LongWord(
          ABuf.Copy(i + TNodeID.NodeIDLen, Cardinal.Size).AsInteger
        ));
        port := GStack.NetworkToHost(Word(
          ABuf.Copy(i + TNodeID.NodeIDLen + Cardinal.Size, SizeOf(TIdPort)).AsWord
        ));

        TAppender.Append<INode>(Result,
          TNode.Create(ABuf.Copy(i, TNodeID.NodeIDLen), ip.IPAsString, port)
        );
      finally
        ip.Free;
      end;

      Inc(i, ItemLength);
    end;
  finally
    GStack.DecUsage;
  end;
end;

function TNode.GetCompact: TUniString;
begin
  Result := FID.AsUniString + GetCompactAddress;
end;

function TNode.GetCompactAddress: TUniString;
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

function TNode.GetFailedCount: Integer;
begin
  Result := FFailedCount;
end;

function TNode.GetHashCode: Integer;
begin
  Result := FID.AsUniString.GetHashCode;
end;

function TNode.GetHost: string;
begin
  Result := FHost;
end;

function TNode.GetID: TNodeID;
begin
  Result := FID;
end;

function TNode.GetLastSeen: TDateTime;
begin
  Result := FLastSeen;
end;

function TNode.GetPort: TIdPort;
begin
  Result := FPort;
end;

function TNode.GetState: TNodeState;
begin
  if FFailedCount >= MaxFailures then
    Result := nsBad
  else
  if FLastSeen = MinDateTime then
    Result := nsUnknown
  else
  if MinutesBetween(Now, FLastSeen) < 15 then
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
  FLastSeen := Now;
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

end.
