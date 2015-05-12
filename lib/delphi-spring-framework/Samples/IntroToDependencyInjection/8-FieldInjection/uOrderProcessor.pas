unit uOrderProcessor;

interface

uses
  uOrder,
  uOrderInterfaces,
  Spring.Services;

type
  TOrderProcessor = class(TInterfacedObject, IOrderProcessor)
  private
    [Inject]
    FOrderValidator: IOrderValidator;
    [Inject]
    FOrderEntry: IOrderEntry;
  public
    function ProcessOrder(aOrder: TOrder): Boolean;
  end;

implementation

uses
  Spring.Container;

{ TOrderProcessor }

function TOrderProcessor.ProcessOrder(aOrder: TOrder): Boolean;
var
  OrderIsValid: Boolean;
begin
  Result := False;
  OrderIsValid := FOrderValidator.ValidateOrder(aOrder);
  if OrderIsValid then
  begin
    Result := FOrderEntry.EnterOrderIntoDatabase(aOrder);
  end;

  {$IFDEF CONSOLEAPP}
  Writeln('Order has been processed....');
  {$ENDIF}
end;

initialization
  GlobalContainer.RegisterType<TOrderProcessor>;

end.
