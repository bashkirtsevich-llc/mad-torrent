unit DHT.Common;

interface

uses
  System.Generics.Defaults,
  DHT.Engine, DHT.NodeID;

function NodeIDSorter: IComparer<TNodeId>;

implementation

function NodeIDSorter: IComparer<TNodeId>;
begin
  Result := TDelegatedComparer<TNodeId>.Create(
    function (const Left, Right: TNodeId): Integer
    begin
      if Left < Right then
        Result := -1
      else
      if Left > Right then
        Result := 1
      else
        Result := 0;
    end
  );
end;

end.
