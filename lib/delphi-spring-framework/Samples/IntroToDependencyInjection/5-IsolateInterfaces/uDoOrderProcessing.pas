unit uDoOrderProcessing;

interface

procedure DoOrderProcessing;

implementation

uses
  uOrder,
  uOrderInterfaces,
  uOrderProcessor,
  uOrderValidator,
  uOrderEntry;

procedure DoOrderProcessing;
var
  Order: TOrder;
  OrderProcessor: IOrderProcessor;
begin
  Order := TOrder.Create;
  OrderProcessor := TOrderProcessor.Create(TOrderValidator.Create, TOrderEntry.Create);
  try
    if OrderProcessor.ProcessOrder(Order) then
    begin
      {$IFDEF CONSOLEAPP}
      WriteLn('Order successfully processed....');
      {$ENDIF}
    end;
  finally
    Order.Free;
  end;
end;

end.
