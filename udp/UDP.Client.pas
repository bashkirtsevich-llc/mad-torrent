unit UDP.Client;

interface

uses
  System.Classes, System.SysUtils,
  Basic.UniString,
  IdGlobal, IdStack, IdStackConsts, IdUDPClient, IdBuffer;

type
  TUDPClient = class(TIdUDPClient)
  private
    FInputBuffer: TIdBuffer;
    FWriteBuffer: TIdBuffer;
    function GetInputBufferIsEmpty: Boolean; inline;
    function GetInputBufferSize: Integer; inline;
  public
    function CheckForDataOnSource(ATimeout: Integer = IdTimeoutDefault): Boolean; inline;

    procedure ReadBytes(var VBuffer: TIdBytes; AByteCount: Integer;
      AAppend: Boolean = True); inline;

    function ReadByte: Byte; inline;
    function ReadInt16(AConvert: Boolean = True): Int16; inline;
    function ReadUInt16(AConvert: Boolean = True): UInt16; inline;
    function ReadInt32(AConvert: Boolean = True): Int32; inline;
    function ReadUInt32(AConvert: Boolean = True): UInt32; inline;
    function ReadInt64(AConvert: Boolean = True): Int64; inline;

    procedure ReadUniString(AByteCount: Integer; out AData: TUniString); inline;

    procedure WriteBufferOpen; inline;

    procedure Write(const ABuffer: TIdBytes; const ALength: Integer = -1;
      const AOffset: Integer = 0); overload; inline;

    procedure Write(AValue: Byte); overload; inline;
    procedure Write(AValue: Int16; AConvert: Boolean = True); overload; inline;
    procedure Write(AValue: UInt16; AConvert: Boolean = True); overload; inline;
    procedure Write(AValue: Int32; AConvert: Boolean = True); overload; inline;
    procedure Write(AValue: UInt32; AConvert: Boolean = True); overload; inline;
    procedure Write(AValue: Int64; AConvert: Boolean = True); overload; inline;

    procedure WriteUniString(const AValue: TUniString); inline;

    procedure WriteBufferFlush; overload; inline;
    procedure WriteBufferFlush(const AHost: string; const APort: TIdPort;
      const AIPVersion: TIdIPVersion = Id_IPv4); overload; inline;

    property InputBufferIsEmpty: Boolean read GetInputBufferIsEmpty;
    property InputBufferSize: Integer read GetInputBufferSize;
  public
    constructor Create(AOwner: TComponent; AReceiveTimeout: Integer = 15000 { 15 sec }); reintroduce;
    destructor Destroy; override;
  end;

implementation

{ TUDPClient }

function TUDPClient.CheckForDataOnSource(ATimeout: Integer): Boolean;
var
  LBytes: TIdBytes;
begin
  if FInputBuffer.Size = 0 then
  begin
    SetLength(LBytes, Word.MaxValue);
    SetLength(LBytes, ReceiveBuffer(LBytes, ATimeout));
    FInputBuffer.Write(LBytes);
  end;

  Result := not GetInputBufferIsEmpty;
end;

constructor TUDPClient.Create(AOwner: TComponent; AReceiveTimeout: Integer);
begin
  inherited Create(AOwner);

  TIdStack.IncUsage;

  ReceiveTimeout  := AReceiveTimeout;
  FWriteBuffer    := TIdBuffer.Create;
  FInputBuffer    := TIdBuffer.Create;
end;

destructor TUDPClient.Destroy;
begin
  FInputBuffer.Free;
  FWriteBuffer.Free;
  TIdStack.DecUsage;
  inherited;
end;

function TUDPClient.GetInputBufferIsEmpty: Boolean;
begin
  Result := FInputBuffer.Size = 0;
end;

function TUDPClient.GetInputBufferSize: Integer;
begin
  Result := FInputBuffer.Size;
end;

function TUDPClient.ReadByte: Byte;
var
  LBytes: TIdBytes;
begin
  ReadBytes(LBytes, 1, False);
  Result := LBytes[0];
end;

procedure TUDPClient.ReadBytes(var VBuffer: TIdBytes; AByteCount: Integer;
  AAppend: Boolean);
begin
  if CheckForDataOnSource then
    FInputBuffer.ExtractToBytes(VBuffer, AByteCount, AAppend);
end;

function TUDPClient.ReadInt16(AConvert: Boolean): Int16;
var
  LBytes: TIdBytes;
begin
  ReadBytes(LBytes, SizeOf(Int16), False);
  Result := BytesToInt16(LBytes);
  if AConvert then
    Result := Int16(GStack.NetworkToHost(UInt16(Result)));
end;

function TUDPClient.ReadInt32(AConvert: Boolean): Int32;
var
  LBytes: TIdBytes;
