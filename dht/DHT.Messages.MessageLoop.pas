unit DHT.Messages.MessageLoop;

interface

uses
  System.SysUtils, System.DateUtils, System.TimeSpan,
  System.Generics.Collections, System.Generics.Defaults,
  Socket.Synsock, Socket.SynsockHelper,
  Basic.Bencoding, Basic.UniString,
  Common, Common.ThreadPool, Common.AccurateTimer,
  DHT.Engine, DHT.Listener,
  IdGlobal;

type
  TMessageLoop = class(TInterfacedObject, IMessageLoop)
  private
    type
      ISendDetails = interface
      ['{BB733FE2-683E-479C-85E2-E595E0B33711}']
        function GetDestination: TVarSin;
        {procedure SetDestination(const Value: TVarSin);}
        function GetMsg: IMessage;
        {procedure SetMsg(const Value: TMessage);}
        function GetSentAt: TDateTime;
        procedure SetSentAt(const Value: TDateTime);

        property Destination: TVarSin read GetDestination {write SetDestination};
        property Msg: IMessage read GetMsg {write SetMsg};
        property SentAt: TDateTime read GetSentAt write SetSentAt;
      end;

      TSendDetails = class(TInterfacedObject, ISendDetails)
      private
        FDestination: TVarSin;
        FMsg: IMessage;
        FSentAt: TDateTime;
      private
        function GetDestination: TVarSin;
        {procedure SetDestination(const Value: TVarSin);}
        function GetMsg: IMessage;
        {procedure SetMsg(const Value: TMessage);}
        function GetSentAt: TDateTime;
        procedure SetSentAt(const Value: TDateTime);
      public
        constructor Create(ADest: TVarSin; AMsg: IMessage);
      end;

      TTransactionID = class sealed
      private
        class var FCurrent: array [0..1] of Byte; // может 4 байта запользовать?
        class var FLock: TObject;

        class constructor ClassCreate;
        class destructor ClassDestroy;
      public
        class function NextID: IBencodedString;
      end;
  private
    FPool: TThreadPool;
    FOnQuerySent: TGenList<TFunc<ISendQueryEventArgs, {Handled:} Boolean>>;
    FOnQuerySentLock: TObject;
    FEngine: TDHTEngine;
    FListener: TDHTListener;
    FSendQueue: TQueue<ISendDetails>;
    FSendQueueLock: TObject;
    FReceiveQueue: TQueue<TPair<TVarSin, IMessage>>;
    FReceiveQueueLock: TObject;
    FWaitingResponse: TGenList<ISendDetails>;
    function CanSend: Boolean;

    function MessageLoop: Boolean;
    procedure SendMessage; overload;
    procedure SendMessage(AMsg: IMessage; ADest: TVarSin); overload;
    procedure ReceiveMessage;
    procedure TimeoutMessage;

    procedure RaiseMessageSent(AEndPoint: TVarSin; AQuery: IQueryMessage;
      AResponse: IResponseMessage);

    procedure EnqueueSend(AMessage: IMessage; AEndPoint: TVarSin); overload;
    procedure EnqueueSend(AMessage: IMessage; ANode: INode); overload;

    procedure ParseMessage(ABuffer: TUniString; AAddress: string);

    procedure Start;
    procedure Stop;

    function GetOnQuerySent: TGenList<TFunc<ISendQueryEventArgs, Boolean>>; inline;

    procedure LockQuerySent; inline;
    procedure UnlockQuerySent; inline;
  public
    constructor Create(AEngine: TDHTEngine; APool: TThreadPool; AListener: TDHTListener);
    destructor Destroy; override;
  end;

implementation

uses
  DHT.Messages, DHT.Messages.MessageFactory, DHT.Tasks.Events, DHT.Node;

{ TMessageLoop }

function TMessageLoop.CanSend: Boolean;
begin
  Result := (FSendQueue.Count > 0); //and (MilliSecondsBetween(Now, FLastSent) > {5}1);
end;

constructor TMessageLoop.Create(AEngine: TDHTEngine; APool: TThreadPool;
  AListener: TDHTListener);
begin
  inherited Create;

  FPool := APool;
  FOnQuerySent := TGenList<TFunc<ISendQueryEventArgs, Boolean>>.Create;
  FOnQuerySentLock := TObject.Create;

  FEngine := AEngine;
  FListener := AListener;

  FReceiveQueue := TQueue<TPair<TVarSin, IMessage>>.Create;
  FReceiveQueueLock := TObject.Create;
  FWaitingResponse := TGenList<ISendDetails>.Create;

  FListener.RegisterReceiveEvent(ParseMessage);

  FSendQueue := TQueue<ISendDetails>.Create;
  FSendQueueLock := TObject.Create;

  FPool.Exec(MessageLoop);
