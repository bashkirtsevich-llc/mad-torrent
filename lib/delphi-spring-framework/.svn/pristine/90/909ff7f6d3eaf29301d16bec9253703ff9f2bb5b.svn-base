unit uOrderProcessor;

interface

uses
  uOrder,
  uOrderEntry,
  uOrderValidator;

type
  TOrderProcessor = class
  private
    FOrderValidator: TOrderValidator;
    FOrderEntry: TOrderEntry;
  public
    constructor Create;
    destructor Destroy; override;
    function ProcessOrder(aOrder: TOrder): Boolean;
  end;

implementation

{ TOrderProcessor }

constructor TOrderProcessor.Create;
begin
  FOrderValidator := TOrderValidator.Create;
  FOrderEntry := TOrderEntry.Create;
end;

destructor TOrderProcessor.Destroy;
begin
  FOrderValidator.Free;
  FOrderEntry.Free;
  inherited;
end;

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

end.
