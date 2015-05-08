unit magnet_url_parser_u;

interface

uses
  Classes, SysUtils;

const
  SHA_DIGEST_LENGTH = 20;

type
  // нужно создать отдельный модуль с TCharBuffer и функциями для работы с ним
  PCharBuffer = ^TCharBuffer;
  TCharBuffer = array of Char; // ansichar

  TMagnetInfo = class
  private
    FHash: TCharBuffer;
    FDisplayName: string;
    FTrackers: TStrings;
    FWebSeeds: TStrings;

    function GetHash: PCharBuffer;
  public
    property Hash: PCharBuffer read GetHash;
    property DisplayName: string read FDisplayName write FDisplayName;
    property Trackers: TStrings read FTrackers;
    property WebSeeds: TStrings read FWebSeeds;

    constructor Create;
    destructor Destroy; override;
  end;

  TMagnetURLParser = class
  public
    class function ParseText(const AText: string): TMagnetInfo;
  end;

  EMagnetURLParser = class(Exception);

implementation

{ TMagnetInfo }

constructor TMagnetInfo.Create;
begin
  SetLength(FHash, SHA_DIGEST_LENGTH);
  FDisplayName := EmptyStr;
  FTrackers := TStringList.Create;
  FWebSeeds := TStringList.Create;
end;

destructor TMagnetInfo.Destroy;
begin
  SetLength(FHash, 0);
  FTrackers.Free;
  FWebSeeds.Free;
  inherited;
end;

function TMagnetInfo.GetHash: PCharBuffer;
begin
  Result := @FHash;
end;

{ TMagnetURLParser }

class function TMagnetURLParser.ParseText(
  const AText: string): TMagnetInfo;

  procedure HEXToSHA1(const AHash: PCharBuffer; const AHexStr: string);
  var
    i, j: Integer;
    s: string;
  begin
    {if Length(AHexStr) div 2 <> SHA_DIGEST_LENGTH then
      raise EMagnetURLParser.Create('Length of HEX string <> SHA1 hash');}

    j := 0;
    for i := 1 to Length(AHexStr) div 2 do
    begin
      if j > SHA_DIGEST_LENGTH then // на всякий
        Break;

      s := '$'+Copy(AHexStr, i*2-1, 2);

      AHash^[j] := Char(Byte(StrToInt(s)));
      Inc(j);
    end;
  end;

  procedure Base32ToSHA1(const AHash: PCharBuffer; const ABase32Str: string);
  const
    base32Lookup: array[0..79] of Byte = (
      $FF, $FF, $1A, $1B, $1C, $1D, $1E, $1F, (* '0', '1', '2', '3', '4', '5', '6', '7' *)
      $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, (* '8', '9', ':', ';', '<', '=', '>', '?' *)
      $FF, $00, $01, $02, $03, $04, $05, $06, (* '@', 'A', 'B', 'C', 'D', 'E', 'F', 'G' *)
      $07, $08, $09, $0A, $0B, $0C, $0D, $0E, (* 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O' *)
      $0F, $10, $11, $12, $13, $14, $15, $16, (* 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W' *)
      $17, $18, $19, $FF, $FF, $FF, $FF, $FF, (* 'X', 'Y', 'Z', '[', '\', ']', '^', '_' *)
      $FF, $00, $01, $02, $03, $04, $05, $06, (* '`', 'a', 'b', 'c', 'd', 'e', 'f', 'g' *)
      $07, $08, $09, $0A, $0B, $0C, $0D, $0E, (* 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o' *)
      $0F, $10, $11, $12, $13, $14, $15, $16, (* 'p', 'q', 'r', 's', 't', 'u', 'v', 'w' *)
      $17, $18, $19, $FF, $FF, $FF, $FF, $FF  (* 'x', 'y', 'z', '{', '|', '}', '~', 'DEL' *)
    );
  var
    i, index, offset: Integer;
    digit, lookup: Integer;
  begin
    {if Length(ABase32Str) <> 32 then
      raise EMagnetURLParser.Create('Length of base32 string <> SHA1 hash');}

    index := 0;
    offset := 0;
    for i := 1 to Length(ABase32Str) do
    begin
      lookup := Byte(ABase32Str[i]) - Byte('0');

      (* Skip chars outside the lookup table *)
      if (lookup < 0) or (lookup >= Length(base32Lookup)) then
        Continue;

      (* If this digit is not in the table, ignore it *)
      digit := base32Lookup[lookup];
      if digit = $FF then
        Continue;

      if index <= 3 then
      begin
        index := (index + 5) mod 8;

        if index = 0 then
        begin
          AHash^[offset] := Char(Byte(AHash^[offset]) or digit);

          Inc(offset);

          if offset >= SHA_DIGEST_LENGTH then
            Break;
        end else
          AHash^[offset] := Char(Byte(AHash^[offset]) or (digit shl (8 - index)));
      end else
      begin
        index := (index + 5) mod 8;

        AHash^[offset] := Char(Byte(AHash^[offset]) or (digit shr index));

        Inc(offset);

        if offset >= SHA_DIGEST_LENGTH then
          Break;

        AHash^[offset] := Char(Byte(AHash^[offset]) or (digit shl (8 - index)));
      end;
    end;
  end;

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
  Result := nil;

  if AText = EmptyStr then
    Exit;

  try
    Result := TMagnetInfo.Create;

    i   := 1;
    st  := stNone;
    buf := EmptyStr;
    key := EmptyStr;
    val := EmptyStr;
    while (i <= Length(AText)) or (st = stApply) do
    begin
      case st of
        stNone:
          begin
            buf := buf + AText[i];

            if buf = 'magnet:?' then
              st := stReadKey;
          end;

        stReadKey:
          begin
            key := key + AText[i];
            
            if AText[i+1] = '=' then
            begin
              st := stReadValue;
              Inc(i);
            end;
          end;

        stReadValue:
          begin
            val := val + AText[i];

            if (i = Length(AText)) or (AText[i+1] = '&') then
              st := stApply;
          end;

        stApply:
          begin
            if key = 'xt' then
            begin
              if Copy(val, 1, 9) = 'urn:btih:' then
              begin
                Delete(val, 1, 9);

                case Length(val) of
                  40: HEXToSHA1   (Result.Hash, val);
                  32: Base32ToSHA1(Result.Hash, val);
                else
                  raise EMagnetURLParser.Create('Invalid "xt" value length');
                end;
              end else
                raise EMagnetURLParser.Create('Invalid "xt" value format');
            end else
            if key = 'dn' then
              Result.DisplayName := Unescape(val)
            else
            if Copy(key, 1, 2) = 'tr' then
              Result.FTrackers.Add(Unescape(val))
            else
            if key = 'ws' then
              Result.FWebSeeds.Add(Unescape(val));

            buf := EmptyStr;
            key := EmptyStr;
            val := EmptyStr;
            
            st  := stReadKey;
          end;
      end;

      Inc(i);
    end;
  except
    on E: Exception do
    begin
      if Assigned(Result) then
        FreeAndNil(Result);
        
      raise E; // reraise exception
    end;
  end;
end;

end.
