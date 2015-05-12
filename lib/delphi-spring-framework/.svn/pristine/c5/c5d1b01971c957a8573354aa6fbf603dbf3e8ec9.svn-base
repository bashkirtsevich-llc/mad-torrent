unit uDoOrderProcessing;

interface

procedure DoOrderProcessing;

implementation

uses
  Spring.Container,
  Spring.Services,
  uOrder,
  uOrderInterfaces,
  uOrderProcessor;

procedure DoOrderProcessing;
var
  Order: TOrder;
  OrderProcessor: IOrderProcessor;
  OrderValidator: IOrderValidator;
  OrderEntry: IOrderEntry;
begin
  GlobalContainer.Build;
  Order := TOrder.Create;
  try
    OrderValidator := ServiceLocator.GetService<IOrderValidator>;
    OrderEntry := ServiceLocator.GetService<IOrderEntry>;
    OrderProcessor := TOrderProcessor.Create(OrderValidator, OrderEntry);
    if OrderProcessor.ProcessOrder(Order) then
    begin
      {$IFDEF CONSOLEAPP}
      Writeln('Order successfully processed....');
      {$ENDIF}
    end;
  finally
    Order.Free;
  end;
end;

end.
