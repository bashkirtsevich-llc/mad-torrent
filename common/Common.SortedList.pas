unit Common.SortedList;

interface

uses
  System.Types, System.SysUtils, System.Generics.Defaults,
  System.Generics.Collections;

type
  TSortedList<TKey, TValue> = class(TList<TPair<TKey, TValue>>)
  private
    type
      TKeyEnumerator = class(TEnumerator<TKey>)
      private
        FSortedList: TSortedList<TKey,TValue>;
        FIndex: Integer;
        function GetCurrent: TKey;
      protected
        function DoGetCurrent: TKey; override;
        function DoMoveNext: Boolean; override;
      public
        constructor Create(const ASortedList: TSortedList<TKey,TValue>);
        property Current: TKey read GetCurrent;
        function MoveNext: Boolean;
      end;

      TValueEnumerator = class(TEnumerator<TValue>)
      private
        FSortedList: TSortedList<TKey, TValue>;
        FIndex: Integer;
        function GetCurrent: TValue;
      protected
        function DoGetCurrent: TValue; override;
        function DoMoveNext: Boolean; override;
      public
        constructor Create(const ASortedList: TSortedList<TKey, TValue>);
        property Current: TValue read GetCurrent;
        function MoveNext: Boolean;
      end;

      TValueCollection = class(TEnumerable<TValue>)
      private
        FSortedList: TSortedList<TKey, TValue>;
        function GetCount: Integer;
        function GetItem(AIndex: Integer): TValue;
      protected
        function DoGetEnumerator: TEnumerator<TValue>; override;
      public
        constructor Create(const ASortedList: TSortedList<TKey, TValue>);
        function GetEnumerator: TValueEnumerator; reintroduce;
        function ToArray: TArray<TValue>; override; final;
        function IndexOf(AValue: TValue): Integer;
        property Count: Integer read GetCount;
        property Items[AIndex: Integer]: TValue read GetItem; default;
      end;

      TKeyCollection = class(TEnumerable<TKey>)
      private
        FSortedList: TSortedList<TKey, TValue>;
        function GetCount: Integer;
        function GetItem(AIndex: Integer): TKey;
      protected
        function DoGetEnumerator: TEnumerator<TKey>; override;
      public
        constructor Create(const ASortedList: TSortedList<TKey, TValue>);
        function GetEnumerator: TKeyEnumerator; reintroduce;
        function ToArray: TArray<TKey>; override; final;
        property Count: Integer read GetCount;
        property Items[AIndex: Integer]: TKey read GetItem; default;
      end;
  private
    FComparer: IComparer<TPair<TKey, TValue>>;
    FKeyCollection: TKeyCollection;
    FValueCollection: TValueCollection;
    function GetKeys: TKeyCollection;
    function GetValues: TValueCollection;
  protected
    procedure Notify(const Item: TPair<TKey, TValue>; Action: TCollectionNotification); override;
  public
    function Add(const Key: TKey; const Value: TValue): Integer; reintroduce;

    function ContainsKey(const Key: TKey): Boolean;
    function ContainsValue(const Value: TValue): Boolean;

    property Keys: TKeyCollection read GetKeys;
    property Values: TValueCollection read GetValues;

    constructor Create(AComparer: IComparer<TKey>); reintroduce;
    destructor Destroy; override;
  end;

implementation

{ TSortedList<TKey, TValue> }

function TSortedList<TKey, TValue>.Add(const Key: TKey;
  const Value: TValue): Integer;
var
  it: TPair<TKey, TValue>;
begin
  it.Key := Key;
  it.Value := Value;

  inherited Add(it);
end;

function TSortedList<TKey, TValue>.ContainsKey(const Key: TKey): Boolean;
var
  it1, it2: TPair<TKey, TValue>;
begin
  it2.Key := Key;

  for it1 in Self do
    if FComparer.Compare(it1, it2) = 0 then
      Exit(True);

  Result := False;
end;

function TSortedList<TKey, TValue>.ContainsValue(const Value: TValue): Boolean;
var
  it: TPair<TKey, TValue>;
  c: IEqualityComparer<TValue>;
begin
  c := TEqualityComparer<TValue>.Default;

  for it in Self do
    if c.Equals(it.Value, Value) then
      Exit(True);

  Result := False;
end;

constructor TSortedList<TKey, TValue>.Create(AComparer: IComparer<TKey>);
begin
  FComparer := TDelegatedComparer<TPair<TKey, TValue>>.Create(
    function (const Left, Right: TPair<TKey, TValue>): Integer
    begin
      Result := AComparer.Compare(Left.Key, Right.Key);
    end
  );

  FKeyCollection := nil;
  FValueCollection := nil;

  inherited Create(FComparer);
end;

destructor TSortedList<TKey, TValue>.Destroy;
begin
  if Assigned(FKeyCollection) then
    FreeAndNil(FKeyCollection);

  if Assigned(FValueCollection) then
    FreeAndNil(FValueCollection);

  inherited;
end;

