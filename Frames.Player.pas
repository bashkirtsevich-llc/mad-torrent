unit Frames.Player;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  System.SyncObjs, System.TimeSpan, System.Rtti, System.Math,

  Winapi.Windows,

  FMX.Types, FMX.Graphics, FMX.Controls, FMX.Forms, FMX.StdCtrls,
  FMX.Objects, FMX.Layouts, FMX.Surfaces, System.Actions,

  PasLibVlcUnit,
  VLC.Player,

  Common.Prelude,
  Bittorrent,

  Frames.Overlay, FMX.ActnList, FMX.Controls.Presentation, FMX.ListBox;

type
  TfrmPlayer = class(TFrame)
    rectangleScreen     : TRectangle;
    pnlState            : TPanel;
    tmrToolKitVisibility: TTimer;
    imageVideo          : TImage;
    pnlPlayerToolKit    : TPanel;
    layoutVolumeBar     : TLayout;
    trckbrVolume        : TTrackBar;
    layoutPlay          : TLayout;
    btnPlay             : TButton;
    layoutState         : TLayout;
    trckbrPlayingState  : TTrackBar;
    pbLoadingState      : TProgressBar;
    layoutFullScreen    : TLayout;
    btnFullScreen       : TButton;
    layoutVolume        : TLayout;
    btnVolume           : TButton;
    layoutTime          : TLayout;
    lblCurrentTime      : TLabel;
    lblFullTime         : TLabel;
    frmOverlay          : TfrmOverlay;
    tmrCursor           : TTimer;
	labelFileName       : TLabel;
    actlstFullScreen    : TActionList;
    actFullScreen       : TAction;
    lstFiles: TListBox;

    procedure btnPlayClick(Sender: TObject);
    procedure btnFullScreenClick(Sender: TObject);
    procedure btnVolumeClick(Sender: TObject);
    procedure trackBarPlayingChange(Sender: TObject);
    procedure trckbrVolumeChange(Sender: TObject);
    procedure trckbrVolumeClick(Sender: TObject);
    procedure trckbrVolumeKeyUp(Sender: TObject; var Key: Word;
      var KeyChar: Char; Shift: TShiftState);
    procedure SetIcon(AControl: TControl; AOnStyle, AOffStyle: string;
      ACondition: Boolean);
    procedure FillTrackBar(Sender: TObject);
    procedure tmrToolKitVisibilityTimer(Sender: TObject);
    procedure trckbrPlayingStateMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    procedure trckbrPlayingStateMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    procedure trckbrPlayingStateApplyStyleLookup(Sender: TObject);
    procedure trckbrPlayingStateThumbMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    procedure tmrCursorTimer(Sender: TObject);
	procedure actFullScreenExecute(Sender: TObject);
    procedure lstFilesDblClick(Sender: TObject);
  private
    const
      BuffSize: Integer = 10*1024*1024; { 10Мб буфер }
      MouseIdleTime: Integer = 3000; { 3 сек }
  private
    FPlayer     : TVLCPlayer;
    FLock       : TObject;
    FFileStream : TFileStream;
    FFileItem   : ISeedingItem;
    FPlaying    : Boolean;
    FMouseDroped: Boolean;
    FSeeding: ISeeding;

    procedure Lock; inline;
    procedure Unlock; inline;

    procedure SetFileItem(const Value: ISeedingItem);
    procedure SetPlayingState(APlaying: Boolean);

	  function TimeToString(ATime: Int64): string;
    procedure FadeControlIn(AControl: TControl);
    function CalcRequireSize: Int64; inline;

    function OnPlayerOpen(APlayer: TVLCPlayer): Int64;
    function OnPlayerRead(APlayer: TVLCPlayer; ABuf: PByte; ALen: Integer): Integer;
    procedure OnPlayerSeek(APlayer: TVLCPlayer; AOffset: Int64);
    procedure OnPlayerClose(APlayer: TVLCPlayer);
    procedure OnPlayerDisplayFrame(APlayer: TVLCPlayer; AStream: TStream);
    procedure OnPlayerLengthChanged(APlayer: TVLCPlayer; ALength: Int64);
    procedure OnPlayerPositionChanged(APlayer: TVLCPlayer; APosition: Single);
    procedure OnPlayerPlaying(APlayer: TVLCPlayer);
    procedure OnPlayerPaused(APlayer: TVLCPlayer);
    procedure OnPlayerEndReached(APlayer: TVLCPlayer);
    procedure SetSeeding(const Value: ISeeding);
  public
    property FileItem: ISeedingItem read FFileItem write SetFileItem;
    property Seeding: ISeeding read FSeeding write SetSeeding;
    procedure PausePlayer;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

