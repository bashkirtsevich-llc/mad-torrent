unit VLC.Player;

interface

uses
  System.Classes, System.SysUtils, System.Math,
  Winapi.Windows,
  Vcl.Graphics,
  PasLibVlcUnit;

type
  TVLCPlayer = class
  private
    const
      MAX_ARGS = 255;
      Events: array[0..19] of libvlc_event_type_t = (
        libvlc_MediaPlayerScrambledChanged,
        libvlc_MediaPlayerVout,
        libvlc_MediaPlayerLengthChanged,
        libvlc_MediaPlayerSnapshotTaken,
        libvlc_MediaPlayerTitleChanged,
        libvlc_MediaPlayerPausableChanged,
        libvlc_MediaPlayerSeekableChanged,
        libvlc_MediaPlayerPositionChanged,
        libvlc_MediaPlayerTimeChanged,
        libvlc_MediaPlayerEncounteredError,
        libvlc_MediaPlayerEndReached,
        libvlc_MediaPlayerBackward,
        libvlc_MediaPlayerForward,
        libvlc_MediaPlayerStopped,
        libvlc_MediaPlayerPaused,
        libvlc_MediaPlayerPlaying,
        libvlc_MediaPlayerBuffering,
        libvlc_MediaPlayerOpening,
        libvlc_MediaPlayerNothingSpecial,
        libvlc_MediaPlayerMediaChanged
      );
  private
    FLibInstance: libvlc_instance_t_ptr;

    FPlayerInstance: libvlc_media_player_t_ptr;
    FEventManager: libvlc_event_manager_t_ptr;

    FLock: TObject;
    FBuffer: TMemoryStream;
    FBufWidth,
    FBufHeight: Integer;

    FArgV: packed array[0..MAX_ARGS-1] of AnsiString;
    AFrgS: packed array[0..MAX_ARGS-1] of PAnsiChar;
    FArgC: Integer;

    FOnOpen: TFunc<TVLCPlayer, Int64>;
    FOnRead: TFunc<TVLCPlayer, PByte, Integer, Integer>;
    FOnSeek: TProc<TVLCPlayer, Int64>;
    FOnClose: TProc<TVLCPlayer>;
    FOnDisplayFrame: TProc<TVLCPlayer, TStream>;
    FOnLengthChanged: TProc<TVLCPlayer, Int64>;
    FOnPositionChanged: TProc<TVLCPlayer, Single>;
    FOnStopped: TProc<TVLCPlayer>;
    FOnPlaying: TProc<TVLCPlayer>;
    FOnPaused: TProc<TVLCPlayer>;
    FOnEndReached: TProc<TVLCPlayer>;

    procedure AddArg(const AValue: string); inline;
    procedure RegisterEvents;
    procedure UnRegisterEvents;
    function GetPaused: Boolean; inline;
    function GetPlaying: Boolean; inline;
    function GetVolume: Integer; inline;
    procedure SetVolume(const Value: Integer); inline;
    function GetMute: Boolean; inline;
    procedure SetMute(const Value: Boolean); inline;
    function GetLengthMS: Int64; inline;
    function GetPositionMS: Int64; inline;
    procedure SetPositionMS(const Value: Int64); inline;
    function GetState: SmallInt; inline;

    procedure Lock; inline;
    procedure Unlock; inline;
    function GetAspectRatio: string;
    procedure SetAspectRatio(const Value: string);
    function GetPosition: Single;
    procedure SetPosition(const Value: Single);

    procedure Exec(AProc: TProc; AWait: Boolean = False);
    function GetEnded: Boolean; inline;
    function GetStopped: Boolean; inline;
  public
    procedure Start;
    procedure Pause;
    procedure Resume;
    procedure Stop(AWait: Boolean = False);
    procedure TogglePause; inline;

    property Playing: Boolean read GetPlaying;
    property Paused: Boolean read GetPaused;
    property Stopped: Boolean read GetStopped;
    property Ended: Boolean read GetEnded;
    property Volume: Integer read GetVolume write SetVolume;
    property Mute: Boolean read GetMute write SetMute;
    property LengthMS: Int64 read GetLengthMS;
    property PositionMS: Int64 read GetPositionMS write SetPositionMS;
    property Position: Single read GetPosition write SetPosition;
    property AspectRatio: string read GetAspectRatio write SetAspectRatio;
    property State: SmallInt read GetState;

    property OnOpen: TFunc<TVLCPlayer, Int64> read FOnOpen write FOnOpen;
    property OnRead: TFunc<TVLCPlayer, PByte, Integer, Integer> read FOnRead write FOnRead;
    property OnSeek: TProc<TVLCPlayer, Int64> read FOnSeek write FOnSeek;
    property OnClose: TProc<TVLCPlayer> read FOnClose write FOnClose;

    property OnDisplayFrame: TProc<TVLCPlayer, TStream> read FOnDisplayFrame write FOnDisplayFrame;

    property OnLengthChanged: TProc<TVLCPlayer, Int64> read FOnLengthChanged write FOnLengthChanged;
    property OnPositionChanged: TProc<TVLCPlayer, Single> read FOnPositionChanged write FOnPositionChanged;
    property OnStopped: TProc<TVLCPlayer> read FOnStopped write FOnStopped;
    property OnEndReached: TProc<TVLCPlayer> read FOnEndReached write FOnEndReached;
    property OnPaused: TProc<TVLCPlayer> read FOnPaused write FOnPaused;
    property OnPlaying: TProc<TVLCPlayer> read FOnPlaying write FOnPlaying;

    constructor Create(const ALibPath: string; ABufWidth, ABufHeight: Integer);
    destructor Destroy; override;
  end;