end;

destructor TMessageLoop.Destroy;
begin
  FOnQuerySent.Free;
  FOnQuerySentLock.Free;
  FSendQueue.Free;
  FSendQueueLock.Free;
  FReceiveQueue.Free;
  FReceiveQueueLock.Free;
  FWaitingResponse.Free;
  inherited;
end;

procedure TMessageLoop.EnqueueSend(AMessage: IMessage; AEndPoint: TVarSin);
begin
  if AMessage.TransactionId = nil then
  begin
    if Supports(AMessage, IResponseMessage) then
      raise EMessageLoop.Create('Message must have a transaction id');

    repeat
      AMessage.TransactionId := TTransactionId.NextId;
    until not(TMessageFactory.IsRegistered(AMessage.TransactionId));
  end;

  // We need to be able to cancel a query message if we time out waiting for a response
  if Supports(AMessage, IQueryMessage) then
    TMessageFactory.RegisterSend(AMessage as IQueryMessage);

  TMonitor.Enter(FSendQueueLock);
  try
    FSendQueue.Enqueue(TSendDetails.Create(AEndPoint, AMessage) as ISendDetails);
  finally
    TMonitor.Exit(FSendQueueLock);
  end;
end;

procedure TMessageLoop.EnqueueSend(AMessage: IMessage; ANode: INode);
begin
  EnqueueSend(AMessage, ANode.EndPoint);
end;

function TMessageLoop.GetOnQuerySent: TGenList<TFunc<ISendQueryEventArgs, Boolean>>;
begin
  Result := FOnQuerySent;
end;

procedure TMessageLoop.LockQuerySent;
begin
  TMonitor.Enter(FOnQuerySentLock);
end;

function TMessageLoop.MessageLoop: Boolean;
begin
  Result := not (FEngine.Disposed or AppTerminate);

  if Result then
  begin
    FEngine.Lock;
    try
      try
        SendMessage;
        ReceiveMessage;
        TimeoutMessage;

        DelayMicSec(1);
      except
  //      on E: Exception do
  //      Debug.WriteLine("Error in DHT main loop:");
  //      Debug.WriteLine(ex);
      end;
    finally
      FEngine.Unlock;
    end;
  end;
end;

procedure TMessageLoop.ParseMessage(ABuffer: TUniString; AAddress: string);
var
  msg: IMessage;
  it: TPair<TVarSin, IMessage>;
  dict: IBencodedDictionary;
begin
  try
    BencodeParse(ABuffer, False,
      function (ALen: Integer; AValue: IBencodedValue): Boolean
      begin
        Assert(Supports(AValue, IBencodedDictionary));
        Assert((AValue as IBencodedDictionary).Childs.Count > 0);

        dict := AValue as IBencodedDictionary;

        if TMessageFactory.TryDecodeMessage(dict, msg) then
        begin
          it.Key := StrToVarSin(AAddress);
          it.Value := msg;

          TMonitor.Enter(FReceiveQueueLock);
          try
            FReceiveQueue.Enqueue(it);
          finally
            TMonitor.Exit(FReceiveQueueLock);
          end;
        end;

        Result := False; { stop parse }
      end);
  except
    //on E: MessageException do
    //  Console.WriteLine("Message Exception: {0}", ex);
    //on E: Exception do
    //  Console.WriteLine("OMGZERS! {0}", ex);
  end;
end;

procedure TMessageLoop.RaiseMessageSent(AEndPoint: TVarSin;
  AQuery: IQueryMessage; AResponse: IResponseMessage);
var
  i: Integer;
begin
  LockQuerySent;
  try
    i := 0;

    while i < FOnQuerySent.Count do
      if FOnQuerySent[i](TSendQueryEventArgs.Create(AEndpoint, AQuery, AResponse)) then
        FOnQuerySent.Delete(i)
      else
        Inc(i);
  finally
    UnlockQuerySent;
  end;
end;

procedure TMessageLoop.ReceiveMessage;
var
  receive: TPair<TVarSin, IMessage>;
  m: IMessage;
  source: TVarSin;
  i: Integer;
  node: INode;
  response: IResponseMessage;
