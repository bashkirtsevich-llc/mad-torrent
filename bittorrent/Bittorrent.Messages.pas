unit Bittorrent.Messages;

interface

uses
  System.SysUtils,
  System.Generics.Defaults,
  Spring.Collections,
  Bittorrent, Bittorrent.Bitfield, Basic.UniString,
  IdIOHandler, IdIOHandlerHelper, IdGlobal;

type
  TMessage = class abstract(TInterfacedObject, IMessage)
  private
    procedure Send(AIOHandler: TIdIOHandler); inline;
  protected
    procedure ReadFromIOHandler(AIOHandler: TIdIOHandler; AMsgSize: Integer); virtual; abstract;
    procedure WriteToIOHandler(AIOHandler: TIdIOHandler); virtual; abstract;
  public
    constructor CreateFromIOHandler(AIOHandler: TIdIOHandler; AMsgSize: Integer);
  end;

  TFixedMessagesClass = class of TFixedMessage;

  TFixedMessage = class abstract(TMessage, IFixedMessage)
  private
//    function GetPayloadSize: Integer; inline;
    function GetMessageID: TFixedMessageID; inline;
  protected
    function MessageLen: Integer; virtual;
    procedure WriteToIOHandler(AIOHandler: TIdIOHandler); override;
  protected
    class function ClassMessageID: TFixedMessageID; virtual; abstract;
  public
    class function ParseMessage(AIOHandler: TIdIOHandler): IMessage; static;
  end;

  { класс-затычка, перекрывающая абстрактный метод ReadFromIOHandler }
  TAtomicMessage = class abstract(TFixedMessage)
  protected
    procedure ReadFromIOHandler(AIOHandler: TIdIOHandler; AMsgSize: Integer); override;
  end;

  TChokeMessage = class(TAtomicMessage, IChokeMessage)
  protected
    class function ClassMessageID: TFixedMessageID; override;
  end;

  TUnchokeMessage = class(TAtomicMessage, IUnchokeMessage)
  protected
    class function ClassMessageID: TFixedMessageID; override;
  end;

  TInterestedMessage = class(TAtomicMessage, IInterestedMessage)
  protected
    class function ClassMessageID: TFixedMessageID; override;
  end;

  TNotInterestedMessage = class(TAtomicMessage, INotInterestedMessage)
  protected
    class function ClassMessageID: TFixedMessageID; override;
  end;

  THaveMessage = class(TFixedMessage, IHaveMessage)
  private
    FPieceIndex: Integer;
    function GetPieceIndex: Integer; inline;
  protected
    function MessageLen: Integer; override;
    procedure ReadFromIOHandler(AIOHandler: TIdIOHandler; AMsgSize: Integer); override;
    procedure WriteToIOHandler(AIOHandler: TIdIOHandler); override;
  protected
    class function ClassMessageID: TFixedMessageID; override;
  public
    constructor Create(APieceIndex: Integer);
  end;

  TBitfieldMessage = class(TFixedMessage, IBitfieldMessage)
  private
    FBitfield: TBitField;
    function GetBits: TBitField; inline;
  protected
    function MessageLen: Integer; override;
    procedure ReadFromIOHandler(AIOHandler: TIdIOHandler; AMsgSize: Integer); override;
    procedure WriteToIOHandler(AIOHandler: TIdIOHandler); override;
  protected
    class function ClassMessageID: TFixedMessageID; override;
  public
    constructor Create(const ABits: TBitField);
  end;

  TRequestMessage = class(TFixedMessage, IRequestMessage)
  private
    FPieceIndex,
    FOffset,
    FSize: Integer;

    function GetPieceIndex: Integer; inline;
    function GetOffset: Integer; inline;
    function GetSize: Integer; inline;
  protected
    function MessageLen: Integer; override;
    procedure ReadFromIOHandler(AIOHandler: TIdIOHandler; AMsgSize: Integer); override;
    procedure WriteToIOHandler(AIOHandler: TIdIOHandler); override;
  protected
    class function ClassMessageID: TFixedMessageID; override;
  public
    constructor Create(APieceIndex, AOffset, ASize: Integer);
  end;

  TPieceMessage = class(TFixedMessage, IPieceMessage)
  private
    FPieceIndex,
    FOffset: Integer;
    FBlock: TUniString;

    function GetPieceIndex: Integer; inline;
    function GetOffset: Integer; inline;
    function GetBlock: TUniString; inline;
  protected
    function MessageLen: Integer; override;
    procedure ReadFromIOHandler(AIOHandler: TIdIOHandler; AMsgSize: Integer); override;
    procedure WriteToIOHandler(AIOHandler: TIdIOHandler); override;
  protected
    class function ClassMessageID: TFixedMessageID; override;
  public
    constructor Create(APieceIndex, AOffset: Integer; ABlock: TUniString);
  end;

  TCancelMessage = class(TFixedMessage, ICancelMessage)
  private
    FPieceIndex,
    FOffset,
    FSize: Integer;

    function GetPieceIndex: Integer; inline;
    function GetOffset: Integer; inline;
    function GetSize: Integer; inline;
  protected
    function MessageLen: Integer; override;
    procedure ReadFromIOHandler(AIOHandler: TIdIOHandler; AMsgSize: Integer); override;
    procedure WriteToIOHandler(AIOHandler: TIdIOHandler); override;
  protected
    class function ClassMessageID: TFixedMessageID; override;
  public
    constructor Create(APieceIndex, AOffset, ASize: Integer);
  end;

  TPortMessage = class(TFixedMessage, IPortMessage)
  private
    FPort: TIdPort;
    function GetPort: TIdPort; inline;
  protected
    function MessageLen: Integer; override;
    procedure ReadFromIOHandler(AIOHandler: TIdIOHandler; AMsgSize: Integer); override;
    procedure WriteToIOHandler(AIOHandler: TIdIOHandler); override;
  protected
    class function ClassMessageID: TFixedMessageID; override;
  public
    constructor Create(APort: TIdPort);
  end;

  TExtensionMessage = class(TFixedMessage, IExtensionMessage)
  public
    const
      HandshakeMsgID = 0;
  protected
    FMessageID: Byte;
    FMessageData: TUniString;
    FExtendedMsg: IExtension;
    function GetExtension: IExtension; inline;
    function GetMessageID: Byte; inline;
  protected
    function MessageLen: Integer; override;
    procedure ReadFromIOHandler(AIOHandler: TIdIOHandler; AMsgSize: Integer); override;
    procedure WriteToIOHandler(AIOHandler: TIdIOHandler); override;
  protected
    class function ClassMessageID: TFixedMessageID; override;
  public
    constructor Create(AMessageID: Byte; AExtendedMsgData: TUniString); overload;
    constructor Create(ASupportsDict: IDictionary<string, Byte>; AExtendedMsg: IExtension); overload;
  end;

  TKeepAliveMessage = class(TMessage, IKeepAliveMessage)
  private
    FDmmy: TUniString;
    function GetDummy: TUniString; inline;
  protected
    procedure ReadFromIOHandler(AIOHandler: TIdIOHandler; AMsgSize: Integer); override;
    procedure WriteToIOHandler(AIOHandler: TIdIOHandler); override;
  end;

  THandshakeMessage = class(TMessage, IHandshakeMessage)
  private
    const
      ProtocolIdentifier = 'BitTorrent protocol';

      {$REGION 'Flags'}
      FlagsLen                = 8;

      OffsetExtendedMessaging = -3;
      FlagExtendedMessaging   = $10;

      OffsetFastPeer          = -1;
      FlagFastPeer            = $04;

      OffsetDHT               = -1;
      FlagDHT                 = $01;
      {$ENDREGION}
  private
    FInfoHash,
    FFlags,
    FPeerID: TUniString;

    function GetInfoHash: TUniString; inline;
    function GetPeerID: TUniString; inline;
    function GetFlags: TUniString; inline;

    function GetSupportsDHT: Boolean; inline;
    function GetSupportsExtendedMessaging: Boolean; inline;
    function GetSupportsFastPeer: Boolean; inline;
  protected
    procedure ReadFromIOHandler(AIOHandler: TIdIOHandler; AMsgSize: Integer); override;
    procedure WriteToIOHandler(AIOHandler: TIdIOHandler); override;
  public
    constructor Create(AInfoHash, APeerID: TUniString;
      AEnableDHT, AEnableFastPeer, AEnableExtended: Boolean);
    constructor CreateFromIOHandler(AIOHandler: TIdIOHandler); reintroduce;
  end;

