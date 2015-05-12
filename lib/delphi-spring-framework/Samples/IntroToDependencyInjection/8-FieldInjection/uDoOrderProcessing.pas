unit uDoOrderProcessing;

interface

procedure DoOrderProcessing;

implementation

uses
  Spring.Container,
  Spring.Services,
  uOrder,
  uOrderInterfaces;

procedure DoOrderProcessing;
var
  Order: TOrder;
  OrderProcessor: IOrderProcessor;
begin
  GlobalContainer.Build;
  Order := TOrder.Create;
  try
    OrderProcessor := ServiceLocator.GetService<IOrderProcessor>;
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
