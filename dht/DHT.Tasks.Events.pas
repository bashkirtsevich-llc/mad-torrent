unit DHT.Tasks.Events;

interface

uses
  Socket.Synsock, Socket.SynsockHelper,
  DHT.Engine;

type
  TTaskCompleteEventArgs = class(TInterfacedObject, ITaskCompleteEventArgs)
  private
    FTask: ITask;
  public
    function GetTask: ITask; inline;
    procedure SetTask(Value: ITask); inline;
    constructor Create(ATask: ITask);
  end;

  TSendQueryEventArgs = class(TTaskCompleteEventArgs, ISendQueryEventArgs)
  private
    FResponse: IResponseMessage;
    FQuery: IQueryMessage;
    FEndPoint: TVarSin;
  private
    function GetTimedOut: Boolean; inline;
    function GetEndPoint: TVarSin; inline;
    function GetQuery: IQueryMessage; inline;
    function GetResponse: IResponseMessage; inline;
  public
    constructor Create(AEndPoint: TVarSin; AQuery: IQueryMessage;
      AResponse: IResponseMessage); overload;
  end;

implementation

{ TaskCompleteEventArgs }

constructor TTaskCompleteEventArgs.Create(ATask: ITask);
begin
  inherited Create;
  FTask := ATask;
end;

function TTaskCompleteEventArgs.GetTask: ITask;
begin
  Result := FTask;
end;

procedure TTaskCompleteEventArgs.SetTask(Value: ITask);
begin
  FTask := Value;
end;

{ TSendQueryEventArgs }

constructor TSendQueryEventArgs.Create(AEndPoint: TVarSin; AQuery: IQueryMessage;
  AResponse: IResponseMessage);
begin
  inherited Create(nil);

  FEndPoint := AEndPoint;
  FQuery    := AQuery;
  FResponse := AResponse;
end;

function TSendQueryEventArgs.GetEndPoint: TVarSin;
begin
  Result := FEndPoint;
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
