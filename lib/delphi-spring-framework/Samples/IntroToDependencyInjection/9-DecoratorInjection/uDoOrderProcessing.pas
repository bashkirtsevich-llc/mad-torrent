unit uDoOrderProcessing;

interface

procedure DoOrderProcessing;

implementation

uses
  Spring.Services,
  uOrder,
  uOrderInterfaces,
  uRegistrations;

procedure DoOrderProcessing;
var
  Order: TOrder;
  OrderProcessor: IOrderProcessor;
begin
  RegisterComponents;
  Order := TOrder.Create;
  try
    OrderProcessor := ServiceLocator.GetService<IOrderProcessor>;
    if OrderProcessor.ProcessOrder(Order) then
    begin
      Writeln('Order successfully processed....');
    end;
  finally
    Order.Free;
  end;
end;

end.
