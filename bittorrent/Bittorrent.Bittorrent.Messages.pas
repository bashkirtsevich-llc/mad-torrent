unit Shareman.Bittorrent.Messages;

interface

uses
  System.SysUtils,
  System.Generics.Defaults,
  Spring.Collections,
  Hash,
  Basic.UniString,
  Shareman.Messages, Shareman.Bittorrent, Shareman.Bitfield,
  IdIOHandler, IdIOHandlerHelper, IdGlobal;

type
  TBTMessage = class abstract(TMessage, IBTMessage)
  protected
    procedure ReadFromIOHandler(AIOHandler: TIdIOHandler; AMsgSize: Integer); reintroduce; virtual; abstract;
    constructor CreateFromIOHandler(AIOHandler: TIdIOHandler; AMsgSize: Integer); reintroduce;
  end;

  TFixedMessagesClass = class of TBTFixedMessage;

  TBTFixedMessage = class abstract(TBTMessage, IBTFixedMessage)
  private
    function GetMessageID: TBTMessageID; inline;
  protected
    function GetMsgSize: Integer; override;
    function MessageLen: Integer; virtual;
    procedure WriteToIOHandler(AIOHandler: TIdIOHandler); override;
  protected
    class function ClassMessageID: TBTMessageID; virtual; abstract;
  public
    class function ParseMessage(AIOHandler: TIdIOHandler;
      AHandshake: Boolean): IBTMessage; static;
  end;

  { класс-затычка, перекрывающая абстрактный метод ReadFromIOHandler }
  TBTAtomicMessage = class abstract(TBTFixedMessage)
  protected
    procedure ReadFromIOHandler(AIOHandler: TIdIOHandler; AMsgSize: Integer); override;
  end;

  TBTChokeMessage = class(TBTAtomicMessage, IBTChokeMessage)
  protected
    class function ClassMessageID: TBTMessageID; override;
  end;

  TBTUnchokeMessage = class(TBTAtomicMessage, IBTUnchokeMessage)
  protected
    class function ClassMessageID: TBTMessageID; override;
  end;

  TBTInterestedMessage = class(TBTAtomicMessage, IBTInterestedMessage)
  protected
    class function ClassMessageID: TBTMessageID; override;
  end;

  TBTNotInterestedMessage = class(TBTAtomicMessage, IBTNotInterestedMessage)
  protected
    class function ClassMessageID: TBTMessageID; override;
  end;

  TBTHaveMessage = class(TBTFixedMessage, IBTHaveMessage)
  private
    FPieceIndex: Integer;
    function GetPieceIndex: Integer; inline;
  protected
    function MessageLen: Integer; override;
    procedure ReadFromIOHandler(AIOHandler: TIdIOHandler; AMsgSize: Integer); override;
    procedure WriteToIOHandler(AIOHandler: TIdIOHandler); override;
  protected
    class function ClassMessageID: TBTMessageID; override;
  public
    constructor Create(APieceIndex: Integer);
  end;

  TBTBitfieldMessage = class(TBTFixedMessage, IBTBitfieldMessage)
  private
    FBitfield: TBitField;
    function GetBitField: TBitField; inline;
  protected
    function MessageLen: Integer; override;
    procedure ReadFromIOHandler(AIOHandler: TIdIOHandler; AMsgSize: Integer); override;
    procedure WriteToIOHandler(AIOHandler: TIdIOHandler); override;
  protected
    class function ClassMessageID: TBTMessageID; override;
  public
    constructor Create(const ABits: TBitField);
  end;

  TBTRequestMessage = class(TBTFixedMessage, IBTRequestMessage)
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
    class function ClassMessageID: TBTMessageID; override;
  public
    constructor Create(APieceIndex, AOffset, ASize: Integer);
  end;

  TBTPieceMessage = class(TBTFixedMessage, IBTPieceMessage)
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
    class function ClassMessageID: TBTMessageID; override;
  public
    constructor Create(APieceIndex, AOffset: Integer; ABlock: TUniString);
  end;

  TBTCancelMessage = class(TBTFixedMessage, IBTCancelMessage)
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
    class function ClassMessageID: TBTMessageID; override;
  public
    constructor Create(APieceIndex, AOffset, ASize: Integer);
  end;

  TBTPortMessage = class(TBTFixedMessage, IBTPortMessage)
  private
    FPort: TIdPort;
    function GetPort: TIdPort; inline;
  protected
    function MessageLen: Integer; override;
    procedure ReadFromIOHandler(AIOHandler: TIdIOHandler; AMsgSize: Integer); override;
    procedure WriteToIOHandler(AIOHandler: TIdIOHandler); override;
  protected
    class function ClassMessageID: TBTMessageID; override;
  public
    constructor Create(APort: TIdPort);
  end;

  TBTExtensionMessage = class(TBTFixedMessage, IBTExtensionMessage)
  public
    const
      HandshakeMsgID = 0;
  protected
    FMessageID: Byte;
    FMessageData: TUniString;
    FExtendedMsg: IBTExtension;
    function GetExtension: IBTExtension;
    function GetMessageID: Byte; inline;
  protected
    function MessageLen: Integer; override;
    procedure ReadFromIOHandler(AIOHandler: TIdIOHandler; AMsgSize: Integer); override;
    procedure WriteToIOHandler(AIOHandler: TIdIOHandler); override;
  protected
    class function ClassMessageID: TBTMessageID; override;
  public
    constructor Create(AMessageID: Byte; AExtendedMsgData: TUniString); overload;
    constructor Create(ASupportsDict: IDictionary<string, Byte>; AExtendedMsg: IBTExtension); overload;
  end;

  TBTKeepAliveMessage = class(TBTMessage, IBTKeepAliveMessage)
  private
    FDmmy: TUniString;
    function GetDummy: TUniString; inline;
  protected
    function GetMsgSize: Integer; override;
    procedure ReadFromIOHandler(AIOHandler: TIdIOHandler; AMsgSize: Integer); override;
    procedure WriteToIOHandler(AIOHandler: TIdIOHandler); override;
  end;

  TBTHandshakeMessage = class(TBTMessage, IBTHandshakeMessage)
  private
    const
      ProtocolIdentifier = 'BitTorrent protocol';
      PeerIDLen = 20;
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
    function GetMsgSize: Integer; override;
    procedure ReadFromIOHandler(AIOHandler: TIdIOHandler; AMsgSize: Integer); override;
    procedure WriteToIOHandler(AIOHandler: TIdIOHandler); override;
  public
    constructor Create(AInfoHash, APeerID: TUniString;
      AEnableDHT, AEnableFastPeer, AEnableExtended: Boolean);
    constructor CreateFromIOHandler(AIOHandler: TIdIOHandler); reintroduce;
  end;