implementation

uses
  Forms.Main;

{$R *.fmx}

{ TframePlayer }

var
//  dx, dy        : Single; //для хранения координат мыши

  FWindowRect   : TRect;
  FWindowState  : TWindowState;

(*
 * Обработчик события клика кнопки «Воспроизведение/пауза»
 *)

procedure TfrmPlayer.btnPlayClick(Sender: TObject);
begin
  if Assigned(FFileItem) then
  begin
    if FPlayer.Ended or FPlayer.Stopped then
      FPlayer.Start
    else
      FPlayer.TogglePause;

    FPlaying := not FPlayer.Playing;
  end;
end;

(*
 * Процедура изменения значка (вкл/выкл)
 *)

procedure TfrmPlayer.SetIcon(AControl: TControl; AOnStyle, AOffStyle: string;
  ACondition: Boolean);
var
  LButton: TButton absolute AControl;
begin
  LButton.StylesData[AOnStyle + '.Visible'] := ACondition;
  LButton.StylesData[AOffStyle + '.Visible'] := not ACondition;
end;

procedure TfrmPlayer.SetFileItem(const Value: ISeedingItem);
begin
//  TThread.CreateAnonymousThread(procedure
//  begin
    Lock;
    try
      Sleep(100);

      FPlayer.Pause;

      FFileItem := nil;

      FPlayer.Stop(True);

      if Assigned(FFileStream) then
        FreeAndNil(FFileStream);

      FFileItem := Value;
      FPlaying := Assigned(Value);

      if FPlaying then
      begin
        Value.Priority := fpImmediate;
		    labelFileName.Text := ExtractFileName(Value.Path);
		
        FPlayer.Start;
      end else
	  	  labelFileName.Text := '';

      TThread.Synchronize(nil, procedure
      begin
        with imageVideo.Bitmap do
          if Canvas.BeginScene then
            try
              Canvas.Clear(TAlphaColorRec.Black);
            finally
              Canvas.EndScene;
            end;
      end);
    finally
      Unlock;
    end;
//  end).Start;
end;

(*
 * Процедура заполнения полосы громкости/воспроизведения красным цветом
 *)

procedure TfrmPlayer.FillTrackBar(Sender: TObject);
var
  trackBar: TTrackBar absolute Sender;
begin
  trackBar.StylesData['hindicator.Width'] := trackBar.Width
                                           * trackBar.Value
                                           / trackBar.Max;
end;

procedure TfrmPlayer.Lock;
begin
  TMonitor.Enter(FLock);
end;

procedure TfrmPlayer.lstFilesDblClick(Sender: TObject);
var
  lst: TArray<ISeedingItem>;
  it: ISeedingItem;
  s: string;
begin
  if (lstFiles.ItemIndex <> -1) and Assigned(FSeeding) then
  begin
    s := lstFiles.Items[lstFiles.ItemIndex];

    Lock;
    try
      lst := FSeeding.Items.ToArray;

      for it in lst do
        if it.Path.Contains(s) then
        begin
          SetFileItem(it);
          lstFiles.Visible := False;
          Break;
        end;
    finally
      Unlock;
    end;
  end;
end;

procedure TfrmPlayer.OnPlayerClose(APlayer: TVLCPlayer);
begin
  if Assigned(FFileStream) then
    FreeAndNil(FFileStream);