function TSortedList<TKey, TValue>.GetKeys: TKeyCollection;
begin
  if not Assigned(FKeyCollection) then
    FKeyCollection := TKeyCollection.Create(Self);

  Result := FKeyCollection;
end;

function TSortedList<TKey, TValue>.GetValues: TValueCollection;
begin
  if not Assigned(FValueCollection) then
    FValueCollection := TValueCollection.Create(Self);

  Result := FValueCollection;
end;

procedure TSortedList<TKey, TValue>.Notify(const Item: TPair<TKey, TValue>;
  Action: TCollectionNotification);
begin
  Sort;
  inherited Notify(Item, Action);
end;

{ TSortedList<TKey, TValue>.TKeyEnumerator }

constructor TSortedList<TKey, TValue>.TKeyEnumerator.Create(
  const ASortedList: TSortedList<TKey, TValue>);
begin
  inherited Create;
  FIndex := -1;
  FSortedList := ASortedList;
end;

function TSortedList<TKey, TValue>.TKeyEnumerator.DoGetCurrent: TKey;
begin
  Result := GetCurrent;
end;

function TSortedList<TKey, TValue>.TKeyEnumerator.DoMoveNext: Boolean;
begin
  Result := MoveNext;
end;

function TSortedList<TKey, TValue>.TKeyEnumerator.GetCurrent: TKey;
begin
  Result := FSortedList[FIndex].Key;
end;

function TSortedList<TKey, TValue>.TKeyEnumerator.MoveNext: Boolean;
begin
  Inc(FIndex);

  Result := FIndex < FSortedList.Count;
end;

{ TSortedList<TKey, TValue>.TValueEnumerator }

constructor TSortedList<TKey, TValue>.TValueEnumerator.Create(
  const ASortedList: TSortedList<TKey, TValue>);
begin
  inherited Create;
  FIndex := -1;
  FSortedList := ASortedList;
end;

function TSortedList<TKey, TValue>.TValueEnumerator.DoGetCurrent: TValue;
begin
  Result := GetCurrent;
end;

function TSortedList<TKey, TValue>.TValueEnumerator.DoMoveNext: Boolean;
begin
  Result := MoveNext;
end;

function TSortedList<TKey, TValue>.TValueEnumerator.GetCurrent: TValue;
begin
  Result := FSortedList[FIndex].Value;
end;

function TSortedList<TKey, TValue>.TValueEnumerator.MoveNext: Boolean;
begin
  Inc(FIndex);
  Result := FIndex < FSortedList.Count;
end;

{ TSortedList<TKey, TValue>.TValueCollection }

constructor TSortedList<TKey, TValue>.TValueCollection.Create(
  const ASortedList: TSortedList<TKey, TValue>);
begin
  inherited Create;
  FSortedList := ASortedList;
end;

function TSortedList<TKey, TValue>.TValueCollection.DoGetEnumerator: TEnumerator<TValue>;
begin
  Result := GetEnumerator;
end;

function TSortedList<TKey, TValue>.TValueCollection.GetCount: Integer;
begin
  Result := FSortedList.Count;
end;

function TSortedList<TKey, TValue>.TValueCollection.GetEnumerator: TValueEnumerator;
begin
  Result := TValueEnumerator.Create(FSortedList);
end;

function TSortedList<TKey, TValue>.TValueCollection.GetItem(
  AIndex: Integer): TValue;
begin
  Result := FSortedList[AIndex].Value;
end;

function TSortedList<TKey, TValue>.TValueCollection.IndexOf(
  AValue: TValue): Integer;
var
  it: TPair<TKey, TValue>;
  c: IEqualityComparer<TValue>;
begin
  c := TEqualityComparer<TValue>.Default;

  Result := 0;

  for it in FSortedList do
  begin
    if c.Equals(it.Value, AValue) then
      Exit;

    Inc(Result);
  end;

  Result := -1;
end;

function TSortedList<TKey, TValue>.TValueCollection.ToArray: TArray<TValue>;
var
  i: Integer;
begin
  SetLength(Result, GetCount);

  for i := 0 to GetCount - 1 do
    Result[i] := GetItem(i);
end;

{ TSortedList<TKey, TValue>.TKeyCollection }

constructor TSortedList<TKey, TValue>.TKeyCollection.Create(
  const ASortedList: TSortedList<TKey, TValue>);
begin
  inherited Create;
  FSortedList := ASortedList;
end;

function TSortedList<TKey, TValue>.TKeyCollection.DoGetEnumerator: TEnumerator<TKey>;
begin
  Result := GetEnumerator;
end;

function TSortedList<TKey, TValue>.TKeyCollection.GetCount: Integer;
begin
  Result := FSortedList.Count;
end;

function TSortedList<TKey, TValue>.TKeyCollection.GetEnumerator: TKeyEnumerator;
begin
  Result := TKeyEnumerator.Create(FSortedList);
end;

function TSortedList<TKey, TValue>.TKeyCollection.GetItem(
  AIndex: Integer): TKey;
begin
  Result := FSortedList[AIndex].Key;
end;

function TSortedList<TKey, TValue>.TKeyCollection.ToArray: TArray<TKey>;
begin

end;

end.
