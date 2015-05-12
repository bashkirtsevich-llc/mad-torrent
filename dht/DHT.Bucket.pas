unit DHT.Bucket;

interface

uses
  System.SysUtils,
  Common,
  DHT.Engine, DHT.NodeID;

type
  TBucket = class(TInterfacedObject, IBucket)
  public
    const
      MaxCapacity: Integer = 8;
  private
    FLastChanged: TDateTime;
    FMin, FMax: TNodeID;
    FNodes: TGenList<INode>;
    FReplacement: INode;
    function GetLastChanged: TDateTime; inline;
    procedure SetLastChanged(const Value: TDateTime); inline;
    function GetMax: TNodeID; inline;
    function GetMin: TNodeID; inline;
    function GetNodes: TGenList<INode>; inline;
    function GetReplacement: INode; inline;
    procedure SetReplacement(const Value: INode); inline;
  public
    constructor Create; reintroduce; overload;
    constructor Create(AMin, AMax: TNodeID); overload;
    destructor Destroy; override;

    function GetHashCode: Integer; override;
//    function ToString: string; override;
  private
    function Add(ANode: INode): Boolean;
    procedure SortBySeen;

    function CanContain(ANode: INode): Boolean; overload; inline;
    function CanContain(ANodeID: TNodeID): Boolean; overload; inline;

    function CompareTo(AOther: IBucket): Integer;

    function Equals(AOther: IBucket): Boolean; reintroduce;
  end;

implementation

{ TBucket }

function TBucket.Add(ANode: INode): Boolean;
var
  i: Integer;
begin
  if FNodes.Count < MaxCapacity then
  begin
    FNodes.Add(ANode);
    FLastChanged := UtcNow;
    Exit(True);
  end;

  for i := FNodes.Count - 1 downto 0 do
  begin
    if FNodes[i].State <> TNodeState.nsBad then
      continue;

    FNodes.Delete(i);
    FNodes.Add(ANode);
    FLastChanged := Now;
    Exit(True);
  end;

  Result := False;
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

  FLastChanged := UtcNow;

  FNodes := TGenList<INode>.Create;
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

function TBucket.GetNodes: TGenList<INode>;
begin
  Result := FNodes;
end;

function TBucket.GetReplacement: INode;
begin
  Result := FReplacement;
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

//function TBucket.ToString: string;
//begin
//  //Result := Format('Count: %d Min: {0}  Max: {1}', [FMin, FMax, FNodes.Count]);
//end;

end.
