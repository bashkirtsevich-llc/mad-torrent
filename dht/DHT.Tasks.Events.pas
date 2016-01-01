unit DHT.Tasks.Events;

interface

uses
  System.Classes,
  DHT,
  IdGlobal;

type
  TCompleteEventArgs = class(TInterfacedObject, ICompleteEventArgs)
  end;

  TSendQueryEventArgs = class(TCompleteEventArgs, ISendQueryEventArgs)
  private
    FResponse: IResponseMessage;
    FQuery: IQueryMessage;
    FHost: string;
    FPort: TIdPort;
  private
    function GetHost: string; inline;
    function GetPort: TIdPort; inline;
    function GetTimedOut: Boolean; inline;
    function GetQuery: IQueryMessage; inline;
    function GetResponse: IResponseMessage; inline;
  public
    constructor Create(const AHost: string; APort: TIdPort; AQuery: IQueryMessage;
      AResponse: IResponseMessage); reintroduce;
  end;

implementation

{ TSendQueryEventArgs }

constructor TSendQueryEventArgs.Create(const AHost: string; APort: TIdPort;
  AQuery: IQueryMessage; AResponse: IResponseMessage);
begin
  inherited Create;

  FHost     := AHost;
  FPort     := APort;
  FQuery    := AQuery;
  FResponse := AResponse;
end;

function TSendQueryEventArgs.GetHost: string;
begin
  Result := FHost;
end;

function TSendQueryEventArgs.GetPort: TIdPort;
begin
  Result := FPort;
end;

function TSendQueryEventArgs.GetQuery: IQueryMessage;
begin
  Result := FQuery;
end;

function TSendQueryEventArgs.GetResponse: IResponseMessage;
begin
  Result := FResponse;
end;

function TSendQueryEventArgs.GetTimedOut: Boolean;
begin
  Result := not Assigned(FResponse);
end;

end.