implementation

uses
  Bittorrent.Extensions;

{ TMessage }

constructor TMessage.CreateFromIOHandler(AIOHandler: TIdIOHandler;
  AMsgSize: Integer);
begin
  inherited Create;

  ReadFromIOHandler(AIOHandler, AMsgSize);
end;

procedure TMessage.Send(AIOHandler: TIdIOHandler);
begin
  AIOHandler.WriteBufferOpen;
  try
    WriteToIOHandler(AIOHandler);
  finally
    AIOHandler.WriteBufferFlush;
  end;
end;

{ TChokeMessage }

class function TChokeMessage.ClassMessageID: TFixedMessageID;
begin
  Result := idChoke;
end;

{ THaveMessage }

constructor THaveMessage.Create(APieceIndex: Integer);
begin
  inherited Create;
  FPieceIndex := APieceIndex;
end;

class function THaveMessage.ClassMessageID: TFixedMessageID;
begin
  Result := idHave;
end;

function THaveMessage.GetPieceIndex: Integer;
begin
  Result := FPieceIndex;
end;

function THaveMessage.MessageLen: Integer;
begin
  Result := inherited MessageLen;
  Result := Result + FPieceIndex.Size;
end;

procedure THaveMessage.ReadFromIOHandler(AIOHandler: TIdIOHandler;
  AMsgSize: Integer);