implementation

uses
  Shareman.Bittorrent.Extensions;

{ TBTMessage }

constructor TBTMessage.CreateFromIOHandler(AIOHandler: TIdIOHandler;
  AMsgSize: Integer);
begin
  inherited Create;

  ReadFromIOHandler(AIOHandler, AMsgSize);
end;

{ TBTChokeMessage }

class function TBTChokeMessage.ClassMessageID: TBTMessageID;
begin
  Result := idChoke;
end;

{ TBTHaveMessage }

constructor TBTHaveMessage.Create(APieceIndex: Integer);
begin
  inherited Create;
  FPieceIndex := APieceIndex;
end;

class function TBTHaveMessage.ClassMessageID: TBTMessageID;
begin
  Result := idHave;
end;

function TBTHaveMessage.GetPieceIndex: Integer;
begin
  Result := FPieceIndex;
end;

function TBTHaveMessage.MessageLen: Integer;
begin
  Result := (inherited MessageLen) + FPieceIndex.Size;
end;

procedure TBTHaveMessage.ReadFromIOHandler(AIOHandler: TIdIOHandler;
  AMsgSize: Integer);
begin
  Assert(AMsgSize = 4);
  FPieceIndex := AIOHandler.ReadLongWord;
end;

procedure TBTHaveMessage.WriteToIOHandler(AIOHandler: TIdIOHandler);
begin
  inherited WriteToIOHandler(AIOHandler);
  AIOHandler.Write(FPieceIndex);
