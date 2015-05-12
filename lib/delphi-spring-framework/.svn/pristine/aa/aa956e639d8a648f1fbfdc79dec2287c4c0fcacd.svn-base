unit uDoOrderProcessing;

interface

procedure DoOrderProcessing;

implementation

uses
   uOrder,
   uOrderProcessor;

procedure DoOrderProcessing;
var
  Order: TOrder;
  OrderProcessor: TOrderProcessor;
begin
  Order := TOrder.Create;
  try
    OrderProcessor := TOrderProcessor.Create;
    try
      if OrderProcessor.ProcessOrder(Order) then
      begin
        {$IFDEF CONSOLEAPP}
        Writeln('Order successfully processed....');
        {$ENDIF}
      end;
    finally
      OrderProcessor.Free;
    end;
  finally
    Order.Free;
  end;
end;

end.
