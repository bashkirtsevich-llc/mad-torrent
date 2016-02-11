unit DHT.Bucket;

interface

uses
  System.SysUtils, System.Generics.Collections,
  DHT, DHT.NodeID;

type
  TBucket = class(TInterfacedObject, IBucket)
  public
    const
      MaxCapacity: Integer = 8;
  private
    FLastChanged: TDateTime;
    FMin, FMax: TNodeID;
    FNodes: TList<INode>;
    FReplacement: INode;
    function GetLastChanged: TDateTime; inline;
    procedure SetLastChanged(const Value: TDateTime); inline;
    function GetMax: TNodeID; inline;
    function GetMin: TNodeID; inline;
    function GetNodes: TEnumerable<INode>; inline;
    function GetNodesCount: Integer; inline;
    function GetReplacement: INode; inline;
    procedure SetReplacement(const Value: INode); inline;
  public
    constructor Create; reintroduce; overload;
    constructor Create(AMin, AMax: TNodeID); overload;
    destructor Destroy; override;

    function GetHashCode: Integer; override;
  private
    function Add(ANode: INode): Boolean;
    procedure SortBySeen;

    function CanContain(ANode: INode): Boolean; overload; inline;
    function CanContain(ANodeID: TNodeID): Boolean; overload; inline;
    function Contain(ANode: INode): Boolean; overload; inline;
    function Contain(ANodeID: TNodeID): Boolean; overload;

    function IndexOfNode(ANode: INode): Integer; inline;

    function CompareTo(AOther: IBucket): Integer;

    function Equals(AOther: IBucket): Boolean; reintroduce;
  end;

implementation

{ TBucket }

function TBucket.Add(ANode: INode): Boolean;
var
  i: Integer;
begin
  Result := False;

  if FNodes.Count < MaxCapacity then
  begin
    FNodes.Add(ANode);

    FLastChanged := Now;

    Result := True;
  end else
  for i := FNodes.Count - 1 downto 0 do
    if FNodes[i].State = TNodeState.nsBad then
    begin
      FNodes.Delete(i);
      FNodes.Add(ANode);

      FLastChanged := Now;

      Result := True;

      Break;
    end;
end;

function TBucket.CanContain(ANodeID: TNodeID): Boolean;
begin
  Result := (FMin <= ANodeID) and (FMax > ANodeID);
end;

function TBucket.CanContain(ANode: INode): Boolean;
begin
  Assert(Assigned(ANode), 'ANode not defined');

  Result := CanContain(ANode.ID);
end;

function TBucket.CompareTo(AOther: IBucket): Integer;
begin
  Result := FMin.CompareTo(AOther.Min);
end;

function TBucket.Contain(ANode: INode): Boolean;
begin
  Result := Contain(ANode.ID);
end;

function TBucket.Contain(ANodeID: TNodeID): Boolean;
var
  it: INode;
begin
  for it in FNodes do
    if it.ID = ANodeID then
      Exit(True);

  Result := False;
end;

constructor TBucket.Create;
var
  a, b: TBytes;
begin
  SetLength(a, TNodeID.NodeIDLen);
  SetLength(b, TNodeID.NodeIDLen);

  FillChar(b[0], TNodeID.NodeIDLen, $FF);

  Create(a, b);
end;

constructor TBucket.Create(AMin, AMax: TNodeID);
begin
  inherited Create;

  FMin := AMin;
  FMax := AMax;

  FLastChanged := Now;

  FNodes := TList<INode>.Create;
end;

destructor TBucket.Destroy;
begin
  FNodes.Free;
  inherited;
end;

function TBucket.Equals(AOther: IBucket): Boolean;
begin
  Result := FMin.Equals(AOther.Min) and FMax.Equals(AOther.Max);
end;

function TBucket.GetHashCode: Integer;
begin
  Result := FMin.GetHashCode xor FMax.GetHashCode;
end;

function TBucket.GetLastChanged: TDateTime;
begin
  Result := FLastChanged;
end;

function TBucket.GetMax: TNodeID;
begin
  Result := FMax;
end;

function TBucket.GetMin: TNodeID;
begin
  Result := FMin;
end;

function TBucket.GetNodes: TEnumerable<INode>;
begin
  Result := FNodes;
end;

function TBucket.GetNodesCount: Integer;
begin
  Result := FNodes.Count;
end;

function TBucket.GetReplacement: INode;
begin
  Result := FReplacement;
end;

function TBucket.IndexOfNode(ANode: INode): Integer;
begin
  Result := FNodes.IndexOf(ANode);
end;

procedure TBucket.SetLastChanged(const Value: TDateTime);
begin
  FLastChanged := Value;
end;

procedure TBucket.SetReplacement(const Value: INode);
begin
  FReplacement := Value;
end;

procedure TBucket.SortBySeen;
begin
  FNodes.Sort;
end;

end.
