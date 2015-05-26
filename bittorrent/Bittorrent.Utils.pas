unit Bittorrent.Utils;

interface

uses
  System.SysUtils, System.DateUtils, System.Hash,
  Winapi.Windows,
  Basic.UniString;

function SHA1(const AData: TBytes): TUniString; overload; inline;
function SHA1(const Value: TUniString): TUniString; overload; inline;
function UtcNow: TDateTime;

implementation

function SHA1(const AData: TBytes): TUniString; overload;
var
  ctx: THashSHA1;
begin
  ctx := THashSHA1.Create;
  ctx.Update(AData);
  Result := ctx.HashAsBytes;
end;

function SHA1(const Value: TUniString): TUniString; overload;
var
  ctx: THashSHA1;
begin
  ctx := THashSHA1.Create;
  ctx.Update(Value.DataPtr[0]^, Value.Len);
  Result := ctx.HashAsBytes;
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

  // Применение локальных настроек ко времени
  SystemTimeToTzSpecificLocalTime(@tz, st1, st2);

  // Приведение WindowsSystemTime к TDateTime
  Result := SystemTimeToDateTime(st2);
end;

end.
