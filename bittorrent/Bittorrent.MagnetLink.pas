unit Bittorrent.MagnetLink;

interface

uses
  System.Classes, System.SysUtils, System.Generics.Collections,
  Basic.UniString,
  Bittorrent,
  IdURI;

type
  TMagnetLink = class(TInterfacedObject, IMagnetLink)
  private
    FInfoHash: TUniString;
    FTrackers: TList<string>;
    FDisplayName: string;
    function GetInfoHash: TUniString; inline;
    function GetDisplayName: string; inline;
    function GetTrackers: TEnumerable<string>; inline;
    function GetTrackersCount: Integer; inline;

    procedure ParseMagnetLink(const AURL: string);
  public
    constructor Create(const AURL: string); reintroduce;
    destructor Destroy; override;
  end;

implementation

{ TMagnetLink }

constructor TMagnetLink.Create(const AURL: string);
begin
  inherited Create;

  FInfoHash.Len := 0;
  FTrackers     := TList<string>.Create;
  FDisplayName  := string.Empty;

  ParseMagnetLink(AURL);
end;

destructor TMagnetLink.Destroy;
begin
  FTrackers.Free;
  inherited;
end;

function TMagnetLink.GetDisplayName: string;
begin
  Result := FDisplayName;
end;

function TMagnetLink.GetInfoHash: TUniString;
begin
  Result := FInfoHash;
end;

function TMagnetLink.GetTrackers: TEnumerable<string>;
begin
  Result := FTrackers;
end;

function TMagnetLink.GetTrackersCount: Integer;
begin
  Result := FTrackers.Count;
end;

procedure TMagnetLink.ParseMagnetLink(const AURL: string);

  procedure ParseValues(const AKey, AValue: string);

    function ParseInfoHash(const AVal: string): TUniString; inline;
    var
      s1, s2: string;
    begin
      s1 := aval.Substring(0, 9);
      s2 := aval.Substring(9);

      Assert({(s1 = 'urn:sha1:') or} (s1 = 'urn:btih:'));

      Assert(s2.Length {in [32, 40]} = 40);

      Result := HexToUnistring(s2);
    end;

  var
    tr: string;
  begin
    if AKey = 'xt' then // exact topic
    begin
      Assert(FInfoHash.Empty);
      FInfoHash.Assign(ParseInfoHash(AValue));
    end else
    if AKey = 'tr' then // address tracker
    begin
      tr := TIdURI.URLDecode(AValue);

      if not FTrackers.Contains(tr) then
        FTrackers.Add(tr);
    end else
    if AKey = 'dn' then // display name
      FDisplayName := TIdURI.URLDecode(AValue.Replace('+', ' '));
    {
    "as": // Acceptable Source
    "xl": // exact length
    "xs": // eXact Source - P2P link.
    "kt": // keyword topic
    "mt": // manifest topic
    }
  end;

var
  splitStr, keyval: TArray<string>;
  param: string;
begin
  splitStr := AURL.Split(['?']);

  Assert((Length(splitStr) > 0) and (splitStr[0].ToLower = 'magnet:'));

  if Length(splitStr) > 1 then
  begin
    for param in splitStr[1].Split(['&', ';']) do
    begin
      keyval := param.Split(['=']);

      Assert((Length(keyval) = 2) and (Length(keyval[0]) = 2));

      ParseValues(keyval[0].ToLower, keyval[1]);
    end;
  end;
end;

end.
