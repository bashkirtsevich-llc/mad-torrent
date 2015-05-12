unit uOrderValidator;

interface

uses
  uOrder;

type
  IOrderValidator = interface
    function ValidateOrder(aOrder: TOrder): Boolean;
  end;

  TOrderValidator = class(TInterfacedObject, IOrderValidator)
  public
    function ValidateOrder(aOrder: TOrder): Boolean;
  end;

implementation

{ TOrderValidator }

function TOrderValidator.ValidateOrder(aOrder: TOrder): Boolean;
begin
  Result := Assigned(aOrder);
  {$IFDEF CONSOLEAPP}
  Writeln('Validating Order....');
  {$ENDIF}
end;

end.