implementation

{ TVLCPlayer }

procedure TVLCPlayer.AddArg(const AValue: string);
begin
  if FArgC < MAX_ARGS then
  begin
    FArgV[FArgC] := Utf8Encode(AValue);
    AFrgS[FArgC] := PAnsiChar(FArgV[FArgC]);
    Inc(FArgC);
  end;
end;

constructor TVLCPlayer.Create(const ALibPath: string; ABufWidth,
  ABufHeight: Integer);
var
  bmf: TBitmapFileHeader;
  dsBmih: TBitmapInfoHeader;
begin
  libvlc_dynamic_dll_init_with_path(ALibPath);

  if not libvlc_dynamic_dll_error.IsEmpty then
    raise Exception.Create(libvlc_dynamic_dll_error);

  FLock := TObject.Create;

  FArgC := 0;
  AddArg(libvlc_dynamic_dll_path);
  AddArg('--intf=dummy');
  AddArg('--ignore-config');
  AddArg('--quiet');
  AddArg('--no-one-instance');
  AddArg('--drop-late-frames');
  AddArg('--video-filter=transform');
  AddArg('--transform-type=vflip'); //90, 180, 270, hfilp, vfilp.

//  if not FSpuShow     then FVLC.AddOption('--no-spu')              else FVLC.AddOption('--spu');
//  if not FOsdShow     then FVLC.AddOption('--no-osd')              else FVLC.AddOption('--osd');
//  if not FVideoOnTop  then FVLC.AddOption('--no-video-on-top')     else FVLC.AddOption('--video-on-top');
//  if not FUseOverlay  then FVLC.AddOption('--no-overlay')          else FVLC.AddOption('--overlay');
//  if not FSnapshotPrv then FVLC.AddOption('--no-snapshot-preview') else FVLC.AddOption('--snapshot-preview');
//
//  if (FVideoOutput <> voDefault) then FVLC.AddOption('--vout=' + vlcVideoOutputNames[FVideoOutput]);
//  if (FAudioOutput <> aoDefault) then FVLC.AddOption('--aout=' + vlcAudioOutputNames[FAudioOutput]);

  FLibInstance    := libvlc_new(FArgC, @AFrgS);
  FPlayerInstance := nil;
  FEventManager   := nil;

  FBufWidth := ABufWidth;
  FBufHeight:= ABufHeight;

  FBuffer := TMemoryStream.Create;

  {bfType:19778; bfSize:8294454; bfReserved1:0; bfReserved2:0; bfOffBits:54}
  FillChar(bmf, SizeOf(TBitmapFileHeader), 0);
  with bmf do
  begin
    bfType := $4D42;
    bfSize := ABufWidth * ABufHeight * 4 + SizeOf(TBitmapInfoHeader);
    bfOffBits := SizeOf(TBitmapFileHeader) + SizeOf(TBitmapInfoHeader);
  end;

  FBuffer.Write(bmf, SizeOf(TBitmapFileHeader));

  {biSize:40; biWidth:1920; biHeight:1080; biPlanes:1; biBitCount:32;
    biCompression:0; biSizeImage:8294400; biXPelsPerMeter:0; biYPelsPerMeter:0;
    biClrUsed:0; biClrImportant:0}
  FillChar(dsBmih, SizeOf(dsBmih), 0);
  with dsBmih do
  begin
    biSize := SizeOf(TBitmapInfoHeader);
    biWidth := ABufWidth;
    biHeight := ABufHeight;
    biPlanes := 1;
    biBitCount := 32;
    biSizeImage := ABufWidth * ABufHeight * 4;
  end;

  FBuffer.Write(dsBmih, SizeOf(TBitmapInfoHeader));
  FBuffer.Size := FBuffer.Size + dsBmih.biSizeImage;
