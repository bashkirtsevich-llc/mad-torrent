unit uOrderValidatorMock;

interface

uses
  uOrder,
  uOrderValidator;

type
  TOrderValidatorMock = class(TInterfacedObject, IOrderValidator)
  public
    function ValidateOrder(aOrder: TOrder): Boolean;
  end;

implementation

{ TOrderValidatorMock }

function TOrderValidatorMock.ValidateOrder(aOrder: TOrder): Boolean;
begin
  Result := True;
  {$IFDEF CONSOLEAPP}
  Writeln('TOrderValidatorMock.ValidateOrder called');
  {$ENDIF}
end;

end.