end;

procedure TfrmPlayer.OnPlayerDisplayFrame(APlayer: TVLCPlayer;
  AStream: TStream);
begin
  TThread.Synchronize(nil, procedure
  begin
    imageVideo.Bitmap.LoadFromStream(AStream);
  end);
end;

procedure TfrmPlayer.OnPlayerEndReached(APlayer: TVLCPlayer);
begin
  TThread.Synchronize(nil, procedure
  begin
    trckbrPlayingState.Value := 0;
    SetPlayingState(False);
  end);
end;

procedure TfrmPlayer.OnPlayerLengthChanged(APlayer: TVLCPlayer; ALength: Int64);
begin
  TThread.Synchronize(nil, procedure
  begin
    lblFullTime.Text := '/ ' + TimeToString(ALength);
  end);
end;

function TfrmPlayer.OnPlayerOpen(APlayer: TVLCPlayer): Int64;
begin
  if Assigned(FFileItem) then
    Result := FFileItem.Size
  else
    Result := -1;
end;

procedure TfrmPlayer.OnPlayerPaused(APlayer: TVLCPlayer);
begin
  TThread.Synchronize(nil, procedure
  begin
    SetPlayingState(False);
  end);
end;

procedure TfrmPlayer.OnPlayerPlaying(APlayer: TVLCPlayer);
begin
  TThread.Synchronize(nil, procedure
  begin
    SetPlayingState(True);
  end);
end;

procedure TfrmPlayer.OnPlayerPositionChanged(APlayer: TVLCPlayer;
  APosition: Single);
begin
  TThread.Synchronize(nil, procedure
  begin
    trckbrPlayingState.Value := APosition;
    lblCurrentTime.Text := TimeToString(Trunc(APosition * FPlayer.LengthMS));
  end);
end;

function TfrmPlayer.OnPlayerRead(APlayer: TVLCPlayer; ABuf: PByte;
  ALen: Integer): Integer;
var
  len, pos: Int64;
begin
  if not Assigned(FFileItem) then
    Result := -1
  else
  begin
    Assert(FFileItem.Priority <> fpSkip);

    if Assigned(FFileStream) then
    begin
      if FFileStream.Position >= FFileStream.Size then
        Exit(0);

      pos := FFileStream.Position;
    end else
      pos := 0;

    len := calcRequireSize;

    while Assigned(FFileItem) and (
            not FileExists(FFileItem.Path) or { доп. проверка. файл создается только тогда, когда в него хотя бы 1 кусок записан }
            not FFileItem.IsLoaded(pos, Min(len, Int64(ALen)))) do
    begin
//      { показываем крутяшку }
//      if frmOverlay.Overlay <> otLoading then
//        TThread.Synchronize(nil, procedure
//        begin
//          frmOverlay.Overlay := otLoading;
//        end);

      FFileItem.Require(pos, len);

      Sleep(1);
    end;

    if Assigned(FFileItem) and FileExists(FFileItem.Path) then
    begin
      if not Assigned(FFileStream) then
        FFileStream := TFileStream.Create(FFileItem.Path, fmOpenRead or fmShareDenyNone);

      with FFileStream do
        Result := Read(ABuf^, Min(Int64(ALen), Size - Position));
    end else
      Result := 0;

//    { прячем крутяшку }
//    if frmOverlay.Overlay <> otNone then
//      TThread.Synchronize(nil, procedure
//      begin
//        frmOverlay.Overlay := otNone;
//      end);
  end;
end;

procedure TfrmPlayer.OnPlayerSeek(APlayer: TVLCPlayer; AOffset: Int64);
begin
  FFileStream.Seek(AOffset, soBeginning);
end;

procedure TfrmPlayer.PausePlayer;
begin
  if Assigned(FFileItem) and FPlayer.Playing then
  begin
    FPlaying := not FPlayer.Playing;
    FPlayer.Pause;
  end;
end;

procedure TfrmPlayer.tmrCursorTimer(Sender: TObject);
var
  LInput: TLastInputInfo;
