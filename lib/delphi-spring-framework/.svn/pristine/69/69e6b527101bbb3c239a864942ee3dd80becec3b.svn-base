{***************************************************************************}
{                                                                           }
{           Spring Framework for Delphi                                     }
{                                                                           }
{           Copyright (c) 2009-2013 Spring4D Team                           }
{                                                                           }
{           http://www.spring4d.org                                         }
{                                                                           }
{***************************************************************************}
{                                                                           }
{  Licensed under the Apache License, Version 2.0 (the "License");          }
{  you may not use this file except in compliance with the License.         }
{  You may obtain a copy of the License at                                  }
{                                                                           }
{      http://www.apache.org/licenses/LICENSE-2.0                           }
{                                                                           }
{  Unless required by applicable law or agreed to in writing, software      }
{  distributed under the License is distributed on an "AS IS" BASIS,        }
{  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. }
{  See the License for the specific language governing permissions and      }
{  limitations under the License.                                           }
{                                                                           }
{***************************************************************************}

{TODO -oOwner -cGeneral : Thread Safety}

unit Spring.Container;

{$I Spring.inc}

interface

uses
  Rtti,
  Spring,
  Spring.Collections,
  Spring.Container.Core,
  Spring.Container.Registration,
  Spring.Services;

type
  ///	<summary>
  ///	  Represents a Dependency Injection Container.
  ///	</summary>
  TContainer = class(TInterfaceBase, IContainerContext, IInterface)
  private
    fRegistry: IComponentRegistry;
    fBuilder: IComponentBuilder;
    fServiceResolver: IServiceResolver;
    fDependencyResolver: IDependencyResolver;
    fInjectionFactory: IInjectionFactory;
    fRegistrationManager: TRegistrationManager;
    fExtensions: IList<IContainerExtension>;
    class var GlobalInstance: TContainer;
    function GetContext: IContainerContext;
  protected
    class constructor Create;
    class destructor Destroy;
  {$REGION 'Implements IContainerContext'}
    function GetComponentBuilder: IComponentBuilder;
    function GetComponentRegistry: IComponentRegistry;
    function GetDependencyResolver: IDependencyResolver;
    function GetInjectionFactory: IInjectionFactory;
    function GetServiceResolver: IServiceResolver;
  {$ENDREGION}
    procedure CheckPoolingSupported(componentType: TRttiType);
    function CreateLifetimeManager(model: TComponentModel): ILifetimeManager;
    procedure InitializeInspectors; virtual;
    property ComponentBuilder: IComponentBuilder read GetComponentBuilder;
    property ComponentRegistry: IComponentRegistry read GetComponentRegistry;
    property DependencyResolver: IDependencyResolver read GetDependencyResolver;
    property InjectionFactory: IInjectionFactory read GetInjectionFactory;
    property ServiceResolver: IServiceResolver read GetServiceResolver;
  public
    constructor Create;
    destructor Destroy; override;

    procedure AddExtension(const extension: IContainerExtension); overload;
    procedure AddExtension<T: IContainerExtension, constructor>; overload;

    function RegisterInstance<TServiceType>(const instance: TServiceType): TRegistration<TServiceType>; overload;

    function RegisterType<TComponentType>: TRegistration<TComponentType>; overload;
    function RegisterType(componentType: PTypeInfo): TRegistration; overload;
    function RegisterType<TServiceType, TComponentType>(
      const name: string = ''): TRegistration<TComponentType>; overload;

    function RegisterComponent<TComponentType>: TRegistration<TComponentType>; overload; deprecated 'Use RegisterType';
    function RegisterComponent(componentType: PTypeInfo): TRegistration; overload; deprecated 'Use RegisterType';

    procedure Build;

    function Resolve<T>: T; overload;
    function Resolve<T>(resolverOverride: IResolverOverride): T; overload;
    function Resolve<T>(const name: string): T; overload;
    function Resolve<T>(const name: string; resolverOverride: IResolverOverride): T; overload;
    function Resolve(typeInfo: PTypeInfo): TValue; overload;
    function Resolve(typeInfo: PTypeInfo; resolverOverride: IResolverOverride): TValue; overload;
    function Resolve(const name: string): TValue; overload;
    function Resolve(const name: string; resolverOverride: IResolverOverride): TValue; overload;

    function ResolveAll<TServiceType>: TArray<TServiceType>; overload;
    function ResolveAll(serviceType: PTypeInfo): TArray<TValue>; overload;

    function HasService(serviceType: PTypeInfo): Boolean; overload;
    function HasService(const name: string): Boolean; overload;

    { Experimental Release Methods }
    procedure Release(instance: TObject); overload;
    procedure Release(instance: IInterface); overload;

    property Context: IContainerContext read GetContext;
  end;

  ///	<summary>
  ///	  Adapter to get access to a <see cref="TContainer" /> instance over the
  ///	  <see cref="Spring.Services|IServiceLocator" /> interface.
  ///	</summary>
  TServiceLocatorAdapter = class(TInterfacedObject, IServiceLocator)
  private
    fContainer: TContainer;
    class var GlobalInstance: IServiceLocator;
    class constructor Create;
  public
    constructor Create(container: TContainer);

    function GetService(serviceType: PTypeInfo): TValue; overload;
    function GetService(serviceType: PTypeInfo; const name: string): TValue; overload;
    function GetService(serviceType: PTypeInfo; const args: array of TValue): TValue; overload;
    function GetService(serviceType: PTypeInfo; const name: string; const args: array of TValue): TValue; overload;

    function GetAllServices(serviceType: PTypeInfo): TArray<TValue>; overload;

    function HasService(serviceType: PTypeInfo): Boolean; overload;
    function HasService(serviceType: PTypeInfo; const name: string): Boolean; overload;
  end;


{$REGION 'Exceptions'}

  EContainerException = Spring.Container.Core.EContainerException;
  ERegistrationException = Spring.Container.Core.ERegistrationException;
  EResolveException = Spring.Container.Core.EResolveException;
  EUnsatisfiedDependencyException = Spring.Container.Core.EUnsatisfiedDependencyException;
  ECircularDependencyException = Spring.Container.Core.ECircularDependencyException;
  EActivatorException = Spring.Container.Core.EActivatorException;

{$ENDREGION}


function GlobalContainer: TContainer; inline;

implementation

uses
  SysUtils,
  TypInfo,
  Spring.Container.Builder,
  Spring.Container.Injection,
  Spring.Container.LifetimeManager,
  Spring.Container.Resolvers,
  Spring.Container.ResourceStrings,
  Spring.Helpers;

function GlobalContainer: TContainer;
begin
  Result := TContainer.GlobalInstance;
end;


{$REGION 'TContainer'}

class constructor TContainer.Create;
begin
  GlobalInstance := TContainer.Create;
end;

class destructor TContainer.Destroy;
begin
  GlobalInstance.Free;
end;

constructor TContainer.Create;
begin
  inherited Create;
  fRegistry := TComponentRegistry.Create(Self);
  fBuilder := TComponentBuilder.Create(Self, fRegistry);
  fServiceResolver := TServiceResolver.Create(Self, fRegistry);
  fDependencyResolver := TDependencyResolver.Create(Self, fRegistry);
  fInjectionFactory := TInjectionFactory.Create;
  fRegistrationManager := TRegistrationManager.Create(fRegistry);
  fExtensions := TCollections.CreateList<IContainerExtension>;
  InitializeInspectors;
end;

destructor TContainer.Destroy;
begin
  fRegistrationManager.Free;
  fBuilder.ClearInspectors;
  fRegistry.UnregisterAll;
  inherited Destroy;
end;

procedure TContainer.AddExtension(const extension: IContainerExtension);
begin
  fExtensions.Add(extension);
  extension.InitializeExtension(Self);
  extension.Initialize;
end;

procedure TContainer.AddExtension<T>;
var
  extension: IContainerExtension;
begin
  extension := T.Create;
  AddExtension(extension);
end;

procedure TContainer.Build;
begin
  fBuilder.BuildAll;
end;

procedure TContainer.CheckPoolingSupported(componentType: TRttiType);
begin
  if not (componentType.IsInstance
    and (componentType.AsInstance.MetaclassType.InheritsFrom(TInterfacedObject)
    or Supports(componentType.AsInstance.MetaclassType, IRefCounted))) then
  begin
    if componentType.IsPublicType then
      raise ERegistrationException.CreateResFmt(@SPoolingNotSupported, [
        componentType.QualifiedName])
    else
      raise ERegistrationException.CreateResFmt(@SPoolingNotSupported, [
        componentType.Name]);
  end;
end;

procedure TContainer.InitializeInspectors;
var
  inspectors: TArray<IBuilderInspector>;
  inspector: IBuilderInspector;
begin
  inspectors := TArray<IBuilderInspector>.Create(
    TInterfaceInspector.Create,
    TComponentActivatorInspector.Create,
    TLifetimeInspector.Create,
    TInjectionTargetInspector.Create,
    TConstructorInspector.Create,
    TPropertyInspector.Create,
    TMethodInspector.Create,
    TFieldInspector.Create
  );
  for inspector in inspectors do
  begin
    fBuilder.AddInspector(inspector);
  end;
end;

function TContainer.CreateLifetimeManager(
  model: TComponentModel): ILifetimeManager;
begin
  Guard.CheckNotNull(model, 'model');
  case model.LifetimeType of
    TLifetimeType.Singleton:
    begin
      Result := TSingletonLifetimeManager.Create(model);
    end;
    TLifetimeType.Transient:
    begin
      Result := TTransientLifetimeManager.Create(model);
    end;
    TLifetimeType.SingletonPerThread:
    begin
      Result := TSingletonPerThreadLifetimeManager.Create(model);
    end;
    TLifetimeType.Pooled:
    begin
      CheckPoolingSupported(model.ComponentType);
      Result := TPooledLifetimeManager.Create(model);
    end;
  else
    raise ERegistrationException.CreateRes(@SUnexpectedLifetimeType);
  end;
end;

function TContainer.GetComponentBuilder: IComponentBuilder;
begin
  Result := fBuilder;
end;

function TContainer.GetComponentRegistry: IComponentRegistry;
begin
  Result := fRegistry;
end;

function TContainer.GetContext: IContainerContext;
begin
  Result := Self;
end;

function TContainer.GetDependencyResolver: IDependencyResolver;
begin
  Result := fDependencyResolver;
end;

function TContainer.GetInjectionFactory: IInjectionFactory;
begin
  Result := fInjectionFactory;
end;

function TContainer.GetServiceResolver: IServiceResolver;
begin
  Result := fServiceResolver;
end;

function TContainer.RegisterComponent(componentType: PTypeInfo): TRegistration;
begin
  Result := fRegistrationManager.RegisterComponent(componentType);
end;

function TContainer.RegisterComponent<TComponentType>: TRegistration<TComponentType>;
begin
  Result := fRegistrationManager.RegisterComponent<TComponentType>;
end;

function TContainer.RegisterInstance<TServiceType>(
  const instance: TServiceType): TRegistration<TServiceType>;
begin
  Result := fRegistrationManager.RegisterComponent<TServiceType>;
  Result := Result.DelegateTo(
    function: TServiceType
    begin
      Result := instance;
    end);
end;

function TContainer.RegisterType<TComponentType>: TRegistration<TComponentType>;
begin
  Result := fRegistrationManager.RegisterComponent<TComponentType>;
end;

function TContainer.RegisterType<TServiceType, TComponentType>(
  const name: string): TRegistration<TComponentType>;
begin
  Result := fRegistrationManager.RegisterComponent<TComponentType>;
  Result := Result.Implements<TServiceType>(name);
end;

function TContainer.RegisterType(componentType: PTypeInfo): TRegistration;
begin
  Result := fRegistrationManager.RegisterComponent(componentType);
end;

function TContainer.HasService(serviceType: PTypeInfo): Boolean;
begin
  Result := fRegistry.HasService(serviceType);
end;

function TContainer.HasService(const name: string): Boolean;
begin
  Result := fRegistry.HasService(name);
end;

function TContainer.Resolve<T>: T;
var
  value: TValue;
begin
  value := Resolve(TypeInfo(T));
  Result := value.AsType<T>;
end;

function TContainer.Resolve<T>(resolverOverride: IResolverOverride): T;
var
  value: TValue;
begin
  value := Resolve(TypeInfo(T), resolverOverride);
  Result := value.AsType<T>;
end;

function TContainer.Resolve<T>(const name: string): T;
var
  value: TValue;
begin
  value := Resolve(name);
  Result := value.AsType<T>;
end;

function TContainer.Resolve<T>(const name: string;
  resolverOverride: IResolverOverride): T;
var
  value: TValue;
begin
  value := Resolve(name, resolverOverride);
  Result := value.AsType<T>;
end;

function TContainer.Resolve(typeInfo: PTypeInfo): TValue;
var
  model: TComponentModel;
begin
  // TODO: How to support bootstrap
  if not fRegistry.HasService(typeInfo) and (typeInfo.Kind = tkClass) then
  begin
    model := fRegistry.FindOne(typeInfo);
    if not Assigned(model) then
      model := fRegistry.RegisterComponent(typeInfo);
    fRegistry.RegisterService(model, typeInfo);
    fBuilder.Build(model);
    Result := fServiceResolver.Resolve(model.GetServiceName(typeInfo));
  end
  else
  begin
    Result := fServiceResolver.Resolve(typeInfo);
  end;
end;

function TContainer.Resolve(typeInfo: PTypeInfo;
  resolverOverride: IResolverOverride): TValue;
begin
  Result := fServiceResolver.Resolve(typeInfo, resolverOverride);
end;

function TContainer.Resolve(const name: string): TValue;
begin
  Result := fServiceResolver.Resolve(name);
end;

function TContainer.Resolve(const name: string;
  resolverOverride: IResolverOverride): TValue;
begin
  Result := fServiceResolver.Resolve(name, resolverOverride);
end;

function TContainer.ResolveAll<TServiceType>: TArray<TServiceType>;
var
  serviceType: PTypeInfo;
  models: IEnumerable<TComponentModel>;
  model: TComponentModel;
  value: TValue;
  i: Integer;
begin
  serviceType := TypeInfo(TServiceType);
  models := fRegistry.FindAll(serviceType);
  SetLength(Result, models.Count);
  i := 0;
  for model in models do
  begin
    value := Resolve(model.GetServiceName(serviceType));
    Result[i] := value.AsType<TServiceType>;
    Inc(i);
  end;
end;

function TContainer.ResolveAll(serviceType: PTypeInfo): TArray<TValue>;
begin
  Result := fServiceResolver.ResolveAll(serviceType);
end;

procedure TContainer.Release(instance: TObject);
var
  model: TComponentModel;
begin
  Guard.CheckNotNull(instance, 'instance');

  model := fRegistry.FindOne(instance.ClassInfo);
  if model = nil then
  begin
    raise EContainerException.CreateRes(@SComponentNotFound);
  end;
  model.LifetimeManager.ReleaseInstance(instance);
end;

procedure TContainer.Release(instance: IInterface);
begin
  Guard.CheckNotNull(instance, 'instance');
  { TODO: -oOwner -cGeneral : Release instance of IInterface }
end;

{$ENDREGION}


{$REGION 'TServiceLocatorAdapter'}

class constructor TServiceLocatorAdapter.Create;
begin
  GlobalInstance := TServiceLocatorAdapter.Create(GlobalContainer);
  ServiceLocator.Initialize(
    function: IServiceLocator
    begin
      Result := GlobalInstance;
    end);
end;

constructor TServiceLocatorAdapter.Create(container: TContainer);
begin
  inherited Create;
  fContainer := container;
end;

function TServiceLocatorAdapter.GetService(serviceType: PTypeInfo): TValue;
begin
  Result := fContainer.Resolve(serviceType);
end;

function TServiceLocatorAdapter.GetService(serviceType: PTypeInfo; const name: string): TValue;
begin
  Result := fContainer.Resolve({serviceType, }name);
end;

function TServiceLocatorAdapter.GetService(serviceType: PTypeInfo;
  const args: array of TValue): TValue;
begin
  Result := fContainer.Resolve(serviceType,
    TOrderedParametersOverride.Create(args));
end;

function TServiceLocatorAdapter.GetService(serviceType: PTypeInfo;
  const name: string; const args: array of TValue): TValue;
begin
  Result := fContainer.Resolve({serviceType, }name,
    TOrderedParametersOverride.Create(args));
end;

function TServiceLocatorAdapter.GetAllServices(serviceType: PTypeInfo): TArray<TValue>;
begin
  Result := fContainer.ResolveAll(serviceType);
end;

function TServiceLocatorAdapter.HasService(serviceType: PTypeInfo): Boolean;
begin
  Result := fContainer.HasService(serviceType);
end;

function TServiceLocatorAdapter.HasService(serviceType: PTypeInfo; const name: string): Boolean;
begin
  Result := fContainer.HasService({serviceType, }name);
end;

{$ENDREGION}


end.
