unit Common.BusyObj;

interface

type
  IBusy = interface
  ['{1DC5383D-E022-4831-84AE-7C38B67D55EB}']
    function GetBusy: Boolean;
    procedure Sync;

    property Busy: Boolean read GetBusy;
  end;

  TBusy = class(TInterfacedObject, IBusy)
  private
    FBusy: Cardinal;
    function GetBusy: Boolean; inline;
    procedure Sync; inline;
  protected
    { как-то бы дать им более адекватные имена }
    procedure Enter; inline;
    procedure Leave; inline;
  protected
    procedure DoSync; virtual; abstract;
  public
    constructor Create;
  end;

implementation

{ TBusy }

constructor TBusy.Create;
begin
  inherited Create;

  FBusy := 0;
end;

procedure TBusy.Enter;
begin
  AtomicIncrement(FBusy);
end;

function TBusy.GetBusy: Boolean;
begin
  Result := FBusy > 0;
end;

procedure TBusy.Leave;
begin
  AtomicDecrement(FBusy);
end;

procedure TBusy.Sync;
begin
  if GetBusy then
    Exit;

  Enter;
  try
    DoSync;
  finally
    Leave;
  end;
end;

end.
