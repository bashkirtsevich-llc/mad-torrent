unit UDP.Server;

interface

uses
  System.Classes, System.SysUtils, System.StrUtils, System.Generics.Collections,
  Basic.UniString,
  IdUDPServer, IdGlobal, IdSocketHandle;

type
  TUDPListener = class(TIdUDPServer)
  private
    FOnReceive: TProc<string, TIdPort, TUniString>;
  protected
    procedure DoUDPRead(AThread: TIdUDPListenerThread; const AData: TIdBytes;
      ABinding: TIdSocketHandle); override;
  public
    procedure SendUniString(const AHost: string; const APort: TIdPort;
      const AIPVersion: TIdIPVersion; const AData: TUniString); overload;
    procedure SendUniString(const AHost: string; const APort: TIdPort;
      const AData: TUniString); overload;

    property OnReceive: TProc<string, TIdPort, TUniString> read FOnReceive write FOnReceive;

    constructor Create(AListenPort: TIdPort);
  end;

implementation

{ TUDPListener }

procedure TUDPListener.SendUniString(const AHost: string; const APort: TIdPort;
  const AIPVersion: TIdIPVersion; const AData: TUniString);
var
  data: TIdBytes;
begin
  SetLength(data, AData.Len);
  Move(AData.DataPtr[0]^, data[0], AData.Len);

  SendBuffer(AHost, APort, AIPVersion, data);
end;

constructor TUDPListener.Create(AListenPort: TIdPort);
begin
  inherited Create(nil);

  DefaultPort := AListenPort;
  Active      := True;
end;

procedure TUDPListener.DoUDPRead(AThread: TIdUDPListenerThread;
  const AData: TIdBytes; ABinding: TIdSocketHandle);
begin
  if Assigned(FOnReceive) then
    FOnReceive(ABinding.PeerIP, ABinding.PeerPort, AData);
end;

procedure TUDPListener.SendUniString(const AHost: string; const APort: TIdPort;
  const AData: TUniString);
begin
  SendUniString(AHost, APort, IPVersion, AData);
end;

end.

