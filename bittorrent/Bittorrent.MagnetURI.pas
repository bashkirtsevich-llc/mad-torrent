unit Bittorrent.MagnetURI;

interface

uses
  System.Classes, System.SysUtils,
  Bittorrent,
  Basic.UniString;

type
  TMagnetURI = class(TInterfacedObject, IMagnetURI)
  private
    const
(*  dn (Display Name) — имя файла.
    xl (eXact Length) — размер файла в байтах.
    dl (Display Length) — отображаемый размер в байтах.
    xt (eXact Topic) — URN, содержащий хеш файла.
    as (Acceptable Source) — веб-ссылка на файл в Интернете.
    xs (eXact Source) — P2P ссылка.
    kt (Keyword Topic) — ключевые слова для поиска.
    mt (Manifest Topic) — ссылка на метафайл, который содержит список магнетов (MAGMA).
    tr (TRacker) — адрес трекера для BitTorrent клиентов.
*)
      MagnetPattern   = 'magnet:?';
      DictSeparator   = '&';
      ValSeparator    = '=';

      ExactTopicKey   = 'xt';
      URNBTIHKey      = 'urn:btih:';
      DisplayNameKey  = 'dn';
      TrackerKey      = 'tr';
      WebSeedKey      = 'ws';

      InfoHashHEXLen  = 40;
      InfoHashB32Len  = 32;
  private
    FInfoHash: TUniString;
    FDisplayName: string;
    FTrackers: TStrings;
    FWebSeeds: TStrings;

    function GetInfoHash: TUniString; inline;
    function GetDisplayName: string; inline;
    function GetTrackers: TStrings; inline;
    function GetWebSeeds: TStrings; inline;
  public
    constructor Create(const AMagnetURI: string);
    destructor Destroy; override;
  end;

implementation

{ TMagnetURI }

constructor TMagnetURI.Create(const AMagnetURI: string);

  function Unescape(const AQuotedPrinable: string): string;
  var
    i, j: Integer;
    s: string;
    c: Char;
  begin
    Result := EmptyStr;
    s := EmptyStr;

    j := -1;
    for i := 1 to Length(AQuotedPrinable) do
    begin
      if AQuotedPrinable[i] = '%' then
      begin
        j := 0;
        s := '$';

        Continue;
      end;

      if j >= 0 then
      begin
        s := s + AQuotedPrinable[i];
        if j = 1 then
        begin
          c := Char(Byte(StrToInt(s))); // чтоб исключение происходило, если там кривое число

          if c <> #0 then
            Result := Result + c;

          j := -1;
        end else
          Inc(j);
      end else
        Result := Result + AQuotedPrinable[i];
    end;
  end;

type
  TState = (stNone, stReadKey, stReadValue, stApply);
var
  i: Integer;
  st: TState;
  buf, key, val: string;
begin
  inherited Create;

  Assert(not AMagnetURI.IsEmpty);

  FTrackers := TStringList.Create;
  FWebSeeds := TStringList.Create;

  i   := 1;
  st  := stNone;
  buf := string.Empty;
  key := string.Empty;
  val := string.Empty;

  while (i <= AMagnetURI.Length) or (st = stApply) do
  begin
    case st of
      stNone:
        begin
          buf := buf + AMagnetURI[i];

          if buf = MagnetPattern then
            st := stReadKey;
        end;

      stReadKey:
        begin
          if AMagnetURI[i] = ValSeparator then
            st := stReadValue
          else
            key := key + AMagnetURI[i];
        end;

      stReadValue:
        begin
          if (i = AMagnetURI.Length) or (AMagnetURI[i] = DictSeparator) then
            st := stApply
          else
            val := val + AMagnetURI[i];
        end;

      stApply:
        begin
          if key = ExactTopicKey then
          begin
            if Copy(val, 1, 9) = URNBTIHKey then
            begin
              Delete(val, 1, 9);

              case val.Length of
                InfoHashHEXLen: FInfoHash := HexToUnistring(val);
                InfoHashB32Len: FInfoHash := Base32ToUniString(val);
              else
                raise Exception.CreateFmt('Invalid "%s" value length', [ExactTopicKey]);
              end;
            end else
              raise Exception.CreateFmt('Invalid "%s" value format', [ExactTopicKey]);
          end else
          if key = DisplayNameKey then
            FDisplayName := Unescape(val)
          else
          if key = TrackerKey then
            FTrackers.Add(Unescape(val))
          else
          if key = WebSeedKey then
            FWebSeeds.Add(Unescape(val));

          buf := string.Empty;
          key := string.Empty;
          val := string.Empty;

          st  := stReadKey;

          Continue;
        end;
    end;

    Inc(i);
  end;
end;

destructor TMagnetURI.Destroy;
begin
  FTrackers.Free;
  FWebSeeds.Free;
  inherited;
end;

function TMagnetURI.GetDisplayName: string;
begin
  Result := FDisplayName;
end;

function TMagnetURI.GetInfoHash: TUniString;
begin
  Result := FInfoHash;
end;

function TMagnetURI.GetTrackers: TStrings;
begin
  Result := FTrackers;
end;

function TMagnetURI.GetWebSeeds: TStrings;
begin
  Result := FWebSeeds;
end;

end.
