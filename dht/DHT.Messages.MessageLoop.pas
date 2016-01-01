unit DHT.Messages.MessageLoop;

interface

uses
  System.SysUtils, System.DateUtils, System.TimeSpan,
  System.Generics.Collections, System.Generics.Defaults,
  Basic.Bencoding, Basic.UniString,
  Common.BusyObj,
  DHT, DHT.Listener,
  IdGlobal;

type
  TMessageLoop = class(TBusy, IMessageLoop)
  private
    const
      QueryNameKey      = 'q';
      MessageTypeKey    = 'y';
      TransactionIdKey  = 't';
    type
      IDetails = interface
      ['{AF339B88-3D00-46D5-9E4B-6B7C66E26077}']
        function GetHost: string;
        function GetPort: TIdPort;
        function GetMsg: IMessage;

        property Host: string read GetHost;
        property Port: TIdPort read GetPort;
        property Msg: IMessage read GetMsg;
      end;

      ISendDetails = interface(IDetails)
      ['{BB733FE2-683E-479C-85E2-E595E0B33711}']
        function GetSentAt: TDateTime;
        procedure SetSentAt(const Value: TDateTime);
        function GetOnSent: TProc<ISendQueryEventArgs>;

        property SentAt: TDateTime read GetSentAt write SetSentAt;
        property OnSent: TProc<ISendQueryEventArgs> read GetOnSent;
      end;

      IReceiveDetails = interface(IDetails)
      ['{4B7C241A-40C4-4473-A7DA-7FA37E503B0D}']
      end;

      TDetails = class(TInterfacedObject, IDetails)
      private
        FHost: string;
        FPort: TIdPort;
        FMsg: IMessage;
        FSentAt: TDateTime;

        function GetHost: string; inline;
        function GetPort: TIdPort; inline;
        function GetMsg: IMessage; inline;
      public
        constructor Create(const AHost: string; APort: TIdPort;
          AMsg: IMessage); reintroduce;
      end;

      TSendDetails = class(TDetails, ISendDetails)
      private
        FSentAt: TDateTime;
        FOnSent: TProc<ISendQueryEventArgs>;

        function GetSentAt: TDateTime; inline;
        procedure SetSentAt(const Value: TDateTime); inline;
        function GetOnSent: TProc<ISendQueryEventArgs>; inline;
      public
        constructor Create(const AHost: string; APort: TIdPort;
          AMsg: IMessage; AOnSent: TProc<ISendQueryEventArgs>); reintroduce;
      end;

      TReceiveDetails = class(TDetails, IReceiveDetails)
      end;
  private
    FListener: TDHTListener;

    FSendQueue: TQueue<ISendDetails>;
    FSendQueueLock: TObject;

    FReceiveQueue: TQueue<IReceiveDetails>;
    FReceiveQueueLock: TObject;
    FOnReceiveMessage: TProc<string, TIdPort, IMessage>;
    FOnError: TProc<IMessageLoop, string, TIdPort, Exception>;

    FWaitingResponse: TDictionary<TUniString, ISendDetails>;
    FWaitingResponseLock: TObject;
    FMessageTimeOut: TTimeSpan;

    procedure SendMessage; overload; inline;
    procedure SendMessage(const AHost: string; APort: TIdPort;
      AMsg: IMessage); overload; inline;
    procedure ReceiveMessage;
    procedure TimeoutMessage;

    function ParseQueryMessage(ADict: IBencodedDictionary): IMessage;
    function ParseErrorMessage(ADict: IBencodedDictionary): IMessage;
    function ParseResponseMessage(AHost: string; APort: TIdPort;
      ADict: IBencodedDictionary): IMessage;
    procedure ParseMessage(AHost: string; APort: TIdPort; ABuffer: TUniString);

    procedure LockSendQueue; inline;
    procedure UnlockSendQueue; inline;

    procedure LockReceiveQueue; inline;
    procedure UnlockReceiveQueue; inline;

    procedure LockWaitingResponse; inline;
    procedure UnlockWaitingResponse; inline;
  private
    { IMessageLoop }
    function GetOnError: TProc<IMessageLoop, string, TIdPort, Exception>; inline;
    procedure SetOnError(const Value: TProc<IMessageLoop, string, TIdPort,
      Exception>); inline;

    procedure EnqueueSend(const AHost: string; APort: TIdPort;
      AMessage: IMessage; AOnSent: TProc<ISendQueryEventArgs> = nil); overload;
    procedure EnqueueSend(ANode: INode; AMessage: IMessage;
      AOnSent: TProc<ISendQueryEventArgs> = nil); overload; inline;

    procedure Start; inline;
    procedure Stop; inline;
  protected
    procedure DoSync; override;
  public
    constructor Create(AListenPort: TIdPort; AMessageTimeOut: TTimeSpan;
      AOnReceiveMessage: TProc<string, TIdPort, IMessage>);
    destructor Destroy; override;
  end;

