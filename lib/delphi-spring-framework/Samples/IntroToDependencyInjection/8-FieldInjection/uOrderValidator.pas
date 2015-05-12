unit uOrderValidator;

interface

uses
  uOrder,
  uOrderInterfaces;

type
  TOrderValidator = class(TInterfacedObject, IOrderValidator)
  public
    function ValidateOrder(aOrder: TOrder): Boolean;
  end;

implementation

uses
  Spring.Container;

{ TOrderValidator }

function TOrderValidator.ValidateOrder(aOrder: TOrder): Boolean;
begin
  Result := Assigned(aOrder);
  {$IFDEF CONSOLEAPP}
  Writeln('Validating Order....');
  {$ENDIF}
end;

initialization
  GlobalContainer.RegisterType<TOrderValidator>;

end.
