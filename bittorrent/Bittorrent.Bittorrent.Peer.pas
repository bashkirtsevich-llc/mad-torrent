unit Shareman.Bittorrent.Peer;

interface

uses
  System.SysUtils,
  Basic.UniString,
  Common.ThreadPool,
  Shareman, Shareman.Peer, Shareman.Bitfield, Shareman.Bittorrent,
  IdGlobal;

type
  TBTPeer = class(TPeer)
  protected
    procedure DoHandleMessage(AMessage: IMessage); override;

    function GetKeepAliveMsg: IMessage; override;
    function GetInterestedMsg: IMessage; override;
    function GetNotInterestedMsg: IMessage; override;
    function GetChokeMsg: IMessage; override;
    function GetUnchokeMsg: IMessage; override;
    function GetRequestMsg(AIndex, AOffset, ALength: Integer): IMessage; override;
    function GetCancelMsg(AIndex, AOffset, ALength: Integer): IMessage; override;
    function GetHaveMsg(AIndex: Integer): IMessage; override;
    function GetStartMsg(const AUnitHash: TUniString; const ABitfield: TBitField;
      AWantBack: Boolean = True): IMessage; override;
    function GetPieceMsg(APieceIndex, AOffset: Integer; const ABlock,
      AHash: TUniString): IMessage; override;
    function GetInfoMsg(const AUnitHash, AFiles: TUniString): IMessage; override;
    function GetHandShakeMessage(AWantBack: Boolean): IMessage; override;
    procedure HandleHandShakeMessage(AMessage: IMessage); override;
  public
    constructor Create(AThreadPoolEx: TThreadPool; const AHost: string;
      APort: TIdPort; const AInfoHash, AClientID: TUniString;
      AIPVer: TIdIPVersion = Id_IPv4); reintroduce;
  end;

implementation

uses
  Shareman.Bittorrent.Messages, Shareman.Bittorrent.Connection;

{ TBTPeer }

constructor TBTPeer.Create(AThreadPoolEx: TThreadPool; const AHost: string;
  APort: TIdPort; const AInfoHash, AClientID: TUniString; AIPVer: TIdIPVersion);
begin
  // надо предковый конструктор перегрузить, чтобы здесь вызвать только inherited create
  inherited Create(AThreadPoolEx, TBTOutgoingConnection.Create(AHost, APort, AIPVer), AClientID);

  FInfoHash.Assign(AInfoHash);
  FClientID.Assign(AClientID);
end;

procedure TBTPeer.DoHandleMessage(AMessage: IMessage);
begin
  Assert(Supports(AMessage, IBTFixedMessage));

  case (AMessage as IBTFixedMessage).MessageID of
    idChoke         :  { нас зачокали }
      DoChoke;
    idUnchoke       :  { нас расчокали }
      DoUnchoke;
    idInterested    :  { нами заинтересовались }
      DoInterested;
    idNotInterested :  { мы больше не интересны }
      DoNotInterested;
    idHave          :  { подтверждение передачи куска }
      with (AMessage as IBTHaveMessage) do
        DoHave(PieceIndex);
    idBitfield      :  { список кусков, которые он имеет }
      with (AMessage as IBTBitfieldMessage) do
        DoStart(BitField);
    idRequest       :  { с нас запросили куск/блок }
      with (AMessage as IBTRequestMessage) do
        DoRequest(PieceIndex, Offset, Size);
    idPiece         :  { прислали блок/кусок }
      with (AMessage as IBTPieceMessage) do
        DoPiece(PieceIndex, Offset, '', Block);
    idCancel        :  { отменяет свой запрос }
      with (AMessage as IBTCancelMessage) do
        DoCancel(PieceIndex, Offset);
    idPort          : ;{ для ДХТ и чего-то там еще }
    idExtended      : ;
//      with (AMessage as IBTExtensionMessage) do
//        DoExtended(Extension);
  else
    raise Exception.Create('Unknown message');
  end;
end;

function TBTPeer.GetCancelMsg(AIndex, AOffset, ALength: Integer): IMessage;
begin
  Result := TBTCancelMessage.Create(AIndex, AOffset, ALength);
end;

function TBTPeer.GetChokeMsg: IMessage;
begin
  Result := TBTChokeMessage.Create;
end;

function TBTPeer.GetHandShakeMessage(AWantBack: Boolean): IMessage;
begin
  Result := TBTHandshakeMessage.Create(FInfoHash, FOurClientID, False, False, True);
end;

function TBTPeer.GetHaveMsg(AIndex: Integer): IMessage;
begin
  Result := TBTHaveMessage.Create(AIndex);
end;

function TBTPeer.GetInfoMsg(const AUnitHash, AFiles: TUniString): IMessage;
begin
  Result := TBTKeepAliveMessage.Create; // здесь наверное лучше отправить метаданные
end;

function TBTPeer.GetInterestedMsg: IMessage;
begin
  Result := TBTInterestedMessage.Create;
end;

function TBTPeer.GetKeepAliveMsg: IMessage;
begin
  Result := TBTKeepAliveMessage.Create;
end;

function TBTPeer.GetNotInterestedMsg: IMessage;
begin
  Result := TBTNotInterestedMessage.Create;
end;

function TBTPeer.GetPieceMsg(APieceIndex, AOffset: Integer; const ABlock,
  AHash: TUniString): IMessage;
begin
  Result := TBTPieceMessage.Create(APieceIndex, AOffset, ABlock);
end;

function TBTPeer.GetRequestMsg(AIndex, AOffset, ALength: Integer): IMessage;
begin
  Result := TBTRequestMessage.Create(AIndex, AOffset, ALength);
end;

function TBTPeer.GetStartMsg(const AUnitHash: TUniString;
  const ABitfield: TBitField; AWantBack: Boolean): IMessage;
begin
  Result := TBTKeepAliveMessage.Create; // нет понятия "старт-сообщение"
end;

function TBTPeer.GetUnchokeMsg: IMessage;
begin
  Result := TBTUnchokeMessage.Create;
end;

procedure TBTPeer.HandleHandShakeMessage(AMessage: IMessage);
begin
  Assert(Supports(AMessage, IBTHandshakeMessage));
  case FConnection.ConnectionType of
    ctOutgoing: Assert(FInfoHash = (AMessage as IBTHandshakeMessage).InfoHash);
    ctIncoming: FInfoHash.Assign((AMessage as IBTHandshakeMessage).InfoHash);
  end;
end;

end.