begin
  ReadBytes(LBytes, SizeOf(Int32), False);
  Result := BytesToInt32(LBytes);
  if AConvert then
    Result := Int32(GStack.NetworkToHost(UInt32(Result)));
end;

function TUDPClient.ReadInt64(AConvert: Boolean): Int64;
var
  LBytes: TIdBytes;
  {$IFDEF VCL_60}
  h: Int64;
  {$ENDIF}
begin
  ReadBytes(LBytes, SizeOf(Int64), False);
  Result := BytesToInt64(LBytes);
  if AConvert then
  begin
    {$IFDEF VCL_60}
    // assigning to a local variable to avoid an "Internal error URW699" compiler error in Delphi 6
    h := GStack.NetworkToHost(UInt64(Result));
    Result := h;
    {$ELSE}
    Result := Int64(GStack.NetworkToHost(UInt64(Result)));
    {$ENDIF}
  end;
end;

function TUDPClient.ReadUInt16(AConvert: Boolean): UInt16;
var
  LBytes: TIdBytes;
begin
  ReadBytes(LBytes, SizeOf(UInt16), False);
  Result := BytesToUInt16(LBytes);
  if AConvert then
    Result := GStack.NetworkToHost(Result);
end;

function TUDPClient.ReadUInt32(AConvert: Boolean): UInt32;
var
  LBytes: TIdBytes;
begin
  ReadBytes(LBytes, SizeOf(UInt32), False);
  Result := BytesToUInt32(LBytes);
  if AConvert then
    Result := GStack.NetworkToHost(Result);
end;

procedure TUDPClient.ReadUniString(AByteCount: Integer; out AData: TUniString);
var
  LBytes: TIdBytes;
begin
  ReadBytes(LBytes, AByteCount);
  AData.Len := AByteCount;
  Move(LBytes[0], AData.DataPtr[0]^, AByteCount);
end;

procedure TUDPClient.Write(const ABuffer: TIdBytes; const ALength,
  AOffset: Integer);
var
  LLength: Integer;
begin
  LLength := IndyLength(ABuffer, ALength, AOffset);

  if LLength > 0 then
    FWriteBuffer.Write(ABuffer, LLength, AOffset);
end;

procedure TUDPClient.Write(AValue: UInt16; AConvert: Boolean);
begin
  if AConvert then
    AValue := GStack.HostToNetwork(AValue);

  Write(ToBytes(AValue));
end;

procedure TUDPClient.Write(AValue: Int16; AConvert: Boolean);
begin
  if AConvert then
    AValue := Int16(GStack.HostToNetwork(UInt16(AValue)));

  Write(ToBytes(AValue));
end;

procedure TUDPClient.Write(AValue: Byte);
begin
  Write(ToBytes(AValue));
end;

procedure TUDPClient.Write(AValue: Int32; AConvert: Boolean);
begin
  if AConvert then
    AValue := Int32(GStack.HostToNetwork(UInt32(AValue)));

  Write(ToBytes(AValue));
end;

procedure TUDPClient.Write(AValue: Int64; AConvert: Boolean);
{$IFDEF VCL_60}
var
  h: Int64;
{$ENDIF}
begin
  if AConvert then
  begin
    {$IFDEF VCL_60}
    // assigning to a local variable to avoid an "Internal error URW699" compiler error in Delphi 6
    h := GStack.HostToNetwork(UInt64(AValue));
    AValue := h;
    {$ELSE}
    AValue := Int64(GStack.HostToNetwork(UInt64(AValue)));
    {$ENDIF}
  end;
  Write(ToBytes(AValue));
end;

procedure TUDPClient.Write(AValue: UInt32; AConvert: Boolean);
begin
  if AConvert then
    AValue := GStack.HostToNetwork(AValue);

  Write(ToBytes(AValue));
end;

procedure TUDPClient.WriteBufferFlush(const AHost: string; const APort: TIdPort;
  const AIPVersion: TIdIPVersion);
var
  LBytes: TIdBytes;
begin
  if FWriteBuffer.Size > 0 then
  begin
    FWriteBuffer.ExtractToBytes(LBytes);
    SendBuffer(AHost, APort, AIPVersion, LBytes);
  end;
end;

procedure TUDPClient.WriteBufferFlush;
var
  LBytes: TIdBytes;
begin
  if FWriteBuffer.Size > 0 then
  begin
    FWriteBuffer.ExtractToBytes(LBytes);
    SendBuffer(LBytes);
  end;
end;

procedure TUDPClient.WriteBufferOpen;
begin
  FWriteBuffer.Clear;
end;

procedure TUDPClient.WriteUniString(const AValue: TUniString);
var
  buf: TIdBytes;
begin
  SetLength(buf, AValue.Len);
  Move(AValue.DataPtr[0]^, buf[0], AValue.Len);

  Write(buf);
end;

end.
