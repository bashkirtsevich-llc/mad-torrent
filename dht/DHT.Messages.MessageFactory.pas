unit DHT.Messages.MessageFactory;

interface

uses
  System.Generics.Defaults,
  Basic.Bencoding,
  DHT.Engine;

type
  TMessageFactory = class sealed { static class }
  private
    const
      QueryNameKey      = 'q';
      MessageTypeKey    = 'y';
      TransactionIdKey  = 't';

    class var FMessages: TGenDictionary<IBencodedValue, IQueryMessage>;
    class var FMessagesLock: TObject;
    class var FQueryDecoders: TGenDictionary<IBencodedString, TCreator>;
  public
    class function RegisteredMessages: Integer; static;
    class procedure RegisterSend(AMessage: IQueryMessage); static;
    class procedure UnregisterSend(AMessage: IQueryMessage); static;
    class function DecodeMessage(ADict: IBencodedDictionary): IMessage; static; deprecated 'не используется';
    class function TryDecodeMessage(ADict: IBencodedDictionary;
      var AMsg: IMessage): Boolean; overload; static;
    class function TryDecodeMessage(ADict: IBencodedDictionary; var AMsg: IMessage;
      out AError: string): Boolean; overload; static;
    class function IsRegistered(ATransactionId: IBencodedValue): Boolean; static;

    class constructor ClassCreate;
    class destructor ClassDestroy;
  end;

implementation

uses
  DHT.Messages;

{ TMessageFactory }

class constructor TMessageFactory.ClassCreate;
begin
  FMessages := TGenDictionary<IBencodedValue, IQueryMessage>.Create(
    TDelegatedEqualityComparer<IBencodedValue>.Create(
      function (const ALeft, ARight: IBencodedValue): Boolean
      begin
        Result := ALeft.GetHashCode = ARight.GetHashCode;
      end,
      function (const AValue: IBencodedValue): Integer
      begin
        Result := AValue.GetHashCode;
      end
    ) as IEqualityComparer<IBencodedValue>);

  FMessagesLock := TObject.Create;

  FQueryDecoders := TGenDictionary<IBencodedString, TCreator>.Create(
    TDelegatedEqualityComparer<IBencodedString>.Create(
      function (const ALeft, ARight: IBencodedString): Boolean
      begin
        Result := ALeft.GetHashCode = ARight.GetHashCode;
      end,
      function (const AValue: IBencodedString): Integer
      begin
        Result := AValue.GetHashCode;
      end
    ) as IEqualityComparer<IBencodedString>);

  FQueryDecoders.Add(BencodeString('announce_peer') ,
    function (d: IBencodedDictionary): IMessage
    begin
      Result := TAnnouncePeer.Create(d);
    end);
  FQueryDecoders.Add(BencodeString('find_node')     ,
    function (d: IBencodedDictionary): IMessage
    begin
      Result := TFindNode.Create(d);
    end);
  FQueryDecoders.Add(BencodeString('get_peers')     ,
    function (d: IBencodedDictionary): IMessage
    begin
      Result := TGetPeers.Create(d);
    end);
  FQueryDecoders.Add(BencodeString('ping')          ,
    function (d: IBencodedDictionary): IMessage
    begin
      Result := TPing.Create(d);
    end);
end;

class destructor TMessageFactory.ClassDestroy;
begin
  FMessages.Free;
  FMessagesLock.Free;
  FQueryDecoders.Free;
end;

class function TMessageFactory.DecodeMessage(
  ADict: IBencodedDictionary): IMessage;
var
  error: string;
begin
  Result := nil;

  if not TryDecodeMessage(ADict, Result, error) then
    raise EMessageFactory.Create(error);
end;

class function TMessageFactory.IsRegistered(
  ATransactionId: IBencodedValue): Boolean;
begin
  Result := FMessages.ContainsKey(ATransactionId);
end;

class function TMessageFactory.RegisteredMessages: Integer;
begin
  Result := FMessages.Count;
end;

class procedure TMessageFactory.RegisterSend(AMessage: IQueryMessage);
begin
  TMonitor.Enter(FMessagesLock);
  try
    FMessages.Add(AMessage.TransactionId, AMessage);
  finally
    TMonitor.Exit(FMessagesLock);
  end;
end;

class function TMessageFactory.TryDecodeMessage(ADict: IBencodedDictionary;
  var AMsg: IMessage; out AError: string): Boolean;
var
  key: IBencodedString;
  query: IQueryMessage;
begin
  AMsg := nil;
  AError := '';

  if (ADict[MessageTypeKey] as IBencodedString).Value = TQueryMessage.QueryType then
    AMsg := FQueryDecoders[(ADict[QueryNameKey] as IBencodedString)](ADict)
  else
  if (ADict[MessageTypeKey] as IBencodedString).Value = TErrorMessage.ErrorType then
    AMsg := TErrorMessage.Create(ADict)
  else
  begin
    key := (ADict[TransactionIdKey] as IBencodedString);

    if FMessages.TryGetValue(key, query) then
    begin
      FMessages.Remove(key);
      try
        AMsg := query.ResponseCreator(ADict, query);
      except
        AError := 'Response dictionary was invalid';
      end;
    end else
      AError := 'Response had bad transaction ID';
  end;

  Result := (AError = '') and Assigned(AMsg);
end;

class function TMessageFactory.TryDecodeMessage(ADict: IBencodedDictionary;
  var AMsg: IMessage): Boolean;
var
  error: string;
begin
  Result := TryDecodeMessage(ADict, AMsg, error);
end;

class procedure TMessageFactory.UnregisterSend(AMessage: IQueryMessage);
begin
  TMonitor.Enter(FMessagesLock);
  try
    FMessages.Remove(AMessage.TransactionId);
  finally
    TMonitor.Exit(FMessagesLock);
  end;
end;

end.