implementation

uses
  DHT.Messages, DHT.Tasks.Events, DHT.Node;

{ TMessageLoop }

constructor TMessageLoop.Create(AListenPort: TIdPort; AMessageTimeOut: TTimeSpan;
  AOnReceiveMessage: TProc<string, TIdPort, IMessage>);
begin
  inherited Create;

  FListener := TDHTListener.Create(AListenPort);
  FListener.OnReceive := ParseMessage;

  FMessageTimeOut   := AMessageTimeOut;
  FOnReceiveMessage := AOnReceiveMessage;

  FWaitingResponse := TDictionary<TUniString, ISendDetails>.Create(
    TDelegatedEqualityComparer<TUniString>.Create(
      function (const ALeft, ARight: TUniString): Boolean
      begin
        Result := ALeft.GetHashCode = ARight.GetHashCode;
      end,
      function (const AValue: TUniString): Integer
      begin
        Result := AValue.GetHashCode;
      end
    )
  );
  FWaitingResponseLock := TObject.Create;

  FReceiveQueue     := TQueue<IReceiveDetails>.Create;
  FReceiveQueueLock := TObject.Create;

  FSendQueue        := TQueue<ISendDetails>.Create;
  FSendQueueLock    := TObject.Create;
end;

destructor TMessageLoop.Destroy;
begin
  Stop;

  FWaitingResponse.Free;
  FWaitingResponseLock.Free;

  FReceiveQueue.Free;
  FReceiveQueueLock.Free;

  FSendQueue.Free;
  FSendQueueLock.Free;

  FListener.Free;
  inherited;
end;

procedure TMessageLoop.DoSync;
begin
  SendMessage;
  ReceiveMessage;
  TimeoutMessage;
end;

procedure TMessageLoop.EnqueueSend(const AHost: string; APort: TIdPort;
  AMessage: IMessage; AOnSent: TProc<ISendQueryEventArgs>);
begin
  if Supports(AMessage, IResponseMessage) then
    Assert(not AMessage.TransactionId.Empty);

  LockSendQueue;
  try
    FSendQueue.Enqueue(TSendDetails.Create(AHost, APort, AMessage, AOnSent));
  finally
    UnlockSendQueue;
  end;
end;

procedure TMessageLoop.EnqueueSend(ANode: INode; AMessage: IMessage;
  AOnSent: TProc<ISendQueryEventArgs>);
begin
  EnqueueSend(ANode.Host, ANode.Port, AMessage, AOnSent);
end;

function TMessageLoop.GetOnError: TProc<IMessageLoop, string, TIdPort, Exception>;
begin
  Result := FOnError;
end;

procedure TMessageLoop.LockReceiveQueue;
begin
  TMonitor.Enter(FReceiveQueueLock);
end;

procedure TMessageLoop.LockSendQueue;
begin
  TMonitor.Enter(FSendQueueLock);
end;

procedure TMessageLoop.LockWaitingResponse;
begin
  TMonitor.Enter(FWaitingResponseLock);
