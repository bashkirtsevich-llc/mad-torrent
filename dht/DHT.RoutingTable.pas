unit DHT.RoutingTable;

interface

uses
  System.SysUtils, System.Generics.Collections,
  Common.SortedList, Common.Prelude,
  DHT, DHT.Common, DHT.NodeID;

type
  TRoutingTable = class(TInterfacedObject, IRoutingTable)
  private
    FOnAddNode: TProc<INode>;
    FLocalNode: INode;
    FBuckets  : TList<IBucket>;
  private
    procedure RaiseNodeAdded(ANode: INode); inline;

    function Add(ANode: INode; ARaiseNodeAdded: Boolean): Boolean; overload;
    procedure Add(ABucket: IBucket); overload; inline;

    function FindNode(ANodeID: TNodeID): INode;
    function ContainsNode(ANodeID: TNodeID): Boolean; inline;

    procedure Remove(ABucket: IBucket); inline;
    function Split(ABucket: IBucket): Boolean;

    procedure Clear; inline;

    function Add(ANode: INode): Boolean; overload; inline;
    function GetNodesCount: Integer;
    function GetClosest(ATarget: TNodeID): TArray<INode>;

    function GetBuckets: TEnumerable<IBucket>; inline;
    function GetBucketsCount: Integer; inline;
    function GetLocalNode: INode; inline;
    function GetOnAddNode: TProc<INode>; inline;
    procedure SetOnAddNode(Value: TProc<INode>); inline;
  public
    constructor Create; overload;
    constructor Create(ALocalNode: INode); overload;
    destructor Destroy; override;
  end;

implementation

uses
  DHT.Bucket, DHT.Node;

{ TRoutingTable }

constructor TRoutingTable.Create;
begin
  Create(TNode.Create(TNodeID.New, string.Empty, 0));
end;

function TRoutingTable.Add(ANode: INode): Boolean;
begin
  Result := Add(ANode, True);
end;

function TRoutingTable.Add(ANode: INode; ARaiseNodeAdded: Boolean): Boolean;
var
  bucket: IBucket;
begin
  Result := False;

  Assert(Assigned(ANode));

  for bucket in FBuckets do
    if bucket.CanContain(ANode) then
    begin
      if not bucket.Contain(ANode) then
      begin
        Result := bucket.Add(ANode);
        if Result and ARaiseNodeAdded then
          RaiseNodeAdded(ANode);

        if ((not Result) and bucket.CanContain(FLocalNode)) and Split(bucket) then
          Result := Add(ANode, ARaiseNodeAdded);
      end else
        Result := False;

      Break;
    end;
end;

procedure TRoutingTable.Add(ABucket: IBucket);
begin
  FBuckets.Add(ABucket);
  FBuckets.Sort;
end;

procedure TRoutingTable.Clear;
begin
  FBuckets.Clear;
  Add(TBucket.Create as IBucket);
end;

function TRoutingTable.ContainsNode(ANodeID: TNodeID): Boolean;
begin
  Result := Assigned(FindNode(ANodeID));
end;

function TRoutingTable.GetNodesCount: Integer;
begin
  Result := TPrelude.Fold<IBucket, Integer>(FBuckets.ToArray, 0,
    function (X: Integer; Y: IBucket): Integer
    begin
      Result := X + Y.NodesCount;
    end
  );
end;

constructor TRoutingTable.Create(ALocalNode: INode);
begin
  inherited Create;

  Assert(Assigned(ALocalNode));

  FBuckets := TList<IBucket>.Create;

  FLocalNode := ALocalNode;
  FLocalNode.Seen;

  Add(TBucket.Create as IBucket);
end;

destructor TRoutingTable.Destroy;
begin
  FBuckets.Free;
  FLocalNode := nil;
  inherited;
end;

function TRoutingTable.FindNode(ANodeID: TNodeID): INode;
var
  b: IBucket;
  reslt: INode;
begin
  // использовать бинарный поиск
  for b in FBuckets do
    for reslt in b.Nodes do
      if reslt.ID.Equals(ANodeID) then
        Exit(reslt);

  Result := nil;
end;

function TRoutingTable.GetBuckets: TEnumerable<IBucket>;
begin
  Result := FBuckets;
end;

function TRoutingTable.GetBucketsCount: Integer;
begin
  Result := FBuckets.Count;
end;

function TRoutingTable.GetClosest(ATarget: TNodeID): TArray<INode>;
var
  b: IBucket;
  n: INode;
  distance: TNodeID;
  sortedNodes: TSortedList<TNodeID, INode>;
begin
  sortedNodes := TSortedList<TNodeID, INode>.Create(NodeIDSorter);
  try
    for b in FBuckets do
      for n in b.Nodes do
      begin
        distance := n.ID xor ATarget;
        if sortedNodes.Count = TBucket.MaxCapacity then
        begin
          if distance > sortedNodes.Keys[sortedNodes.Count - 1] then
            Continue;

          sortedNodes.Delete(sortedNodes.Count - 1);
        end;

        sortedNodes.Add(distance, n);
      end;

    Result := sortedNodes.Values.ToArray;
  finally
    sortedNodes.Free;
  end;
end;

function TRoutingTable.GetLocalNode: INode;
begin
  Result := FLocalNode;
end;

function TRoutingTable.GetOnAddNode: TProc<INode>;
begin
  Result := FOnAddNode;
end;

procedure TRoutingTable.RaiseNodeAdded(ANode: INode);
begin
  if Assigned(FOnAddNode) then
    FOnAddNode(ANode);
end;

procedure TRoutingTable.Remove(ABucket: IBucket);
begin
  FBuckets.Remove(ABucket);
end;

procedure TRoutingTable.SetOnAddNode(Value: TProc<INode>);
begin
  FOnAddNode := Value;
end;

function TRoutingTable.Split(ABucket: IBucket): Boolean;
var
  median: TNodeID;
  left, right: IBucket;
  n: INode;
begin
  if ABucket.Max - ABucket.Min < TNodeID(TBucket.MaxCapacity) then
    Exit(False);

  median  := (ABucket.Min + ABucket.Max) div 2;
  left    := TBucket.Create(ABucket.Min, median);
  right   := TBucket.Create(median, ABucket.Max);

  Remove(ABucket);
  Add(left);
  Add(right);

  for n in ABucket.Nodes do
    Add(n, False);

  if Assigned(ABucket.Replacement) then
    Add(ABucket.Replacement, False);

  Result := True;
end;

end.