begin
  Assert(AMsgSize = 4);
  FPieceIndex := AIOHandler.ReadLongWord;
end;

procedure THaveMessage.WriteToIOHandler(AIOHandler: TIdIOHandler);
begin
  inherited WriteToIOHandler(AIOHandler);
  AIOHandler.Write(FPieceIndex);
end;

{ TBitfieldMessage }

class function TBitfieldMessage.ClassMessageID: TFixedMessageID;
begin
  Result := idBitfield;
end;

constructor TBitfieldMessage.Create(const ABits: TBitField);
begin
  inherited Create;
  FBitfield := ABits;
end;

function TBitfieldMessage.GetBits: TBitField;
begin
  Result := FBitfield;
end;

function TBitfieldMessage.MessageLen: Integer;
begin
  Result := inherited MessageLen;
  Result := Result + FBitfield.LengthInBytes;
end;

procedure TBitfieldMessage.ReadFromIOHandler(AIOHandler: TIdIOHandler;
  AMsgSize: Integer);
var
  buf: TUniString;
begin
  //AIOHandler.ReadBytes(buf, AMsgSize);
  //FBitfield := FBitfield.FromUniString(buf);
  AIOHandler.ReadUniString(AMsgSize, buf);
  FBitfield := FBitfield.FromUniString(buf);
end;

procedure TBitfieldMessage.WriteToIOHandler(AIOHandler: TIdIOHandler);
begin
  inherited WriteToIOHandler(AIOHandler);
  AIOHandler.WriteUniString(FBitfield.AsUniString);
end;

{ TRequestMessage }

constructor TRequestMessage.Create(APieceIndex, AOffset, ASize: Integer);
begin
  inherited Create;

  FPieceIndex := APieceIndex;
  FOffset := AOffset;
  FSize := ASize;
end;

class function TRequestMessage.ClassMessageID: TFixedMessageID;
begin
  Result := idRequest;
end;

function TRequestMessage.GetOffset: Integer;
begin
  Result := FOffset;
end;

function TRequestMessage.GetPieceIndex: Integer;
begin
  Result := FPieceIndex;
end;

function TRequestMessage.GetSize: Integer;
begin
  Result := FSize;
end;

function TRequestMessage.MessageLen: Integer;
begin
  Result := inherited MessageLen;
  Result := Result + FPieceIndex.Size + FOffset.Size + FSize.Size;
end;

procedure TRequestMessage.ReadFromIOHandler(AIOHandler: TIdIOHandler;
  AMsgSize: Integer);
begin
  with AIOHandler do
  begin
    FPieceIndex := ReadLongInt;
    FOffset     := ReadLongInt;
    FSize       := ReadLongInt;
  end;
end;

procedure TRequestMessage.WriteToIOHandler(AIOHandler: TIdIOHandler);
begin
  inherited WriteToIOHandler(AIOHandler);

//  DebugOutput(PChar('отправлен запрос куска #'+FPieceIndex.ToString));
  AIOHandler.Write(FPieceIndex);
  AIOHandler.Write(FOffset);
  AIOHandler.Write(FSize);
end;

{ TPieceMessage }

constructor TPieceMessage.Create(APieceIndex, AOffset: Integer;
  ABlock: TUniString);
begin
  inherited Create;
  FPieceIndex := APieceIndex;
  FOffset := AOffset;
  FBlock.Assign(ABlock);
