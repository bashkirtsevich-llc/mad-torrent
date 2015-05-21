unit Bittorrent.Tracker.ScrapeParameters;

interface

uses
  Bittorrent,
  Basic.UniString;

type
  TScrapeParameters = class(TInterfacedObject, IScrapeParameters)
  private
    FInfoHash: TUniString;

    function GetInfoHash: TUniString; inline;
  public
    constructor Create(const AInfoHash: TUniString);
  end;

implementation

{ TScrapeParameters }

constructor TScrapeParameters.Create(const AInfoHash: TUniString);
begin
  inherited Create;

  FInfoHash.Assign(AInfoHash);
end;

function TScrapeParameters.GetInfoHash: TUniString;
begin
  Result := FInfoHash;
end;

end.
