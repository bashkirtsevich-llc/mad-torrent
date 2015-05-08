unit Bittorrent.Server;

interface

uses
  System.SysUtils,
  IdCustomTCPServer, IdContext, IdGlobal;

type
  TTCPServer = class(TIdCustomTCPServer)
  private
  protected
    procedure CheckOkToBeActive; override;
    function DoExecute(AContext: TIdContext): Boolean; override;
  published
    property OnExecute;
  public
    constructor Create(AListenPort: TIdPort); reintroduce;
    destructor Destroy; override;
  end;

implementation

{ TTCPServer }

procedure TTCPServer.CheckOkToBeActive;
begin
  inherited;
  Assert(Assigned(OnExecute));
  { scheck something else }
end;

constructor TTCPServer.Create(AListenPort: TIdPort);
begin
  inherited Create(nil);

  DefaultPort := AListenPort;
end;

destructor TTCPServer.Destroy;
begin
  TerminateAllThreads;
  inherited;
end;

function TTCPServer.DoExecute(AContext: TIdContext): Boolean;
begin
  if Assigned(OnExecute) then
    OnExecute(AContext);

  { крутим поток, пока есть соединение }
  while FActive and
        Assigned(AContext) and
        Assigned(AContext.Connection) and
        AContext.Connection.Connected do
    Sleep(100);

  Result := False;
end;

end.