end;

class function TPieceMessage.ClassMessageID: TFixedMessageID;
begin
  Result := idPiece;
end;

function TPieceMessage.GetBlock: TUniString;
begin
  Result := FBlock;
end;

function TPieceMessage.GetOffset: Integer;
begin
  Result := FOffset;
end;

function TPieceMessage.GetPieceIndex: Integer;
begin
  Result := FPieceIndex;
end;

function TPieceMessage.MessageLen: Integer;
begin
  Result := inherited MessageLen;

  Result := Result + FPieceIndex.Size + FOffset.Size + FBlock.Len;
end;

procedure TPieceMessage.ReadFromIOHandler(AIOHandler: TIdIOHandler;
  AMsgSize: Integer);
//var
//  buf: TIdBytes;
begin
  FPieceIndex := AIOHandler.ReadLongWord;
  FOffset := AIOHandler.ReadLongWord;

//  AIOHandler.ReadBytes(buf, AMsgSize - FPieceIndex.Size - FOffset.Size);
//  FBlock := buf;
  AIOHandler.ReadUniString(AMsgSize - FPieceIndex.Size - FOffset.Size, FBlock);
end;

procedure TPieceMessage.WriteToIOHandler(AIOHandler: TIdIOHandler);
//var
//  b: TIdBytes;
begin
  inherited WriteToIOHandler(AIOHandler);

  with AIOHandler do
  begin
    Write(FPieceIndex);
    Write(FOffset);

//    { FIXME: FBlock неявно преобразуется в строку и при отправке данных в сеть, получается херня }
//    SetLength(b, FBlock.Len);
//    Move(FBlock.DataPtr[0]^, b[0], FBlock.Len);
//
//    Write(b);
    WriteUniString(FBlock);
  end;
end;

{ TCancelMessage }

constructor TCancelMessage.Create(APieceIndex, AOffset, ASize: Integer);
begin
  inherited Create;
  FPieceIndex := APieceIndex;
  FOffset := AOffset;
  FSize := ASize;
end;

class function TCancelMessage.ClassMessageID: TFixedMessageID;
begin
  Result := idCancel;
end;

function TCancelMessage.GetOffset: Integer;
begin
  Result := FOffset;
end;

function TCancelMessage.GetPieceIndex: Integer;
begin
  Result := FPieceIndex;
end;

function TCancelMessage.GetSize: Integer;
begin
  Result := FSize;
end;

function TCancelMessage.MessageLen: Integer;
begin
  Result := inherited MessageLen;
  Result := Result + FPieceIndex.Size + FOffset.Size + FSize.Size;
end;

procedure TCancelMessage.ReadFromIOHandler(AIOHandler: TIdIOHandler;
  AMsgSize: Integer);
begin
  FPieceIndex := AIOHandler.ReadLongWord;
  FOffset     := AIOHandler.ReadLongWord;
  FSize       := AIOHandler.ReadLongWord;
end;

procedure TCancelMessage.WriteToIOHandler(AIOHandler: TIdIOHandler);
begin
  inherited WriteToIOHandler(AIOHandler);

  AIOHandler.Write(FPieceIndex);
  AIOHandler.Write(FOffset);
  AIOHandler.Write(FSize);
end;

{ TPortMessage }

constructor TPortMessage.Create(APort: TIdPort);
begin
  inherited Create;
  FPort := APort;
end;

class function TPortMessage.ClassMessageID: TFixedMessageID;
begin
  Result := idPort;
end;

function TPortMessage.GetPort: TIdPort;
begin
  Result := FPort;
end;

function TPortMessage.MessageLen: Integer;
begin
  Result := inherited MessageLen;
  Result := Result + FPort.Size;
end;

procedure TPortMessage.ReadFromIOHandler(AIOHandler: TIdIOHandler;
  AMsgSize: Integer);
begin
  Assert(AMsgSize = 2);
  FPort := AIOHandler.ReadWord;
end;

procedure TPortMessage.WriteToIOHandler(AIOHandler: TIdIOHandler);
begin
  inherited WriteToIOHandler(AIOHandler);

  AIOHandler.WriteWord(FPort);
end;

{ THandshakeMessage }

constructor THandshakeMessage.Create(AInfoHash, APeerID: TUniString;
  AEnableDHT, AEnableFastPeer, AEnableExtended: Boolean);