end;

{ TBTBitfieldMessage }

class function TBTBitfieldMessage.ClassMessageID: TBTMessageID;
begin
  Result := idBitfield;
end;

constructor TBTBitfieldMessage.Create(const ABits: TBitField);
begin
  inherited Create;
  FBitfield := ABits;
end;

function TBTBitfieldMessage.GetBitField: TBitField;
begin
  Result := FBitfield;
end;

function TBTBitfieldMessage.MessageLen: Integer;
begin
  Result := (inherited MessageLen) + FBitfield.LengthInBytes;
end;

procedure TBTBitfieldMessage.ReadFromIOHandler(AIOHandler: TIdIOHandler;
  AMsgSize: Integer);
var
  buf: TUniString;
begin
  //AIOHandler.ReadBytes(buf, AMsgSize);
  //FBitfield := FBitfield.FromUniString(buf);
  AIOHandler.ReadUniString(AMsgSize, buf);
  FBitfield := FBitfield.FromUniString(buf);
end;

procedure TBTBitfieldMessage.WriteToIOHandler(AIOHandler: TIdIOHandler);
begin
  inherited WriteToIOHandler(AIOHandler);
  AIOHandler.WriteUniString(FBitfield.AsUniString);
end;

{ TBTRequestMessage }

constructor TBTRequestMessage.Create(APieceIndex, AOffset, ASize: Integer);
begin
  inherited Create;

  FPieceIndex := APieceIndex;
  FOffset := AOffset;
  FSize := ASize;
end;

class function TBTRequestMessage.ClassMessageID: TBTMessageID;
begin
  Result := idRequest;
end;

function TBTRequestMessage.GetOffset: Integer;
begin
  Result := FOffset;
end;

function TBTRequestMessage.GetPieceIndex: Integer;
begin
  Result := FPieceIndex;
end;

function TBTRequestMessage.GetSize: Integer;
begin
  Result := FSize;
end;

function TBTRequestMessage.MessageLen: Integer;
begin
  Result := (inherited MessageLen) + FPieceIndex.Size + FOffset.Size + FSize.Size;
end;

procedure TBTRequestMessage.ReadFromIOHandler(AIOHandler: TIdIOHandler;
  AMsgSize: Integer);
begin
  with AIOHandler do
  begin
    FPieceIndex := ReadLongInt;
    FOffset     := ReadLongInt;
    FSize       := ReadLongInt;
  end;
end;

procedure TBTRequestMessage.WriteToIOHandler(AIOHandler: TIdIOHandler);
begin
  inherited WriteToIOHandler(AIOHandler);

//  DebugOutput(PChar('отправлен запрос куска #'+FPieceIndex.ToString));
  AIOHandler.Write(FPieceIndex);
  AIOHandler.Write(FOffset);
  AIOHandler.Write(FSize);
end;

{ TBTPieceMessage }

constructor TBTPieceMessage.Create(APieceIndex, AOffset: Integer;
  ABlock: TUniString);
begin
  inherited Create;
  FPieceIndex := APieceIndex;
  FOffset := AOffset;
  FBlock.Assign(ABlock);
end;

class function TBTPieceMessage.ClassMessageID: TBTMessageID;
begin
  Result := idPiece;
end;

function TBTPieceMessage.GetBlock: TUniString;
begin
  Result := FBlock;
end;

function TBTPieceMessage.GetOffset: Integer;
begin
  Result := FOffset;
