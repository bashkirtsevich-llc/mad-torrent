unit DHT.TokenManager;

interface

uses
  System.SysUtils, System.DateUtils,
  Common,
  Hash,
  DHT.Engine,
  Basic.UniString;

type
  TTokenManager = class(TInterfacedObject, ITokenManager)
  private
    FSecret: TUniString;
    FPreviousSecret: TUniString;
    FLastSecretGeneration: TDateTime;
    FTimeout: TDateTime;
    function GetToken(ANode: INode; s: TUniString): TUniString;
    function GetTimeout: TDateTime; inline;
    procedure SetTimeout(Value: TDateTime); inline;
    function GenerateToken(ANode: INode): TUniString;
    function VerifyToken(ANode: INode; AToken: TUniString): Boolean;
  public
    constructor Create;
  end;

implementation

{ TTokenManager }

constructor TTokenManager.Create;
begin
  FLastSecretGeneration := MinDateTime;

  FSecret.Len := 10; FSecret.FillRandom;
  fpreviousSecret.Len := 10; fpreviousSecret.FillRandom;
end;

function TTokenManager.GenerateToken(ANode: INode): TUniString;
begin
  Result.Len := 0;
  Result := GetToken(anode, fsecret);
end;

function TTokenManager.GetTimeout: TDateTime;
begin
  Result := FTimeout;
end;

function TTokenManager.GetToken(ANode: INode; s: TUniString): TUniString;
var
  n: TUniString;
begin
  if MinutesBetween(UtcNow, FTimeout) > 5 then
  begin
    FLastSecretGeneration := UtcNow;
    FPreviousSecret := FSecret.Copy;
    FSecret.FillRandom;
  end;

  n := ANode.CompactPort;
  Result := SHA1(n);
end;

procedure TTokenManager.SetTimeout(Value: TDateTime);
begin
  FTimeout := Value;
end;

function TTokenManager.VerifyToken(ANode: INode; AToken: TUniString): Boolean;
begin
  Result := (AToken = GetToken(anode, fsecret)) or
            (AToken = GetToken(anode, FPreviousSecret));
end;

end.