end;

destructor TVLCPlayer.Destroy;
begin
  if Assigned(FLibInstance) then
  begin
    Pause;
    Sleep(10);
    Stop(True);

    Lock;
    try
      libvlc_release(FLibInstance);
      FLibInstance := nil;
    finally
      Unlock;
    end;
  end;

  FBuffer.Free;
  FLock.Free;

  inherited;
end;

procedure TVLCPlayer.Exec(AProc: TProc; AWait: Boolean);
var
  b: Boolean;
begin
  b := False;

  TThread.CreateAnonymousThread(procedure
  begin
    AProc();
    b := True;
  end).Start;

  while AWait and not b do
    Sleep(1);
end;

function TVLCPlayer.GetAspectRatio: string;
var
  ratio: PAnsiChar;
begin
  Lock;
  try
    Result := '';

    if Assigned(FPlayerInstance) then
    begin
      ratio := libvlc_video_get_aspect_ratio(FPlayerInstance);

      if Assigned(ratio) then
      try
        Result := UTF8ToWideString(AnsiString(ratio));
      finally
        libvlc_free(ratio);
      end;
    end;
  finally
    Unlock;
  end;
end;

function TVLCPlayer.GetEnded: Boolean;
begin
  Lock;
  try
    Result := (not Assigned(FPlayerInstance)) or (libvlc_media_player_get_state(FPlayerInstance) = libvlc_Ended);
  finally
    Unlock;
  end;
end;

function TVLCPlayer.GetLengthMS: Int64;
begin
  Result := 0;

  Lock;
  try
    if Assigned(FPlayerInstance) then
      Result := libvlc_media_player_get_length(FPlayerInstance);
  finally
    Unlock;
  end;
end;

function TVLCPlayer.GetMute: Boolean;
begin
  Lock;
  try
    Result := Assigned(FPlayerInstance) and (libvlc_audio_get_mute(FPlayerInstance) > 0);
  finally
    Unlock;
  end;
end;

function TVLCPlayer.GetPaused: Boolean;
begin
  Lock;
  try
    Result := Assigned(FPlayerInstance) and (libvlc_media_player_get_state(FPlayerInstance) = libvlc_Paused);
  finally
    Unlock;
  end;
end;

function TVLCPlayer.GetPlaying: Boolean;
begin
  Lock;
  try
    Result := Assigned(FPlayerInstance) and (libvlc_media_player_get_state(FPlayerInstance) = libvlc_Playing);
  finally
    Unlock;
  end;
end;

function TVLCPlayer.GetPosition: Single;
begin
  Result := 0;
  if Assigned(FPlayerInstance) then
    Result := libvlc_media_player_get_position(FPlayerInstance);
end;

function TVLCPlayer.GetPositionMS: Int64;
begin
  Result := 0;

  Lock;
  try
    if Assigned(FPlayerInstance) then
      Result := libvlc_media_player_get_time(FPlayerInstance);
  finally
    Unlock;
  end;
end;

function TVLCPlayer.GetState: SmallInt;
begin
  Result := 0;

  Lock;
  try
    if Assigned(FPlayerInstance) then
      Result := Ord(libvlc_media_player_get_state(FPlayerInstance));
  finally
    Unlock;
  end;
end;

function TVLCPlayer.GetStopped: Boolean;
begin
  Lock;
  try
    Result := (not Assigned(FPlayerInstance)) or (libvlc_media_player_get_state(FPlayerInstance) = libvlc_Stopped);
  finally
    Unlock;
  end;
end;

function TVLCPlayer.GetVolume: Integer;
begin
  Result := -1;

  Lock;
  try
    if Assigned(FPlayerInstance) then
      Result := libvlc_audio_get_volume(FPlayerInstance);
  finally
    Unlock;
  end;
end;

procedure TVLCPlayer.Lock;
begin
  TMonitor.Enter(FLock);
end;

