unit Bittorrent.Utils;

interface

uses
  Winapi.Windows,
  System.SysUtils, System.DateUtils,
  Basic.UniString,
  IdHMAC, IdHMACSHA1, IdGlobal;

function SHA1(const AData: TIdBytes): TUniString; overload;
function SHA1(const Value: TUniString): TUniString; overload;
function UtcNow: TDateTime;

implementation

function SHA1(const AData: TIdBytes): TUniString; overload;
var
  ctx: TIdHMAC;
begin
  ctx := TIdHMACSHA1.Create;
  try
    Result := ctx.HashValue(AData);
  finally
    ctx.Free;
  end;
end;

function SHA1(const Value: TUniString): TUniString; overload;
var
  buf: TIdBytes;
begin
  SetLength(buf, Value.Len);
  Move(Value.DataPtr[0]^, buf[0], Value.Len);
  Result := SHA1(buf);
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
