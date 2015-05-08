unit Utils;

interface

uses
  Winapi.Windows,
  System.SysUtils, System.DateUtils,
  Hash.SHA1, Basic.UniString;

function SHA1DigestToUniString(const ADigest: TSHA1Digest): TUniString;
function SHA1(AData: Pointer; ALength: Integer): TUniString; overload;
function SHA1(const Value: TUniString): TUniString; overload;
function UtcNow: TDateTime;

implementation

function SHA1DigestToUniString(const ADigest: TSHA1Digest): TUniString;
var
  i: Integer;
begin
  Result.Len := SizeOf(TSHA1Digest);

  for i := 0 to SizeOf(TSHA1Digest) do
    Result[i] := ADigest[i];
end;

function SHA1(AData: Pointer; ALength: Integer): TUniString; overload;
var
  digest: TSHA1Digest;
  ctx: TSHA1Context;
begin
  Result.Len := 0;

  SHA1Init(ctx);
  SHA1Update(ctx, AData^, ALength);
  digest := SHA1Final(ctx);

  Result := SHA1DigestToUniString(digest);
end;

function SHA1(const Value: TUniString): TUniString; overload;
begin
  Result := SHA1(Value.DataPtr[0], Value.Len);
end;

function UtcNow: TDateTime;
var
  st1, st2: TSystemTime;
  tz: TTimeZoneInformation;
begin
  // TZ - локальные (Windows) настройки
  GetTimeZoneInformation(tz);

  // т.к. надо будет делать обратное преобразование - инвертируем bias
  tz.Bias := -tz.Bias;
  tz.StandardBias := -tz.StandardBias;
  tz.DaylightBias := -tz.DaylightBias;

  DateTimeToSystemTime(Now, st1);

  // ѕрименение локальных настроек ко времени
  SystemTimeToTzSpecificLocalTime(@tz, st1, st2);

  // ѕриведение WindowsSystemTime к TDateTime
  Result := SystemTimeToDateTime(st2);
end;

end.