end;

function TMessageLoop.ParseErrorMessage(ADict: IBencodedDictionary): IMessage;
begin
  Result := TErrorMessage.CreateFromDict(ADict);
end;

procedure TMessageLoop.ParseMessage(AHost: string; APort: TIdPort;
  ABuffer: TUniString);
begin
  try
    BencodeParse(ABuffer, False,
      function (ALen: Integer; AValue: IBencodedValue): Boolean
      var
        msg: IMessage;
        dict: IBencodedDictionary;
      begin
        Assert(Supports(AValue, IBencodedDictionary));
        Assert((AValue as IBencodedDictionary).Childs.Count > 0);

        dict := AValue as IBencodedDictionary;

        if dict.ContainsKey(MessageTypeKey) then
        with dict[MessageTypeKey] as IBencodedString do
        begin
          if Value = TQueryMessage.QueryType then
            msg := ParseQueryMessage(dict)
          else
          if Value = TErrorMessage.ErrorType then
            msg := ParseErrorMessage(dict)
          else
            msg := ParseResponseMessage(AHost, APort, dict);
        end else
          msg := ParseResponseMessage(AHost, APort, dict);

        if Assigned(msg) then
        begin
          LockReceiveQueue;
          try
            FReceiveQueue.Enqueue(TReceiveDetails.Create(AHost, APort, msg));
          finally
            UnlockReceiveQueue;
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

function TMessageLoop.ParseQueryMessage(ADict: IBencodedDictionary): IMessage;
const
  Queries: array[0..3] of TQueryMessages = (TAnnouncePeer, TFindNode,
    TGetPeers, TPing);
var
  it: TQueryMessages;
begin
  with (ADict[QueryNameKey] as IBencodedString) do
    for it in Queries do
      if it.GetQueryName = Value then
        Exit(it.CreateFromDict(ADict));

  Result := nil;
end;

function TMessageLoop.ParseResponseMessage(AHost: string; APort: TIdPort;
  ADict: IBencodedDictionary): IMessage;
var
  it: ISendDetails;
  q: IQueryMessage;
begin
  LockWaitingResponse;
  try
    if ADict.ContainsKey(TransactionIdKey) and FWaitingResponse.TryGetValue(
        (ADict[TransactionIdKey] as IBencodedString).Value + AHost + APort, it) and
        Supports(it.Msg, IQueryMessage, q) then
      Result := (it.Msg as IQueryMessage).ResponseCreator(ADict, q)
    else
      Result := nil;
  finally
    UnlockWaitingResponse;
  end;
end;

procedure TMessageLoop.ReceiveMessage;
var
  receive: IReceiveDetails;
  send: ISendDetails;
  key: TUniString;
  response: IResponseMessage;
begin
  LockReceiveQueue;
  try
    if FReceiveQueue.Count > 0 then
      receive := FReceiveQueue.Dequeue
    else
      receive := nil;
  finally
    UnlockReceiveQueue;
  end;

  if Assigned(receive) then
  try
    if Assigned(FOnReceiveMessage) then
      with receive do
        FOnReceiveMessage(Host, Port, Msg);

    if Supports(receive.Msg, IResponseMessage, response) then
    begin
      { определяем, что да, это ожидаемое сообщение от этого нода }
      with receive do
        key := Msg.TransactionId + Host + Port;

      LockWaitingResponse;
      try
        if FWaitingResponse.TryGetValue(key, send) then
          FWaitingResponse.Remove(key);
      finally
        UnlockWaitingResponse;
      end;

      if Assigned(send) and Assigned(send.OnSent) then
        send.OnSent(TSendQueryEventArgs.Create(send.Host, send.Port,
          response.Query, response));
    end;
  except
    on E: Exception do
    begin
      // на ожидаемый нами ответ нет смысла отправлять ошибку
      if Supports(receive.Msg, IQueryMessage) then
        EnqueueSend(receive.Host, receive.Port,
          TErrorMessage.Create(
            ecGenericError,
            'Misshandle received message!',
            receive.Msg.TransactionId
          )
        )
      else
      if Assigned(FOnError) then
        FOnError(Self, receive.Host, receive.Port, E);
    end;
  end;
end;

procedure TMessageLoop.SendMessage(const AHost: string; APort: TIdPort;
  AMsg: IMessage);
begin
  FListener.SendUniString(AHost, APort, AMsg.Encode);
end;

procedure TMessageLoop.SetOnError(const Value: TProc<IMessageLoop, string,
  TIdPort, Exception>);
begin
  FOnError := Value;
end;

procedure TMessageLoop.Start;
begin
  FListener.Active := True;
end;

procedure TMessageLoop.Stop;
begin
  FListener.Active := False;
end;

procedure TMessageLoop.TimeoutMessage;
var
  key: TUniString;
  t: TDateTime;
begin
  LockWaitingResponse;
  try
    t := Now;

    for key in FWaitingResponse.Keys do
      with FWaitingResponse[key] do
        if TTimeSpan.Subtract(t, SentAt) > FMessageTimeOut then
        begin
          FWaitingResponse.Remove(key);

          if Assigned(OnSent) then
          begin
            Assert(Supports(Msg, IQueryMessage));
            OnSent(TSendQueryEventArgs.Create(Host, Port, Msg as IQueryMessage, nil));
          end;

          Break;
        end;
  finally
    UnlockWaitingResponse;
  end;
end;

procedure TMessageLoop.UnlockReceiveQueue;
begin
  TMonitor.Exit(FReceiveQueueLock);
end;

procedure TMessageLoop.UnlockSendQueue;
begin
  TMonitor.Exit(FSendQueueLock);
end;

procedure TMessageLoop.UnlockWaitingResponse;
begin
  TMonitor.Exit(FWaitingResponseLock);
end;

procedure TMessageLoop.SendMessage;
var
  send: ISendDetails;
begin
  LockSendQueue;
  try
    if FSendQueue.Count > 0 then
      send := FSendQueue.Dequeue
    else
      send := nil;
  finally
    UnlockSendQueue;
  end;

  if Assigned(send) then
  begin
    SendMessage(send.Host, send.Port, send.Msg);

    // We need to be able to cancel a query message if we time out waiting for a response
    if Supports(send.Msg, IQueryMessage) then
    begin
      send.SentAt := Now;

      LockWaitingResponse;
      try
        FWaitingResponse.Add(send.Msg.TransactionId + send.Host + send.Port, send);
      finally
        UnlockWaitingResponse;
      end;
    end;
  end;
end;

{ TMessageLoop.TSendDetails }

constructor TMessageLoop.TSendDetails.Create(const AHost: string;
  APort: TIdPort; AMsg: IMessage; AOnSent: TProc<ISendQueryEventArgs>);
begin
  inherited Create(AHost, APort, AMsg);

  FOnSent := AOnSent;
end;

function TMessageLoop.TSendDetails.GetOnSent: TProc<ISendQueryEventArgs>;
begin
  Result := FOnSent;
end;

function TMessageLoop.TSendDetails.GetSentAt: TDateTime;
begin
  Result := FSentAt;
end;

procedure TMessageLoop.TSendDetails.SetSentAt(const Value: TDateTime);
begin
  FSentAt := Value;
end;

{ TMessageLoop.TDetails }

constructor TMessageLoop.TDetails.Create(const AHost: string; APort: TIdPort;
  AMsg: IMessage);
begin
  inherited Create;

  FHost := AHost;
  FPort := APort;
  FMsg := AMsg;
  FSentAt := MinDateTime;
end;

function TMessageLoop.TDetails.GetHost: string;
begin
  Result := FHost;
end;

function TMessageLoop.TDetails.GetMsg: IMessage;
begin
  Result := FMsg;
end;

function TMessageLoop.TDetails.GetPort: TIdPort;
begin
  Result := FPort;
end;

end.