begin
  inherited Create;

  FInfoHash.Assign(AInfoHash);
  FPeerID.Assign(APeerID);

  FFlags.Len := FlagsLen;
  FFlags.FillChar;

  if AEnableDHT then
    FFlags[FlagsLen + OffsetDHT] := FlagDHT or FFlags[FlagsLen + OffsetDHT];

  if AEnableFastPeer then
    FFlags[FlagsLen + OffsetFastPeer] := FlagFastPeer or FFlags[FlagsLen + OffsetFastPeer];

  if AEnableExtended then
    FFlags[FlagsLen + OffsetExtendedMessaging] := FlagExtendedMessaging or FFlags[FlagsLen + OffsetExtendedMessaging];
end;

constructor THandshakeMessage.CreateFromIOHandler(AIOHandler: TIdIOHandler);
begin
  inherited CreateFromIOHandler(AIOHandler, 0);
end;

function THandshakeMessage.GetFlags: TUniString;
begin
  Result := FFlags;
end;

function THandshakeMessage.GetInfoHash: TUniString;
begin
  Result := FInfoHash;
end;

function THandshakeMessage.GetPeerID: TUniString;
begin
  Result := FPeerID;
end;

function THandshakeMessage.GetSupportsDHT: Boolean;
begin
  Result := (FlagDHT and FFlags[FlagsLen + OffsetDHT]) = FlagDHT;
end;

function THandshakeMessage.GetSupportsExtendedMessaging: Boolean;
begin
  Result := (FlagExtendedMessaging and FFlags[FlagsLen + OffsetExtendedMessaging]) = FlagExtendedMessaging;
end;

function THandshakeMessage.GetSupportsFastPeer: Boolean;
begin
  Result := (FlagFastPeer and FFlags[FlagsLen + OffsetFastPeer]) = FlagFastPeer;
end;

procedure THandshakeMessage.ReadFromIOHandler(AIOHandler: TIdIOHandler;
  AMsgSize: Integer);
var
  i: Integer;
  //buf1, buf2, buf3: TIdBytes;
  proto: string;
begin
  with AIOHandler do
  begin
    { проверки правильности заполнения протокола }
    i := ReadByte;
    Assert(i = Length(ProtocolIdentifier));

    proto := ReadString(i);
    Assert(proto = ProtocolIdentifier);

    { достаем данные клиента }
//    ReadBytes(buf1, FlagsLen);
//    FFlags := buf1;
    ReadUniString(FlagsLen, FFlags);

//    ReadBytes(buf2, 20);
//    FInfoHash := buf2;
    ReadUniString(20, FInfoHash);

//    ReadBytes(buf3, 20);
//    FPeerID := buf3;
    ReadUniString(20, FPeerID);
  end;
end;

procedure THandshakeMessage.WriteToIOHandler(AIOHandler: TIdIOHandler);
begin
  with AIOHandler do
  begin
    WriteByte(Length(ProtocolIdentifier));
    WriteString(ProtocolIdentifier);
    WriteUniString(FFlags);
    WriteUniString(FInfoHash);
    WriteUniString(FPeerID);
  end;
end;

{ TFixedMessage }

function TFixedMessage.GetMessageID: TFixedMessageID;
begin
  Result := ClassMessageID;
end;

//function TFixedMessage.GetPayloadSize: Integer;
//begin
//  Result := MessageLen;
//end;

function TFixedMessage.MessageLen: Integer;
begin
  Result := SizeOf(TFixedMessageID) {1};
end;

class function TFixedMessage.ParseMessage(AIOHandler: TIdIOHandler): IMessage;
var
  id: TFixedMessageID;
  msgLen: Cardinal;
  msgClass: TFixedMessagesClass;
begin
  with AIOHandler do
  begin
    msgLen := ReadLongInt; { читаем длину }

    if msgLen > 0 then
    begin
      id := TFixedMessageID(ReadByte); { читаем id сообщения }
      msgClass := nil;

      case id of
        idChoke         : msgClass := TChokeMessage;
        idUnchoke       : msgClass := TUnchokeMessage;
        idInterested    : msgClass := TInterestedMessage;
        idNotInterested : msgClass := TNotInterestedMessage;
        idHave          : msgClass := THaveMessage;
        idBitfield      : msgClass := TBitfieldMessage;
        idRequest       : msgClass := TRequestMessage;
        idPiece         : msgClass := TPieceMessage;
        idCancel        : msgClass := TCancelMessage;
        idPort          : msgClass := TPortMessage;
        idExtended      : msgClass := TExtensionMessage;
      end;

      //DebugOutput('received message ' + msgClass.ClassName);

      Assert(Assigned(msgClass));
      Result := msgClass.CreateFromIOHandler(AIOHandler, msgLen-1) as IMessage; { за вычитом длины идентификатора }
    end else
      Result := TKeepAliveMessage.CreateFromIOHandler(AIOHandler, msgLen) as IMessage;
  end;
