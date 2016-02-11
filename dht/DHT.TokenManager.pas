unit DHT.TokenManager;

interface

uses
  System.SysUtils, System.DateUtils, System.Hash,
  Common.SHA1,
  DHT,
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
begin
  if MinutesBetween(Now, FTimeout) > 5 then
  begin
    FLastSecretGeneration := Now;
    FPreviousSecret := FSecret.Copy;
    FSecret.FillRandom;
  end;

  Result := SHA1(ANode.Host);
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
