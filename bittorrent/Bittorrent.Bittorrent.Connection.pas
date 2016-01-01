unit Shareman.Bittorrent.Connection;

interface

uses
  System.SysUtils,
  Shareman, Shareman.Connection, Shareman.Bittorrent.Messages,
  IdIOHandler;

type
  TBTOutgoingConnection = class(TOutgoingConnection)
  strict protected
    function ParseMessage(AIOHandler: TIdIOHandler;
      AHandshake: Boolean): IMessage; override; final;
  end;

implementation

{ TBTOutgoingConnection }

function TBTOutgoingConnection.ParseMessage(AIOHandler: TIdIOHandler;
  AHandshake: Boolean): IMessage;
begin
  Result := TBTFixedMessage.ParseMessage(AIOHandler, AHandshake);
end;

end.
