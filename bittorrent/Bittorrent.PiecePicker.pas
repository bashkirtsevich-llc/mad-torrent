unit Bittorrent.PiecePicker;

interface

uses
  System.SysUtils, System.Generics.Collections, System.Generics.Defaults,
  System.Math,
  Common.SortedList,
  Bittorrent, Bittorrent.Bitfield {$IFDEF DEBUG}, IdGlobal{$ENDIF};

type
  TPicker = class abstract(TInterfacedObject, IPiecePicker)
  strict private
    FNextPicker: IPiecePicker;
    function GetNextPicker: IPiecePicker; inline;
    function GetFetchSize: Integer; inline;
    function Fetch(APeerHave: TBitField; APeersHave: TBitSum;
      AWant: TBitField): TArray<Integer>;
  strict protected
    FFetchSize: Integer;
    function PassToNextPicker: Boolean; virtual;
    function DoFetch(AAvailable: TBitField;
      APeersHave: TBitSum): TBitField; virtual; abstract;
  public
    constructor Create(ANextPicker: IPiecePicker; AFetchSize: Integer); reintroduce;
  end;

  TLinearPicker = class(TPicker)
  strict protected
    function DoFetch(AAvailable: TBitField;
      APeersHave: TBitSum): TBitField; override; final;
  end;

  TRandomPicker = class(TPicker)
  strict protected
    function DoFetch(AAvailable: TBitField;
      APeersHave: TBitSum): TBitField; override; final;
  end;

  TRarestFirstPicker = class(TPicker)
  strict private
    FSorter: IComparer<TPair<Integer {frequency}, Integer {piece index}>>;
  strict protected
    function DoFetch(AAvailable: TBitField;
      APeersHave: TBitSum): TBitField; override; final;
  public
    constructor Create(ANextPicker: IPiecePicker; AFetchSize: Integer); reintroduce;
  end;

  TPriorityPicker = class(TPicker)
  strict private
    FSeedingItems: TList<ISeedingItem>;
    function IsAllSamePriority: Boolean;
  strict protected
    function DoFetch(AAvailable: TBitField;
      APeersHave: TBitSum): TBitField; override; final;
  public
    constructor Create(ANextPicker: IPiecePicker; AFetchSize: Integer;
      ASeedingItems: TEnumerable<ISeedingItem>); reintroduce;
    destructor Destroy; override;
  end;

  TRequestFirstPicker = class(TPicker, IRequestFirstPicker)
  strict private
    FStack: TStack<Integer>;
    FCanPass: Boolean;
    function Push(AIndex: Integer): Boolean;
  strict protected
    function PassToNextPicker: Boolean; override; final;
    function DoFetch(AAvailable: TBitField;
      APeersHave: TBitSum): TBitField; override; final;
  public
    constructor Create(ANextPicker: IPiecePicker; AFetchSize: Integer); reintroduce;
    destructor Destroy; override;
  end;

implementation

{ TPicker }

constructor TPicker.Create(ANextPicker: IPiecePicker; AFetchSize: Integer);
begin
  inherited Create;

  Assert(AFetchSize > 0);

  FNextPicker := ANextPicker;
  FFetchSize  := AFetchSize;
end;

function TPicker.Fetch(APeerHave: TBitField; APeersHave: TBitSum;
  AWant: TBitField): TArray<Integer>;
var
  available, canFetch: TBitField;
begin
  available := APeerHave and AWant;
  canFetch  := DoFetch(available, APeersHave);

  if Assigned(FNextPicker) and PassToNextPicker then
    Result := FNextPicker.Fetch(APeerHave, APeersHave, canFetch)
  else
    Result := canFetch.CheckedIndexes;
end;

function TPicker.GetFetchSize: Integer;
begin
  Result := FFetchSize;
end;

function TPicker.GetNextPicker: IPiecePicker;
begin
  Result := FNextPicker;
end;

function TPicker.PassToNextPicker: Boolean;
begin
  Result := True;
end;

{ TLinearPicker }

function TLinearPicker.DoFetch(AAvailable: TBitField;
  APeersHave: TBitSum): TBitField;
var
  i, j: Integer;
begin
  Result := TBitField.Create(AAvailable.Len);

  { фетчим элементы подряд }
  i := 0;
  j := AAvailable.FirstTrue;

  while (i < Min(AAvailable.CheckedCount, FFetchSize)) and AAvailable[j + i]  do
  begin
    Result[j + i] := True;
    Inc(i);
  end;
end;

{ TRandomPicker }

function TRandomPicker.DoFetch(AAvailable: TBitField;
  APeersHave: TBitSum): TBitField;
var
  i, j, k: Integer;
begin
  Result := TBitField.Create(AAvailable.Len);

  { фетчим произвельные элементы в диапазоне }
  i := 0;
  j := AAvailable.FirstTrue;

  while i < Min(AAvailable.CheckedCount, FFetchSize) do
  begin
    k := RandomRange(j, AAvailable.Len);

    if AAvailable[k] then
    begin
      Result[k] := True;
      Inc(i);
    end;
  end;
end;

{ TRarestFirstPicker }

constructor TRarestFirstPicker.Create(ANextPicker: IPiecePicker;
  AFetchSize: Integer);
