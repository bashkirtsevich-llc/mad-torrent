unit uOrderEntry;

interface

uses
  uOrder,
  uOrderInterfaces;

type
  TOrderEntry = class(TInterfacedObject, IOrderEntry)
  public
    function EnterOrderIntoDatabase(aOrder: TOrder): Boolean;
  end;

implementation

uses
  Spring.Container;

{ TOrderEntry }

function TOrderEntry.EnterOrderIntoDatabase(aOrder: TOrder): Boolean;
begin
  Result := Assigned(aOrder);
  WriteLn('Entering order into the database....');
end;

end.