end;

procedure TFixedMessage.WriteToIOHandler(AIOHandler: TIdIOHandler);
begin
  with AIOHandler do
  begin
    WriteCardinal(MessageLen);
    WriteByte(Byte(ClassMessageID));
  end;
end;

{ TExtensionMessage }

class function TExtensionMessage.ClassMessageID: TFixedMessageID;
begin
  Result := idExtended;
end;

constructor TExtensionMessage.Create(AMessageID: Byte;
  AExtendedMsgData: TUniString);
begin
  inherited Create;
  FMessageID := AMessageID;
  FMessageData.Assign(AExtendedMsgData);
end;

constructor TExtensionMessage.Create(ASupportsDict: IDictionary<string, Byte>;
  AExtendedMsg: IExtension);
begin
  inherited Create;
  if Supports(AExtendedMsg, IExtensionHandshake) then
    FMessageID := HandshakeMsgID
  else
  begin
    Assert(Assigned(ASupportsDict));
    Assert(ASupportsDict.ContainsKey(AExtendedMsg.SupportName));

    FMessageID := ASupportsDict[AExtendedMsg.SupportName];
  end;
  FExtendedMsg := AExtendedMsg;
end;

function TExtensionMessage.GetExtension: IExtension;
var
  i: Integer;
begin
  if not Assigned(FExtendedMsg) then
  begin
    if FMessageID = HandshakeMsgID then
      FExtendedMsg := TExtensionHandshake.Create(FMessageData)
    else
    for i := 0 to TExtension.SupportsList.Count - 1 do
    begin
      if i + 1 = FMessageID then
        FExtendedMsg := TExtension.SupportsList[i].Value.Create(FMessageData);
    end;
  end;

  Result := FExtendedMsg;
end;

function TExtensionMessage.GetMessageID: Byte;
begin
  Result := FMessageID;
end;

function TExtensionMessage.MessageLen: Integer;
begin
  Result := inherited MessageLen;
  Result := Result + SizeOf(FMessageID) + FExtendedMsg.Size;
end;

procedure TExtensionMessage.ReadFromIOHandler(AIOHandler: TIdIOHandler;
  AMsgSize: Integer);
//var
//  buf: TIdBytes;
begin
  FMessageID := AIOHandler.ReadByte;
//  AIOHandler.ReadBytes(buf, AMsgSize - 1);
//  FMessageData := buf;
  AIOHandler.ReadUniString(AMsgSize - 1, FMessageData);
end;

procedure TExtensionMessage.WriteToIOHandler(AIOHandler: TIdIOHandler);
begin
  inherited WriteToIOHandler(AIOHandler);

  AIOHandler.WriteByte(FMessageID);
  AIOHandler.WriteUniString(FExtendedMsg.Data);
end;

{ TKeepAliveMessage }

function TKeepAliveMessage.GetDummy: TUniString;
begin
  Result := FDmmy;
end;

procedure TKeepAliveMessage.ReadFromIOHandler(AIOHandler: TIdIOHandler;
  AMsgSize: Integer);
//var
//  buf: TIdBytes;
begin
  //AIOHandler.ReadBytes(buf, AMsgSize);
  //FDmmy := buf;
  AIOHandler.ReadUniString(AMsgSize, FDmmy);
end;

procedure TKeepAliveMessage.WriteToIOHandler(AIOHandler: TIdIOHandler);
begin
  { nope }
end;

{ TAtomicMessage }

procedure TAtomicMessage.ReadFromIOHandler(AIOHandler: TIdIOHandler;
  AMsgSize: Integer);
begin
  { dummy }
end;

{ TUnchokeMessage }

class function TUnchokeMessage.ClassMessageID: TFixedMessageID;
begin
  Result := idUnchoke;
end;

{ TInterestedMessage }

class function TInterestedMessage.ClassMessageID: TFixedMessageID;
begin
  Result := idInterested;
end;

{ TNotInterestedMessage }

class function TNotInterestedMessage.ClassMessageID: TFixedMessageID;
begin
  Result := idNotInterested;
end;

end.