procedure TVLCPlayer.Pause;
begin
  Exec(procedure
  begin
    Lock;
    try
      if GetPlaying then
        libvlc_media_player_pause(FPlayerInstance);
    finally
      Unlock;
    end;
  end);
end;

function CBOpen(AOpaque: Pointer; var AData: Pointer;
  var ASize: Int64): Integer; cdecl;
var
  Self: TVLCPlayer absolute AOpaque;
begin
  Assert(Assigned(Self.FOnOpen));
  ASize := Self.FOnOpen(Self);

  AData := Self;
  Result := 0;
end;

function CBRead(AOpaque: Pointer; ABuf: PByte; ALen: Integer): Integer; cdecl;
var
  Self: TVLCPlayer absolute AOpaque;
begin
  Assert(Assigned(Self.FOnRead));
  Result := Self.FOnRead(Self, ABuf, ALen);
end;

function CBSeek(AOpaque: Pointer; AOffset: Int64): Integer; cdecl;
var
  Self: TVLCPlayer absolute AOpaque;
begin
  Assert(Assigned(Self.FOnSeek));
  Self.FOnSeek(Self, AOffset);

  Result := 0;
end;

function CBClose(AOpaque: Pointer): Integer; cdecl;
var
  Self: TVLCPlayer absolute AOpaque;
begin
  if Assigned(Self.FOnClose) then
    Self.FOnClose(Self);

  Result := 0;
end;

function CBLockVideo(AContext: Pointer; var APlanes: Pointer): Pointer; cdecl;
var
  Self: TVLCPlayer absolute AContext;
begin
  APlanes := Pointer((Cardinal(Self.FBuffer.Memory) +
    SizeOf(TBitmapFileHeader) + SizeOf(TBitmapInfoHeader)));
  Result := Self.FBuffer;
end;

function CBDisplayVideo(AContext: Pointer; APicture: Pointer): Pointer; cdecl;
var
  Self: TVLCPlayer absolute AContext;
  Stream: TStream absolute APicture;
begin
  Stream.Position := 0;

  if Assigned(Self.FOnDisplayFrame) then
    Self.FOnDisplayFrame(Self, Stream);

  Result := nil;
end;

procedure TVLCPlayer.Start;
begin
  Exec(procedure
  var
    media: libvlc_media_t_ptr;
  begin
    Lock;
    try
      FPlayerInstance := libvlc_media_player_new(FLibInstance);

      if Assigned(FPlayerInstance) then
      begin
        libvlc_video_set_callbacks(FPlayerInstance, CBLockVideo, nil,
          CBDisplayVideo, Self);

        libvlc_video_set_format(FPlayerInstance, 'RV32', FBufWidth, FBufHeight,
          FBufWidth * 4);

        media := libvlc_media_new_callbacks(FLibInstance, CBOpen, CBRead, CBSeek,
          CBClose, Self);

        if Assigned(media) then
        try
          RegisterEvents;

          libvlc_media_player_set_media(FPlayerInstance, media);
        finally
          libvlc_media_release(media);
        end;

        libvlc_media_player_play(FPlayerInstance);
      end;
    finally
      Unlock;
    end;
  end);
end;

procedure CBEventHandler(AEvent: libvlc_event_t_ptr; AData: Pointer); cdecl;
var
  Self: TVLCPlayer absolute AData;
begin
  if Assigned(Self) then
    with Self do
    case AEvent^.event_type of
//      libvlc_MediaPlayerScrambledChanged,
//      libvlc_MediaPlayerVout,

      libvlc_MediaPlayerLengthChanged:
        if Assigned(FOnLengthChanged) then
          FOnLengthChanged(Self, AEvent^.media_player_length_changed.new_length);

//      libvlc_MediaPlayerSnapshotTaken,
//      libvlc_MediaPlayerTitleChanged,
//      libvlc_MediaPlayerPausableChanged,
//      libvlc_MediaPlayerSeekableChanged,

      libvlc_MediaPlayerPositionChanged:
        if Assigned(FOnPositionChanged) then
          FOnPositionChanged(Self, AEvent^.media_player_position_changed.new_position);