end;

function TBTPieceMessage.GetPieceIndex: Integer;
begin
  Result := FPieceIndex;
end;

function TBTPieceMessage.MessageLen: Integer;
begin
  Result := (inherited MessageLen) + FPieceIndex.Size + FOffset.Size + FBlock.Len;
end;

procedure TBTPieceMessage.ReadFromIOHandler(AIOHandler: TIdIOHandler;
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

procedure TBTPieceMessage.WriteToIOHandler(AIOHandler: TIdIOHandler);
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

{ TBTCancelMessage }

constructor TBTCancelMessage.Create(APieceIndex, AOffset, ASize: Integer);
begin
  inherited Create;
  FPieceIndex := APieceIndex;
  FOffset := AOffset;
  FSize := ASize;
end;

class function TBTCancelMessage.ClassMessageID: TBTMessageID;
begin
  Result := idCancel;
end;

function TBTCancelMessage.GetOffset: Integer;
begin
  Result := FOffset;
end;

function TBTCancelMessage.GetPieceIndex: Integer;
begin
  Result := FPieceIndex;
end;

function TBTCancelMessage.GetSize: Integer;
begin
  Result := FSize;
end;

function TBTCancelMessage.MessageLen: Integer;
begin
  Result := (inherited MessageLen) + FPieceIndex.Size + FOffset.Size + FSize.Size;
end;

procedure TBTCancelMessage.ReadFromIOHandler(AIOHandler: TIdIOHandler;
  AMsgSize: Integer);
begin
  FPieceIndex := AIOHandler.ReadLongWord;
  FOffset     := AIOHandler.ReadLongWord;
  FSize       := AIOHandler.ReadLongWord;
end;

procedure TBTCancelMessage.WriteToIOHandler(AIOHandler: TIdIOHandler);
begin
  inherited WriteToIOHandler(AIOHandler);

  AIOHandler.Write(FPieceIndex);
  AIOHandler.Write(FOffset);
  AIOHandler.Write(FSize);
end;

{ TBTPortMessage }

constructor TBTPortMessage.Create(APort: TIdPort);
begin
  inherited Create;
  FPort := APort;
end;

class function TBTPortMessage.ClassMessageID: TBTMessageID;
begin
  Result := idPort;
end;

function TBTPortMessage.GetPort: TIdPort;
begin
  Result := FPort;
end;

function TBTPortMessage.MessageLen: Integer;
begin
  Result := (inherited MessageLen) + FPort.Size;
end;

procedure TBTPortMessage.ReadFromIOHandler(AIOHandler: TIdIOHandler;
  AMsgSize: Integer);
begin
  Assert(AMsgSize = 2);
  FPort := AIOHandler.ReadWord;
end;

procedure TBTPortMessage.WriteToIOHandler(AIOHandler: TIdIOHandler);
begin
  inherited WriteToIOHandler(AIOHandler);

  AIOHandler.WriteWord(FPort);
end;

{ TBTHandshakeMessage }

constructor TBTHandshakeMessage.Create(AInfoHash, APeerID: TUniString;
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

constructor TBTHandshakeMessage.CreateFromIOHandler(AIOHandler: TIdIOHandler);
begin
  inherited CreateFromIOHandler(AIOHandler, 0);
end;

function TBTHandshakeMessage.GetFlags: TUniString;
begin
  Result := FFlags;
end;

function TBTHandshakeMessage.GetInfoHash: TUniString;
begin
  Result := FInfoHash;
end;

function TBTHandshakeMessage.GetMsgSize: Integer;
begin
  Result :=
    Byte.Size +
    ProtocolIdentifier.Length +
    FFlags.Len +
    FInfoHash.Len +
    FPeerID.Len;
end;

function TBTHandshakeMessage.GetPeerID: TUniString;
begin
  Result := FPeerID;
end;

function TBTHandshakeMessage.GetSupportsDHT: Boolean;
begin
  Result := (FlagDHT and FFlags[FlagsLen + OffsetDHT]) = FlagDHT;
end;

function TBTHandshakeMessage.GetSupportsExtendedMessaging: Boolean;
begin
  Result := (FlagExtendedMessaging and FFlags[FlagsLen + OffsetExtendedMessaging]) = FlagExtendedMessaging;
end;

function TBTHandshakeMessage.GetSupportsFastPeer: Boolean;
begin
  Result := (FlagFastPeer and FFlags[FlagsLen + OffsetFastPeer]) = FlagFastPeer;
end;

procedure TBTHandshakeMessage.ReadFromIOHandler(AIOHandler: TIdIOHandler;
  AMsgSize: Integer);
var
  i: Integer;
  proto: string;
begin
  with AIOHandler do
  begin
    { проверки правильности заполнения протокола }
    i := ReadByte;
    Assert(i = ProtocolIdentifier.Length);

    proto := ReadString(i);
    Assert(proto = ProtocolIdentifier);
    { достаем данные клиента }
    ReadUniString(FlagsLen, FFlags);
    ReadUniString(SHA1HashLen, FInfoHash);
    ReadUniString(PeerIDLen, FPeerID);
  end;
end;

procedure TBTHandshakeMessage.WriteToIOHandler(AIOHandler: TIdIOHandler);
begin
  with AIOHandler do
  begin
    WriteByte(ProtocolIdentifier.Length);
    WriteString(ProtocolIdentifier);
    WriteUniString(FFlags);
    WriteUniString(FInfoHash);
    WriteUniString(FPeerID);
  end;
end;

{ TBTFixedMessage }

function TBTFixedMessage.GetMessageID: TBTMessageID;
begin
  Result := ClassMessageID;
end;

function TBTFixedMessage.GetMsgSize: Integer;
begin
  Result := MessageLen;
end;

function TBTFixedMessage.MessageLen: Integer;
begin
  Result := SizeOf(TBTMessageID) {1};
end;

class function TBTFixedMessage.ParseMessage(AIOHandler: TIdIOHandler;
  AHandshake: Boolean): IBTMessage;
var
  id: TBTMessageID;
  msgLen: Cardinal;
  msgClass: TFixedMessagesClass;
begin
  if AHandshake then
    Result := TBTHandshakeMessage.CreateFromIOHandler(AIOHandler)
  else
  with AIOHandler do
  begin
    msgLen := ReadLongInt; { читаем длину }

    if msgLen > 0 then
    begin
      id := TBTMessageID(ReadByte); { читаем id сообщения }

      case id of
        idChoke         : msgClass := TBTChokeMessage;
        idUnchoke       : msgClass := TBTUnchokeMessage;
        idInterested    : msgClass := TBTInterestedMessage;
        idNotInterested : msgClass := TBTNotInterestedMessage;
        idHave          : msgClass := TBTHaveMessage;
        idBitfield      : msgClass := TBTBitfieldMessage;
        idRequest       : msgClass := TBTRequestMessage;
        idPiece         : msgClass := TBTPieceMessage;
        idCancel        : msgClass := TBTCancelMessage;
        idPort          : msgClass := TBTPortMessage;
        idExtended      : msgClass := TBTExtensionMessage;
      else
                          msgClass := nil;
      end;

      Assert(Assigned(msgClass));
      Result := msgClass.CreateFromIOHandler(AIOHandler, msgLen-1) as IBTMessage; { за вычитом длины идентификатора }
    end else
      Result := TBTKeepAliveMessage.CreateFromIOHandler(AIOHandler, msgLen) as IBTMessage;
  end;
end;

procedure TBTFixedMessage.WriteToIOHandler(AIOHandler: TIdIOHandler);
begin
  with AIOHandler do
  begin
    WriteCardinal(MessageLen);
    WriteByte(Byte(ClassMessageID));
  end;
end;

{ TBTExtensionMessage }

class function TBTExtensionMessage.ClassMessageID: TBTMessageID;
begin
  Result := idExtended;
end;

constructor TBTExtensionMessage.Create(AMessageID: Byte;
  AExtendedMsgData: TUniString);
begin
  inherited Create;
  FMessageID := AMessageID;
  FMessageData.Assign(AExtendedMsgData);
end;

constructor TBTExtensionMessage.Create(ASupportsDict: IDictionary<string, Byte>;
  AExtendedMsg: IBTExtension);
begin
  inherited Create;
  if Supports(AExtendedMsg, IBTExtensionHandshake) then
    FMessageID := HandshakeMsgID
  else
  begin
    Assert(Assigned(ASupportsDict));
    Assert(ASupportsDict.ContainsKey(AExtendedMsg.SupportName));

    FMessageID := ASupportsDict[AExtendedMsg.SupportName];
  end;
  FExtendedMsg := AExtendedMsg;
end;

function TBTExtensionMessage.GetExtension: IBTExtension;
var
  i: Integer;
begin
  if not Assigned(FExtendedMsg) then
  begin
    if FMessageID = HandshakeMsgID then
      FExtendedMsg := TBTExtensionHandshake.Create(FMessageData)
    else
    for i := 0 to TBTExtension.SupportsList.Count - 1 do
    begin
      if i + 1 = FMessageID then
        FExtendedMsg := TBTExtension.SupportsList[i].Value.Create(FMessageData);
    end;
  end;

  Result := FExtendedMsg;
end;

function TBTExtensionMessage.GetMessageID: Byte;
begin
  Result := FMessageID;
end;

function TBTExtensionMessage.MessageLen: Integer;
begin
  Result := (inherited MessageLen) + SizeOf(FMessageID) + GetExtension.Size;
end;

procedure TBTExtensionMessage.ReadFromIOHandler(AIOHandler: TIdIOHandler;
  AMsgSize: Integer);
begin
  FMessageID := AIOHandler.ReadByte;
  AIOHandler.ReadUniString(AMsgSize - 1, FMessageData);
end;

procedure TBTExtensionMessage.WriteToIOHandler(AIOHandler: TIdIOHandler);
begin
  inherited WriteToIOHandler(AIOHandler);

  AIOHandler.WriteByte(FMessageID);
  AIOHandler.WriteUniString(FExtendedMsg.Data);
end;

{ TBTKeepAliveMessage }

function TBTKeepAliveMessage.GetDummy: TUniString;
begin
  Result := FDmmy;
end;

function TBTKeepAliveMessage.GetMsgSize: Integer;
begin
  Result := Byte.Size;
end;

procedure TBTKeepAliveMessage.ReadFromIOHandler(AIOHandler: TIdIOHandler;
  AMsgSize: Integer);
//var
//  buf: TIdBytes;
begin
  //AIOHandler.ReadBytes(buf, AMsgSize);
  //FDmmy := buf;
  AIOHandler.ReadUniString(AMsgSize, FDmmy);
end;

procedure TBTKeepAliveMessage.WriteToIOHandler(AIOHandler: TIdIOHandler);
begin
  { nope }
end;

{ TBTAtomicMessage }

procedure TBTAtomicMessage.ReadFromIOHandler(AIOHandler: TIdIOHandler;
  AMsgSize: Integer);
begin
  { dummy }
end;

{ TBTUnchokeMessage }

class function TBTUnchokeMessage.ClassMessageID: TBTMessageID;
begin
  Result := idUnchoke;
end;

{ TBTInterestedMessage }

class function TBTInterestedMessage.ClassMessageID: TBTMessageID;
begin
  Result := idInterested;
end;

{ TBTNotInterestedMessage }

class function TBTNotInterestedMessage.ClassMessageID: TBTMessageID;
begin
  Result := idNotInterested;
end;

end.
