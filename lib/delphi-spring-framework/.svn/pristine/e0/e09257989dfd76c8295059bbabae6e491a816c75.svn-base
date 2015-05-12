unit uRegistrations;

interface

procedure RegisterComponents;

implementation

uses
  Spring.Container,
  Spring.Container.DecoratorExtension,
  uOrderInterfaces,
  uOrderEntry,
  uOrderEntryDecorator,
  uOrderProcessor,
  uOrderValidator;

procedure RegisterComponents;
begin
  GlobalContainer.AddExtension<TDecoratorContainerExtension>;

  GlobalContainer.RegisterType<TOrderEntryTransactionDecorator>;
  GlobalContainer.RegisterType<TOrderEntryLoggingDecorator>;
  GlobalContainer.RegisterType<TOrderEntry>;
  GlobalContainer.RegisterType<TOrderValidatorLoggingDecorator>;
  GlobalContainer.RegisterType<TOrderValidator>;
  GlobalContainer.RegisterType<TOrderProcessor>;

  GlobalContainer.Build;
end;

end.