//      libvlc_MediaPlayerTimeChanged,
//      libvlc_MediaPlayerEncounteredError,
//      libvlc_MediaPlayerEndReached,
//      libvlc_MediaPlayerBackward,
//      libvlc_MediaPlayerForward,

      libvlc_MediaPlayerStopped:
        if Assigned(FOnStopped) then
          FOnStopped(Self);

      libvlc_MediaPlayerEndReached:
        if Assigned(FOnEndReached) then
          FOnEndReached(Self);

      libvlc_MediaPlayerPaused:
        if Assigned(FOnPaused) then
          FOnPaused(Self);

      libvlc_MediaPlayerPlaying:
        if Assigned(FOnPlaying) then
          FOnPlaying(Self);

//      libvlc_MediaPlayerBuffering,
//      libvlc_MediaPlayerOpening,
//      libvlc_MediaPlayerNothingSpecial,
//      libvlc_MediaPlayerMediaChanged
    end;
end;

procedure TVLCPlayer.RegisterEvents;
var
  ev: libvlc_event_type_t;
begin
  Assert(Assigned(FPlayerInstance));

  UnRegisterEvents;

  FEventManager := libvlc_media_player_event_manager(FPlayerInstance);
  if Assigned(FEventManager) then
    for ev in Events do
      libvlc_event_attach(FEventManager, ev, CBEventHandler, Self);
end;

procedure TVLCPlayer.UnRegisterEvents;
var
  ev: libvlc_event_type_t;
begin
  if Assigned(FEventManager) then
  begin
    for ev in Events do
      libvlc_event_detach(FEventManager, ev, CBEventHandler, Self);

    FEventManager := nil;
  end;
end;

procedure TVLCPlayer.Resume;
begin
  Exec(procedure
  begin
    Lock;
    try
      if GetPaused then
        libvlc_media_player_play(FPlayerInstance);
    finally
      Unlock;
    end;
  end);
end;

procedure TVLCPlayer.SetAspectRatio(const Value: string);
begin
  Lock;
  try
    if Assigned(FPlayerInstance) then
      libvlc_video_set_aspect_ratio(FPlayerInstance, PAnsiChar(AnsiString(Value)));
  finally
    Unlock;
  end;
end;

procedure TVLCPlayer.SetMute(const Value: Boolean);
begin
  Lock;
  try
    if Assigned(FPlayerInstance) then
      libvlc_audio_set_mute(FPlayerInstance, IfThen(Value, 1, 0));
  finally
    Unlock;
  end;
end;

procedure TVLCPlayer.SetPosition(const Value: Single);
begin
  if Assigned(FPlayerInstance) then
  begin
    libvlc_media_player_set_position(FPlayerInstance, Value);

    if Assigned(FOnPositionChanged) and not GetPlaying then
      FOnPositionChanged(Self, Value);
  end;
end;

procedure TVLCPlayer.SetPositionMS(const Value: Int64);
begin
  Lock;
  try
    if Assigned(FPlayerInstance) and (Value >= 0) and (Value <= GetLengthMS) and
      (libvlc_media_player_is_seekable(FPlayerInstance) > 0) then

    libvlc_media_player_set_time(FPlayerInstance, Value);
  finally
    Unlock;
  end;
end;

procedure TVLCPlayer.SetVolume(const Value: Integer);
begin
  Lock;
  try
    if Assigned(FPlayerInstance) and (Value >= 0) and (Value <= 100) then
      libvlc_audio_set_volume(FPlayerInstance, Value);
  finally
    Unlock;
  end;
end;

procedure TVLCPlayer.Stop(AWait: Boolean);
begin
  Exec(procedure
  begin
    Lock;
    try
      if Assigned(FPlayerInstance) then
      begin
        {$IFDEF DEBUG}
        OutputDebugString('MAD! libvlc_media_player_stop');
        {$ENDIF}
        libvlc_media_player_stop(FPlayerInstance);
        {$IFDEF DEBUG}
        OutputDebugString('MAD! libvlc_media_player_stop done!');
        {$ENDIF}

        while GetPlaying do
          Sleep(1);

        {$IFDEF DEBUG}
        OutputDebugString('MAD! UnRegisterEvents');
        {$ENDIF}
        UnRegisterEvents;

        libvlc_media_player_release(FPlayerInstance);
        FPlayerInstance := nil;
        {$IFDEF DEBUG}
        OutputDebugString('MAD! stopped');
        {$ENDIF}
      end;
    finally
      Unlock;
    end;
  end, AWait);
end;

procedure TVLCPlayer.TogglePause;
begin
  if GetPlaying then
    Pause
  else
    Resume;
end;

procedure TVLCPlayer.Unlock;
begin
  TMonitor.Exit(FLock);
end;

end.