begin
  TMonitor.Enter(FReceiveQueueLock);
  try
    if FReceiveQueue.Count = 0 then
      Exit;

    receive := FReceiveQueue.Dequeue;
  finally
    TMonitor.Exit(FReceiveQueueLock);
  end;

  m := receive.Value;
  source := receive.Key;

  // странно, что есть вероятность пустых сообщений
  if source.IsIPEmpty or not Assigned(m) then
    Exit;

  try
    node := FEngine.RoutingTable.FindNode(m.ID);

    if not Assigned(node) then
    begin
      node := TNode.Create(m.ID, source);
      FEngine.RoutingTable.Add(node);
    end;

    node.Seen;
    m.Handle(FEngine, node);

    if Supports(m, IResponseMessage, response) then
    begin
      for i := 0 to FWaitingResponse.Count - 1 do
        if FWaitingResponse[i].Msg.TransactionId.Equals(response.TransactionId) then
        begin
          FWaitingResponse.Delete(i);
          Break;
        end;

      RaiseMessageSent(node.EndPoint, response.Query, response);
    end;
  except
//    on E: EMessageException do
//      Console.WriteLine("Incoming message barfed: {0}", ex);
    on E: Exception do
      EnqueueSend(TErrorMessage.Create(TErrorCode.GenericError, 'Misshandle received message!'), source);
  end;
end;

procedure TMessageLoop.SendMessage(AMsg: IMessage; ADest: TVarSin);
var
  buf: TUniString;
begin
  buf := AMsg.Encode;

  FListener.SendUniString(ADest.Host, ADest.Port, ADest.IPVersion, buf);
end;

procedure TMessageLoop.Start;
begin
  {if FListener.Status <> sListening then
    FListener.Start;}
  FListener.Active := True;
end;

procedure TMessageLoop.Stop;
begin
  {if FListener.Status <> sNotListening then
    FListener.Stop;}
  FListener.UnregisterReceiveEvent(ParseMessage);
  FListener.Active := False;
end;

procedure TMessageLoop.TimeoutMessage;
var
  details: ISendDetails;
begin
  if (FWaitingResponse.Count > 0) and
    (TTimeSpan.Subtract(UtcNow, FWaitingResponse.First.SentAt) > FEngine.TimeOut) then
  begin
    details := FWaitingResponse.First;
    FWaitingResponse.Remove(details);

    Assert(Supports(details.Msg, IQueryMessage));
    TMessageFactory.UnregisterSend(details.Msg as IQueryMessage);
    RaiseMessageSent(details.Destination, details.Msg as IQueryMessage, nil);
  end;
end;

procedure TMessageLoop.UnlockQuerySent;
begin
  TMonitor.Exit(FOnQuerySentLock);
end;

procedure TMessageLoop.SendMessage;
var
  send: ISendDetails;
begin
  TMonitor.Enter(FSendQueueLock);
  try
    if CanSend then
      send := FSendQueue.Dequeue
    else
      send := nil;
  finally
    TMonitor.Exit(FSendQueueLock);
  end;

  if Assigned(send) then
  begin
    SendMessage(send.Msg, send.Destination);
    send.SentAt := UtcNow;

    if Supports(send.Msg, IQueryMessage) then
      FWaitingResponse.Add(send);
  end;
end;

{ TMessageLoop.TSendDetails }

constructor TMessageLoop.TSendDetails.Create(ADest: TVarSin; AMsg: IMessage);
begin
  FDestination := ADest;
  FMsg := AMsg;
  FSentAt := MinDateTime;
end;

{ TMessageLoop.TTransactionID }

class constructor TMessageLoop.TTransactionID.ClassCreate;
begin
  FLock := TObject.Create;
end;

class destructor TMessageLoop.TTransactionID.ClassDestroy;
begin
  FLock.Free;
end;

class function TMessageLoop.TTransactionID.NextID: IBencodedString;
var
  foo: TUniString;
begin
  TMonitor.Enter(FLock);
  try
    foo.Len := Length(FCurrent);
    Move(FCurrent[0], foo.DataPtr[0]^, foo.Len);
    Result := BencodeString(foo);

    if FCurrent[0] = 255 then
      Inc(FCurrent[1]);
    Inc(FCurrent[0]);
  finally
    TMonitor.Exit(FLock);
  end;
end;

{ TMessageLoop.TSendDetails }

function TMessageLoop.TSendDetails.GetDestination: TVarSin;
begin
  Result := FDestination;
end;

function TMessageLoop.TSendDetails.GetMsg: IMessage;
begin
  Result := FMsg;
end;

function TMessageLoop.TSendDetails.GetSentAt: TDateTime;
begin
  Result := FSentAt;
end;

//procedure TMessageLoop.TSendDetails.SetDestination(const Value: TVarSin);
//begin
//  FDestination := Value;
//end;
//
//procedure TMessageLoop.TSendDetails.SetMsg(const Value: TMessage);
//begin
//  FMsg := Value;
//end;

procedure TMessageLoop.TSendDetails.SetSentAt(const Value: TDateTime);
begin
  FSentAt := Value;
end;

end.
