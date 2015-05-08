unit IdIOHandlerHelper;

interface

uses
  IdIOHandler, Basic.UniString;

type
  TIdIOHandlerHelper = class helper for TIdIOHandler
  public
    procedure ReadUniString(AByteCount: Integer; out AData: TUniString); inline;

    procedure WriteByte(AValue: Byte); inline;
    procedure WriteWord(AValue: Word; AConvert: Boolean = True); inline;
    procedure WriteCardinal(AValue: Cardinal; AConvert: Boolean = True); inline;
    procedure WriteInt64(AValue: Int64; AConvert: Boolean = True); inline;
    procedure WriteString(AValue: string); inline;
    procedure WriteUniString(AValue: TUniString); inline;
    procedure WriteBytes(ALen: Integer; AValue: Byte = 0); inline;

    procedure SkipBytes(ALen: Integer); inline;
  end;

implementation

uses
  IdGlobal;

{ TIdIOHandlerHelper }

procedure TIdIOHandlerHelper.WriteBytes(ALen: Integer; AValue: Byte);
var
  buf: TIdBytes;
begin
  SetLength(buf, ALen);
  FillChar(buf[0], ALen, AValue);
  Write(buf);
end;

procedure TIdIOHandlerHelper.ReadUniString(AByteCount: Integer; out AData: TUniString);
var
  buf: TIdBytes;
begin
  ReadBytes(buf, AByteCount);
  AData.Len := AByteCount;
  Move(buf[0], AData.DataPtr[0]^, AByteCount);
  //AData := buf;
end;

procedure TIdIOHandlerHelper.SkipBytes(ALen: Integer);
var
  buf: TIdBytes;
begin
  ReadBytes(buf, ALen);
end;

procedure TIdIOHandlerHelper.WriteByte(AValue: Byte);
begin
  Write(AValue);
end;

procedure TIdIOHandlerHelper.WriteCardinal(AValue: Cardinal;
  AConvert: Boolean = True);
begin
  Write(AValue, AConvert);
end;

procedure TIdIOHandlerHelper.WriteInt64(AValue: Int64;
  AConvert: Boolean = True);
begin
  Write(AValue, AConvert);
end;

procedure TIdIOHandlerHelper.WriteString(AValue: string);
begin
  Write(AValue);
end;

procedure TIdIOHandlerHelper.WriteUniString(AValue: TUniString);
var
  buf: TIdBytes;
begin
  SetLength(buf, AValue.Len);
  Move(AValue.DataPtr[0]^, buf[0], AValue.Len);

  Write(buf);
end;

procedure TIdIOHandlerHelper.WriteWord(AValue: Word;
  AConvert: Boolean = True);
begin
  Write(AValue, AConvert);
end;

end.
