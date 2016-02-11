unit Common.InterfacedObjHolder;

interface

uses
  System.Classes;

type
  IObjHolder<T: class> = interface
  ['{6B4689E5-83A0-4368-8412-696675378477}']
    function GetData: T;
    property Data: T read GetData;
  end;

  TObjHolder<T: class> = class(TInterfacedObject, IObjHolder<T>)
  private
    FData: T;
    function GetData: T; inline;
  public
    constructor Create(const AData: T);
    destructor Destroy; override;
  end;

implementation

{ TObjHolder<T> }

constructor TObjHolder<T>.Create(const AData: T);
begin
  inherited Create;

  FData := AData;
end;

destructor TObjHolder<T>.Destroy;
begin
  FData.Free;
  inherited;
end;

function TObjHolder<T>.GetData: T;
begin
  Result := FData;
end;

end.