begin
  inherited Create(ANextPicker, AFetchSize);

  FSorter := TDelegatedComparer<TPair<Integer {frequency}, Integer {piece index}>>.Create(
    function(const Left, Right: TPair<Integer {frequency}, Integer {piece index}>): Integer
    begin
      Result := Left.Key - Right.Key;
    end);
end;

function TRarestFirstPicker.DoFetch(AAvailable: TBitField;
  APeersHave: TBitSum): TBitField;
var
  i: Integer;
  l: TList<TPair<Integer {frequency}, Integer {piece index}>>;
begin
  Result := TBitField.Create(AAvailable.Len);

  l := TList<TPair<Integer {frequency}, Integer {piece index}>>.Create;
  try
    for i := 0 to APeersHave.Len - 1 do
      if (APeersHave[i] > 0) and AAvailable[i] then
        if l.Count < FFetchSize then
        begin
          l.Add(TPair<Integer, Integer>.Create(APeersHave[i], i));

          l.Sort(FSorter);
        end else
        if l.First.Key > APeersHave[i] then
        begin
          l.Remove(l.Last);
          l.Add(TPair<Integer, Integer>.Create(APeersHave[i], i));

          l.Sort(FSorter);
        end;

    if l.Count > 0 then
      for i := 0 to l.Count - 1 do
        Result[l[i].Value] := True
    else
      Result := AAvailable;
  finally
    l.Free;
  end;
end;

{ TPriorityPicker }

constructor TPriorityPicker.Create(ANextPicker: IPiecePicker;
  AFetchSize: Integer; ASeedingItems: TEnumerable<ISeedingItem>);
var
  it: ISeedingItem;
begin
  inherited Create(ANextPicker, AFetchSize);

  FSeedingItems := TList<ISeedingItem>.Create(
    TDelegatedComparer<ISeedingItem>.Create(
      function(const Left, Right: ISeedingItem): Integer
      begin
        Result := Ord(Left.Priority) - Ord(Right.Priority);
      end
    )
  );

  for it in ASeedingItems do
    FSeedingItems.Add(it);

  FSeedingItems.Sort;
end;

destructor TPriorityPicker.Destroy;
begin
  FSeedingItems.Free;
  inherited;
end;

function TPriorityPicker.DoFetch(AAvailable: TBitField;
  APeersHave: TBitSum): TBitField;
var
  i, j: Integer;
begin
  Assert(FSeedingItems.Count > 0);

  if FSeedingItems.Count = 1 then
  with FSeedingItems.First do
  begin
    if Priority = fpSkip then
      Result := TBitField.Create(AAvailable.Len) { пустая маска }
    else
      Result := AAvailable;
  end else
  if (AAvailable.CheckedCount = 0) or IsAllSamePriority then
    Result := AAvailable
  else
  begin
    FSeedingItems.Sort;

    Result := TBitfield.Create(AAvailable.Len);

    if FSeedingItems.Last.Priority <> fpSkip then
    begin
      { самый высший приоритет у последнего элемента }
      for i := FSeedingItems.Count - 1 downto 0 do
      with FSeedingItems[i] do
      begin
        for j := FirstPiece to LastPiece do
          Result[j] := AAvailable[j];

        if (Priority <> FSeedingItems.Last.Priority) and (Result.CheckedCount > FFetchSize) then
          Break;
      end;
    end;
  end;
end;

function TPriorityPicker.IsAllSamePriority: Boolean;
var
  it: ISeedingItem;
begin
  Assert(FSeedingItems.Count > 0);

  Result := True;

  for it in FSeedingItems do
    Result := Result and (it.Priority = FSeedingItems[0].Priority);
end;

{ TRequestFirstPicker }

constructor TRequestFirstPicker.Create(ANextPicker: IPiecePicker;
  AFetchSize: Integer);
begin
  inherited Create(ANextPicker, AFetchSize);

  FStack    := TStack<Integer>.Create;
  FCanPass  := True;
end;

destructor TRequestFirstPicker.Destroy;
begin
  FStack.Free;
  inherited;
end;

function TRequestFirstPicker.DoFetch(AAvailable: TBitField;
  APeersHave: TBitSum): TBitField;
var
  i: Integer;
begin
  { очередь пуста -- передаем на сл. пикер как есть }
  if FStack.Count = 0 then
  begin
    Result    := AAvailable;
    FCanPass  := True;
  end else
  begin
    Result := TBitField.Create(AAvailable.Len);

    { пытаемся высвободить очередь на текущий пир }
    i := 0;
    with FStack do
    while (i < FFetchSize) and (Count > 0) and AAvailable[Peek] do
    begin
      {$IFDEF DEBUG}
      DebugOutput('Request First ' + Peek.ToString);
      {$ENDIF}
      Result[Pop] := True;

      Inc(i);
    end;

    { если ничего не удалось высвободить, то возвращаем «Available» маску }
    if Result.CheckedCount = 0 then
    begin
      Result    := AAvailable;
      FCanPass  := True;
    end else
      FCanPass  := False;
  end;
end;

function TRequestFirstPicker.PassToNextPicker: Boolean;
begin
  Result := FCanPass;
end;

function TRequestFirstPicker.Push(AIndex: Integer): Boolean;
var
  i: Integer;
begin
  { будет тормозить при большом количестве данных }
  for i in FStack do
    if i = AIndex then
      Exit(False);

  FStack.Push(AIndex);
  Result := True;
end;

end.