begin
  LInput.cbSize := SizeOf(TLastInputInfo);
  GetLastInputInfo(LInput);

  ShowCursor(Int64(GetTickCount) - Int64(LInput.dwTime) <= MouseIdleTime);
end;

(*
 * Процедура отображения видео в области просмотра
 *)

procedure TfrmPlayer.tmrToolKitVisibilityTimer(Sender: TObject);
//var
//  b: Boolean;
begin
//  if Parent = frmMain.tabItemPlayer then
//  begin
//    tmrToolKitVisibility.Enabled := False;
//    FadeControlIn(pnlPlayerToolKit);
//    FadeControlIn(labelFileName);
//    Exit;
//  end;
//
//  b := ((dx - 2) <= Screen.MousePos.X) and ((dy - 2) <= Screen.MousePos.Y) and
//       ((dx + 2) >= Screen.MousePos.X) and ((dy + 2) >= Screen.MousePos.Y) and
//       not PointInPanel(pnlPlayerToolKit.AbsoluteRect);
//
//  Animate(pnlPlayerToolKit, 'Opacity', IfThen(b, 0, 1));
//  Animate(labelFileName, 'Opacity', IfThen(b, 0, 1));
//
//  tmrToolKitVisibility.Interval := IfThen(b, 100, 1500);
//
//  if b then
//	rectangleScreen.Cursor := crNone
//  else
//  	rectangleScreen.Cursor := crDefault;
//
//  dx := Screen.MousePos.X;
//  dy := Screen.MousePos.Y;
end;

procedure TfrmPlayer.trackBarPlayingChange(Sender: TObject);
begin
  FillTrackBar(Sender);

  if (FMouseDroped and FPlayer.Paused) then
  begin
    FPlayer.Position := trckbrPlayingState.Value;
    FMouseDroped := False;

    if FPlaying then
      FPlayer.Resume;
  end;
end;

procedure TfrmPlayer.trckbrPlayingStateApplyStyleLookup(Sender: TObject);
var
  obj: TFmxObject;
begin
  FillTrackBar(Sender);

  obj := trckbrPlayingState.FindStyleResource('thumb');
  if Assigned(obj) and (obj is TThumb) then
    with TThumb(obj) do
    begin
      if not Assigned(OnMouseDown) then
        OnMouseDown := trckbrPlayingStateMouseDown;
      if not Assigned(OnMouseUp) then
        OnMouseUp := trckbrPlayingStateThumbMouseUp;
    end;
end;

procedure TfrmPlayer.trckbrPlayingStateMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  FPlayer.Pause;
end;

