unit uOrderEntryMock;


interface

uses
  uOrder,
  uOrderEntry;

type
  TOrderEntryMock = class(TInterfacedObject, IOrderEntry)
  public
    function EnterOrderIntoDatabase(aOrder: TOrder): Boolean;
  end;

implementation

{ TOrderEntryMock }

function TOrderEntryMock.EnterOrderIntoDatabase(aOrder: TOrder): Boolean;
begin
  Result := True;
  {$IFDEF CONSOLEAPP}
  Writeln('TOrderEntryMock.EnterOrderIntoDatabase called');
  {$ENDIF}
end;

end.
