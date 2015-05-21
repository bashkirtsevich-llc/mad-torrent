unit Network.URI;

interface

uses
  IdURI, IdGlobal;

type
  IURI = interface
  ['{2AB2B908-596A-41C5-8CAB-031F253C1AFA}']
    function GetFullURI(const AOptionalFields: TIdURIOptionalFieldsSet = [ofAuthInfo, ofBookmark]): String;
    function GetPathAndParams: String;

    function GetBookmark: string;
    function GetDocument: string;
    function GetHost: string;
    function GetIPVersion: TIdIPVersion;
    function GetParams: string;
    function GetPassword: string;
    function GetPath: string;
    function GetPort: string;
    function GetProtocol: string;
    function GetURI: string;
    function GetUserName: string;
    procedure SetBookMark(const Value: string);
    procedure SetDocument(const Value: string);
    procedure SetHost(const Value: string);
    procedure SetIPVersion(const Value: TIdIPVersion);
    procedure SetParams(const Value: string);
    procedure SetPassword(const Value: string);
    procedure SetPath(const Value: string);
    procedure SetPort(const Value: string);
    procedure SetProtocol(const Value: string);
    procedure SetURI(const Value: string);
    procedure SetUserName(const Value: string);

    property Bookmark: string read GetBookmark write SetBookMark;
    property Document: string read GetDocument write SetDocument;
    property Host: string read GetHost write SetHost;
    property Password: string read GetPassword write SetPassword;
    property Path: string read GetPath write SetPath;
    property Params: string read GetParams write SetParams;
    property Port: string read GetPort write SetPort;
    property Protocol: string read GetProtocol write SetProtocol;
    property URI: string read GetURI write SetURI;
    property Username: string read GetUserName write SetUserName;
    property IPVersion: TIdIPVersion read GetIPVersion write SetIPVersion;
  end;

  TURI = class(TInterfacedObject, IURI)
  private
    FURI: TIdURI;

    function GetFullURI(const AOptionalFields: TIdURIOptionalFieldsSet = [ofAuthInfo, ofBookmark]): String; inline;
    function GetPathAndParams: String; inline;

    function GetBookmark: string; inline;
    function GetDocument: string; inline;
    function GetHost: string; inline;
    function GetIPVersion: TIdIPVersion; inline;
    function GetParams: string; inline;
    function GetPassword: string; inline;
    function GetPath: string; inline;
    function GetPort: string; inline;
    function GetProtocol: string; inline;
    function GetURI: string; inline;
    function GetUserName: string; inline;
    procedure SetBookMark(const Value: string); inline;
    procedure SetDocument(const Value: string); inline;
    procedure SetHost(const Value: string); inline;
    procedure SetIPVersion(const Value: TIdIPVersion); inline;
    procedure SetParams(const Value: string); inline;
    procedure SetPassword(const Value: string); inline;
    procedure SetPath(const Value: string); inline;
    procedure SetPort(const Value: string); inline;
    procedure SetProtocol(const Value: string); inline;
    procedure SetURI(const Value: string); inline;
    procedure SetUserName(const Value: string); inline;
  public
    constructor Create(const AURI: string = '');
    destructor Destroy; override;
  end;

implementation

{ TURI }

constructor TURI.Create(const AURI: string);
begin
  inherited Create;

  FURI := TIdURI.Create(AURI);
end;

destructor TURI.Destroy;
begin
  FURI.Free;
  inherited;
end;

function TURI.GetBookmark: string;
begin
  Result := FURI.Bookmark;
end;

function TURI.GetDocument: string;
begin
  Result := FURI.Document;
end;

function TURI.GetFullURI(
  const AOptionalFields: TIdURIOptionalFieldsSet): String;
begin
  Result := FURI.GetFullURI(AOptionalFields);
end;

function TURI.GetHost: string;
begin
  Result := FURI.Host;
end;

function TURI.GetIPVersion: TIdIPVersion;
begin
  Result := FURI.IPVersion;
end;

function TURI.GetParams: string;
begin
  Result := FURI.Params;
end;

function TURI.GetPassword: string;
begin
  Result := FURI.Password;
end;

function TURI.GetPath: string;
begin
  Result := FURI.Path;
end;

function TURI.GetPathAndParams: String;
begin
  Result := FURI.GetPathAndParams;
end;

function TURI.GetPort: string;
begin
  Result := FURI.Port;
end;

function TURI.GetProtocol: string;
begin
  Result := FURI.Protocol;
end;

function TURI.GetURI: string;
begin
  Result := FURI.URI;
end;

function TURI.GetUserName: string;
begin
  Result := FURI.Username;
end;

procedure TURI.SetBookMark(const Value: string);
begin
  FURI.Bookmark := Value;
end;

procedure TURI.SetDocument(const Value: string);
begin
  FURI.Document := Value;
end;

procedure TURI.SetHost(const Value: string);
begin
  FURI.Host := Value;
end;

procedure TURI.SetIPVersion(const Value: TIdIPVersion);
begin
  FURI.IPVersion := Value;
end;

procedure TURI.SetParams(const Value: string);
begin
  FURI.Params := Value;
end;

procedure TURI.SetPassword(const Value: string);
begin
  FURI.Password := Value;
end;

procedure TURI.SetPath(const Value: string);
begin
  FURI.Path := Value;
end;

procedure TURI.SetPort(const Value: string);
begin
  FURI.Port := Value;
end;

procedure TURI.SetProtocol(const Value: string);
begin
  FURI.Protocol := Value;
end;

procedure TURI.SetURI(const Value: string);
begin
  FURI.URI := Value;
end;

procedure TURI.SetUserName(const Value: string);
begin
  FURI.Username := Value;
end;

end.
