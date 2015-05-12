unit DHT.RoutingTable;

interface

uses
  System.SysUtils,
  Spring.Collections,
  Socket.Synsock, Socket.SynsockHelper,
  Common.SortedList,
  DHT.Common, DHT.NodeID, DHT.Engine;

type
  TRoutingTable = class(TInterfacedObject, IRoutingTable)
  private
    FOnAddNode: TProc<INode>;
    FLocalNode: INode;
    FBuckets  : TGenList<IBucket>;
  private
    procedure RaiseNodeAdded(ANode: INode); inline;

    function Add(ANode: INode; ARaiseNodeAdded: Boolean): Boolean; overload;
    procedure Add(ABucket: IBucket); overload; inline;

    function FindNode(ANodeID: TNodeID): INode;

    procedure Remove(ABucket: IBucket); inline;
    function Split(ABucket: IBucket): Boolean;

    procedure Clear; inline;

    function Add(ANode: INode): Boolean; overload; inline;
    function CountNodes: Integer;
    function GetClosest(ATarget: TNodeID): IList<INode>;

    function GetBuckets: TGenList<IBucket>; inline;
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
var
  s: TVarSin;
begin
  s.Clear;
  Create(TNode.Create(TNodeID.New, s) as INode);
end;

function TRoutingTable.Add(ANode: INode): Boolean;
begin
  Result := Add(ANode, True);
end;

function TRoutingTable.Add(ANode: INode; ARaiseNodeAdded: Boolean): Boolean;
var
  bucket: IBucket;
  added: Boolean;
begin
  Assert(Assigned(ANode));

  bucket := nil;

  for bucket in FBuckets do
    if bucket.CanContain(ANode) then
      Break;

  if Assigned(bucket) then
  begin
    if bucket.Nodes.Contains(ANode) then
      Exit(False);

    added := bucket.Add(ANode);
    if added and ARaiseNodeAdded then
      RaiseNodeAdded(ANode);

    if ((not added) and bucket.CanContain(FLocalNode)) and Split(bucket) then
      Exit(Add(ANode, ARaiseNodeAdded));

    Result := added;
  end else
    Result := False;
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

function TRoutingTable.CountNodes: Integer;
var
  b: IBucket;
begin
  Result := 0;

  for b in FBuckets do
    Inc(Result, b.Nodes.Count);
end;

constructor TRoutingTable.Create(ALocalNode: INode);
begin
  inherited Create;

  Assert(Assigned(ALocalNode), 'ALocalNode not assigned');

  FBuckets := TGenList<IBucket>.Create;

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
  for b in FBuckets do
    for reslt in b.Nodes do
      if reslt.ID.Equals(ANodeID) then
        Exit(reslt);

  Result := nil;
end;

function TRoutingTable.GetBuckets: TGenList<IBucket>;
begin
  Result := FBuckets;
end;

function TRoutingTable.GetClosest(ATarget: TNodeID): IList<INode>;
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

    Result := TSprList<INode>.Create;
    for n in sortedNodes.Values do
      Result.Add(n);
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

  median := (ABucket.Min + ABucket.Max) div 2;
  left := TBucket.Create(ABucket.Min, median);
  right := TBucket.Create(median, ABucket.Max);

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