procedure TfrmPlayer.trckbrPlayingStateMouseUp(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  FMouseDroped := True;
end;

procedure TfrmPlayer.trckbrPlayingStateThumbMouseUp(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  with FPlayer do
    if Paused then
    begin
      Position := trckbrPlayingState.Value;

      if FPlaying then
        Resume;
    end;
end;

(*
 * Обработчик события изменения состояния полосы уровня громкости
 *)

procedure TfrmPlayer.trckbrVolumeChange(Sender: TObject);
begin
  FillTrackBar(Sender);
  btnVolume.Tag := IfThen(trckbrVolume.Value = 0, 1, 0);
  SetIcon(btnVolume, 'pathSound', 'pathMute', btnVolume.Tag = 0);
  FPlayer.Volume := Trunc(trckbrVolume.Value);
end;

(*
 * Обработчик события клика по полосе уровня громкости
 *)

procedure TfrmPlayer.trckbrVolumeClick(Sender: TObject);
begin
  trckbrVolume.TagFloat := trckbrVolume.Value;
end;

(*
 * Обработчик события нажатия клавиши на полосе уровня громкости
 *)

procedure TfrmPlayer.trckbrVolumeKeyUp(Sender: TObject; var Key: Word;
  var KeyChar: Char; Shift: TShiftState);
begin
  TTrackBar(Sender).Value := TTrackBar(Sender).Value + TTrackBar(Sender).Max / 10;
end;

procedure TfrmPlayer.Unlock;
begin
  TMonitor.Exit(FLock);
end;

procedure TfrmPlayer.actFullScreenExecute(Sender: TObject);
begin
  if btnFullScreen.Tag = 1 then
    btnFullScreenClick(btnFullScreen);
end;

(*
 * Обработчик события клика кнопки «Во весь экран»
 *)

procedure TfrmPlayer.btnFullScreenClick(Sender: TObject);
begin
  rectangleScreen.Cursor := crDefault;
  btnFullScreen.Tag := btnFullScreen.Tag xor 1;

  if frmMain.BorderStyle <> TFmxFormBorderStyle.None then
  begin
    FWindowState:= frmMain.WindowState;
    frmMain.ClientToScreen(PointF(0, 0));
    with frmMain do
      FWindowRect := Rect(Left, Top, Left + Width, top + Height);

//    Parent := frmMain.layoutFullScreen;
//    frmMain.layoutFullScreen.Visible := True;
//    frmMain.layoutDefaultScreen.Visible := False;
    tmrToolKitVisibility.Enabled := True;
    tmrCursor.Enabled := True;

    frmMain.BorderStyle := TFmxFormBorderStyle.None;
    frmMain.SetBounds(0, 0, Screen.Size.Width, Screen.Size.Height);
  end else
  begin
//    Parent := frmMain.tabItemPlayer;
//    frmMain.layoutFullScreen.Visible := False;
//    frmMain.layoutDefaultScreen.Visible := True;

    tmrToolKitVisibility.Enabled := False;
    tmrCursor.Enabled := False;
    ShowCursor(True);
    FadeControlIn(pnlPlayerToolKit);
    FadeControlIn(labelFileName);

    frmMain.BorderStyle := TFmxFormBorderStyle.Sizeable;
    if FWindowState = TWindowState.wsMaximized then
      frmMain.WindowState := TWindowState.wsMaximized
    else
      with FWindowRect do
        frmMain.SetBounds(Left, Top, Width, Height);
  end;

  Application.ProcessMessages;
  SetIcon(btnPlay, 'pathPlay', 'pathPause', FPlayer.Paused);
  SetIcon(btnVolume, 'pathSound', 'pathMute', btnVolume.Tag = 0);
  SetIcon(btnFullScreen, 'pathFullScreen', 'pathDefaultScreen', btnFullScreen.Tag = 0);
end;

(*
 * Обработчик события клика кнопки «Громкость»
 *)

procedure TfrmPlayer.btnVolumeClick(Sender: TObject);
begin
  btnVolume.Tag := IfThen(btnVolume.Tag = 0, 1, 0);
  //setButtonIcon(TButton(Sender), 'pathSound', 'pathMute');
//  if (btnVolume.Tag = 1) then
//  begin
//    trckbrVolume.TagFloat := trckbrVolume.Value;
//    Animate(trckbrVolume, 'Value', 0);
//  end else
//    Animate(trckbrVolume, 'Value', trckbrVolume.TagFloat, False, 0.15, TAnimationType.Out);
end;

procedure TfrmPlayer.SetPlayingState(APlaying: Boolean);
begin
  SetIcon(btnPlay, 'pathPlay', 'pathPause', not APlaying);
  SetIcon(pnlState, 'pathPause', 'pathPlay', not APlaying);

  TThread.Synchronize(nil, procedure
    begin
      with pnlState do
      begin
        Width   := 100;
        Height  := 100;
        Opacity := 1;

//        Animate(pnlState, 'Height' , 120, False, 0.3);
//        Animate(pnlState, 'Width'  , 120, False, 0.3);
//        Animate(pnlState, 'Opacity',   0, False, 0.3);
      end;
    end
  );
end;

procedure TfrmPlayer.SetSeeding(const Value: ISeeding);
var
  fillList: TProc;
begin
  Lock;
  try
    Sleep(100);

    FPlayer.Pause;
    FFileItem := nil;
    FPlayer.Stop(True);

    FSeeding := Value;

    fillList := procedure
    begin
      TPrelude.Foreach<IFileItem>(FSeeding.Metafile.Files.ToArray,
        procedure (AItem: IFileItem)
        begin
          lstFiles.Items.Add(Format('%s', [AItem.FilePath{, AItem.FileSize}]));
        end
      );

      lstFiles.Visible := True;
    end;

    if not (ssHaveMetadata in FSeeding.State) then
      frmOverlay.Overlay := otLoading
    else
      fillList;

    FSeeding.OnUpdate := procedure (ASeeding: ISeeding)
    var
      s: Single;
    begin
      s := ASeeding.PercentComplete;

      TThread.Synchronize(nil, procedure
      begin
        pbLoadingState.Value := s;
      end);
    end;

    FSeeding.OnMetadataLoaded := procedure (ASeeding: ISeeding; AMetaFile: IMetaFile)
    begin
      TThread.Synchronize(nil, procedure
      begin
        frmOverlay.Overlay := otNone;

        { показать список файлов }
        fillList;
      end);
    end;
  finally
    Unlock;
  end;
end;

function TfrmPlayer.TimeToString(ATime: Int64): string;
  function f(AValue: Integer): string;
  begin
    Result := Format('%.2d', [AValue]);
  end;
var
  t: TTimeSpan;
begin
  t := TTimeSpan.FromMilliseconds(ATime);
  Result := f(t.Hours) + ':' + f(t.Minutes) + ':' + f(t.Seconds);
end;

procedure TfrmPlayer.FadeControlIn(AControl: TControl);
begin
   AControl.StopPropertyAnimation('Opacity');
   AControl.Opacity := 1;
end;

function TfrmPlayer.CalcRequireSize: Int64;
begin
  Assert(Assigned(FFileItem));

  if Assigned(FFileStream) then
  begin
    Result := Min(Int64(FFileStream.Size - FFileStream.Position), Int64(BuffSize));
    Assert((Result >= 0) and (Result <= FFileStream.Size));
  end else
  begin
    Result := Min(Int64(FFileItem.Size), Int64(BuffSize));
    Assert((Result >= 0) and (Result <= FFileItem.Size));
  end;
end;

constructor TfrmPlayer.Create(AOwner: TComponent);
var
  i, w, h: Integer;
begin
  inherited;

  FLock        := TObject.Create;
  FPlaying     := False;
  FMouseDroped := False;
  FFileStream  := nil;
  FPlayer      := nil;

  FillTrackBar(trckbrVolume);

  w := Screen.Width;
  h := Screen.Height;
  for i := 0 to Screen.DisplayCount - 1 do
  begin
    w := Max(w, Screen.Displays[i].WorkArea.Width);
    h := Max(h, Screen.Displays[i].WorkArea.Height)
  end;

  FPlayer := TVLCPlayer.Create(ExtractFilePath(ParamStr(0)), w, h);
  with FPlayer do
  begin
    OnOpen          := OnPlayerOpen;
    OnRead          := OnPlayerRead;
    OnSeek          := OnPlayerSeek;
    OnClose         := OnPlayerClose;

    OnDisplayFrame  := OnPlayerDisplayFrame;

    OnLengthChanged := OnPlayerLengthChanged;
    OnPositionChanged := OnPlayerPositionChanged;
    OnPlaying       := OnPlayerPlaying;
    OnPaused        := OnPlayerPaused;
    OnEndReached    := OnPlayerEndReached;

//    property OnStopped: TProc<TVLCPlayer> read FOnStopped write FOnStopped;
//    property OnPlaying: TProc<TVLCPlayer> read FOnPlaying write FOnPlaying;
//    property OnStateChanged: TProc<TVLCPlayer> read FOnStateChanged write FOnStateChanged;
  end;
end;

destructor TfrmPlayer.Destroy;
begin
  FPlayer.Free;

  if Assigned(FFileStream) then
    FFileStream.Free;

  FLock.Free;
  inherited;
end;

end.
