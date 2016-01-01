unit Bittorrent.FileSystem;

interface

uses
  System.Classes, System.SysUtils, System.Generics.Collections, System.DateUtils,
  System.Math, System.IOUtils, System.Hash,
  Common.SHA1,
  Bittorrent, Bittorrent.Bitfield,
  Basic.UniString;

type
  TFileSystem = class(TInterfacedObject, IFileSystem)
  private
    const
      FileTTL       = 30; { секунд }
      {$IFDEF PUBL_UTIL}
      PieceTTL      = 1;  { секунд }
      {$ELSE}
      PieceTTL      = 10; { секунд }
      {$ENDIF}
  private
    type
      TFilePoolPair = record
        Stream: TStream;
        LastRequest: TDateTime;
        constructor Create(AStream: TStream; ALastRequest: TDateTime);
      end;

      TPiecePoolPair = record
        Piece: IPiece;
        LastRequest: TDateTime;
        constructor Create(const APiece: IPiece; ALastRequest: TDateTime);
      end;
  protected
    FMetaFile: IMetaFile; { метаинформация }
    FDownloadFolder: string;
  private
    FFileCache: TDictionary<string, TFilePoolPair>;
    {$IFNDEF PUBL_UTIL}
    FPieceCache: TDictionary<Integer, TPiecePoolPair>;
    {$ENDIF}
    FLock: TObject;
    FOnChange: TProc<IFileSystem>;
  private
    procedure Lock; inline;
    procedure Unlock; inline;

    function GetDownloadFolder: string; inline;
    procedure SetDownloadFolder(Value: string); inline;
    function GetOnChange: TProc<IFileSystem>; inline;
    procedure SetOnChange(Value: TProc<IFileSystem>); inline;

    procedure ClearCaches(AFullClear: Boolean = False);
    function CheckFiles: TBitField;

    procedure DeleteFiles;

    function PieceCheck(APiece: IPiece): Boolean;
    procedure PieceWrite(APiece: IPiece);
    function ReadPiece(APieceIndex: Integer): IPiece;
    function GetPiece(APieceIndex: Integer): IPiece; inline;

    function OpenFile(AFileItem: IFileItem): TStream;
  public
    constructor Create(AMetaFile: IMetaFile; const ADownloadFolder: string);
    destructor Destroy; override;
  end;

implementation

uses
  Bittorrent.Piece, Bittorrent.MetaFile;

{ TFileSystem }

procedure TFileSystem.ClearCaches(AFullClear: Boolean = False);
var
  i, j: Integer;
  t: TDateTime;
  s: string;
begin
  { удаляем из пула то, что давно не используется }
  Lock;
  try
    t := Now;
    for i := FFileCache.Keys.Count - 1 downto 0 do //s in FFileCache.Keys do
    begin
      s := FFileCache.Keys.ToArray[i];

      with FFileCache[s] do
        if AFullClear or (SecondsBetween(t, LastRequest) >= FileTTL) then
        begin
          Stream.Free;
          FFileCache.Remove(s);
        end;
    end;

    {$IFNDEF PUBL_UTIL}
    for i := FPieceCache.Keys.Count - 1 downto 0 do
    begin
      j := FPieceCache.Keys.ToArray[i];

      with FPieceCache[j] do
        if AFullClear or (SecondsBetween(t, LastRequest) >= PieceTTL) then
          FPieceCache.Remove(j);
    end;
    {$ENDIF}
  finally
    Unlock;
  end;
end;

constructor TFileSystem.Create(AMetaFile: IMetaFile;
  const ADownloadFolder: string);
begin
  FMetaFile := AMetaFile;
  FDownloadFolder := ADownloadFolder;

  FFileCache := TDictionary<string, TFilePoolPair>.Create;
  {$IFNDEF PUBL_UTIL}
  FPieceCache := TDictionary<Integer, TPiecePoolPair>.Create;
  {$ENDIF}
  FLock := TObject.Create;
end;

procedure TFileSystem.DeleteFiles;
var
  s: string;
begin
  Lock;
  try
    ClearCaches(True);

    s := ExcludeTrailingPathDelimiter(FDownloadFolder);

    if TDirectory.Exists(s) then
      TDirectory.Delete(s, True);
  finally
    Unlock;
  end;
end;

destructor TFileSystem.Destroy;
begin
  // удаляем всё из пула
  ClearCaches(True);

  {$IFNDEF PUBL_UTIL}
  FPieceCache.Free;
  {$ENDIF}
  FFileCache.Free;
  FLock.Free;
  inherited;
end;

function TFileSystem.GetDownloadFolder: string;
begin
  Result := FDownloadFolder;
end;

function TFileSystem.GetOnChange: TProc<IFileSystem>;
begin
  Result := FOnChange;
end;

function TFileSystem.GetPiece(APieceIndex: Integer): IPiece;
var
  it: TPiecePoolPair;
begin
  Lock;
  try
    {$IFNDEF PUBL_UTIL}
    if FPieceCache.ContainsKey(APieceIndex) then
    begin
      it := FPieceCache[APieceIndex];
      it.LastRequest := Now;

      FPieceCache.AddOrSetValue(APieceIndex, it);

      Exit(it.Piece);
    end;
    {$ENDIF}

    Result := ReadPiece(APieceIndex);

    {$IFNDEF PUBL_UTIL}
    if Assigned(Result) then
      FPieceCache.Add(APieceIndex, TPiecePoolPair.Create(Result, Now));
    {$ENDIF}
  finally
    Unlock;
  end;
end;

function TFileSystem.CheckFiles: TBitField;

  procedure NormalizePieceIndex(var APiece: Integer; ASign: TValueSign;
    AItem: IFileItem);
  begin
    {TODO -oMAD -cMedium : проверить скорость работы этой ф-ии, насколько шустро работает FilesByPiece}
//    while True do
//      with FMetaFile.FilesByPiece[APiece] do
//        if IsEmpty or ((Count = 1) and (First.HashCode = AItem.HashCode)) then
//          Break
//        else
//          Inc(APiece, ASign);
  end;

var
  it: IFileItem;
  p: IPiece;
  i, j, k: Integer;
begin
  Assert(Assigned(FMetaFile));

  Result := TBitField.Create(FMetaFile.PiecesCount);

  Lock;
  try
    { проверяем только существующие файлы }
    for it in FMetaFile.Files do
      if TFile.Exists(IncludeTrailingPathDelimiter(FDownloadFolder) + it.FilePath) then
      begin
        j := it.FirstPiece;
        k := it.LastPiece;

        { проверяем только те куски, которые входят в файл целиком, исключая граничные случаи (иначе соседний файл создастся) }
        NormalizePieceIndex(j, PositiveValue, it);
        NormalizePieceIndex(k, NegativeValue, it);

        for i := j to k do
        begin
          p := ReadPiece(i);
          Result[i] := Assigned(p) and PieceCheck(p);
        end;
      end;
  finally
    Unlock;
  end;
end;

function TFileSystem.OpenFile(AFileItem: IFileItem): TStream;
var
  it: TFilePoolPair;
  s: string;
  mode: Word;
begin
  { ищем в пуле }
  s := AFileItem.FilePath;
  if FFileCache.ContainsKey(s) then
  begin
    it := FFileCache[s];
    it.LastRequest := Now; { обновляем время }

    FFileCache.AddOrSetValue(s, it);

    Exit(it.Stream);
  end;

  { создаем/открываем новый }
  s := IncludeTrailingPathDelimiter(FDownloadFolder) + AFileItem.FilePath;
  TDirectory.CreateDirectory(ExtractFilePath(s));
  {$IFDEF PUBL_UTIL}
  Assert(FileExists(s), 'file not exists ' + s);
  Result := TFileStream.Create(s, fmOpenRead or fmShareDenyWrite);
  {$ELSE}
  // открыть файл на чтение и запись с запретом записи извне
  mode := System.Math.IfThen(TFile.Exists(s), fmOpenReadWrite, fmCreate) or fmShareDenyWrite;

  Result := TFileStream.Create(s, mode);

  if mode and fmCreate = fmCreate then
    Result.Size := AFileItem.FileSize;
  {$ENDIF}

  FFileCache.Add(AFileItem.FilePath, TFilePoolPair.Create(Result, Now));
end;

function TFileSystem.PieceCheck(APiece: IPiece): Boolean;
begin
  with APiece do
    Result := SHA1(Data) = FMetaFile.PieceHash[Index];
end;

procedure TFileSystem.PieceWrite(APiece: IPiece);
var
  fi: IFileItem;
  offset: UInt64;
  first: Boolean;
  i, got: Integer;
  buf: TUniString;
begin
  if PieceCheck(APiece) then
  begin
    Lock;
    try
      got := 0;
      first := True;
      buf.Assign(APiece.Data); // почему так?

      for fi in FMetaFile.FilesByPiece[APiece.Index] do
      begin
        { абсолютное смещение куска }
        offset := FMetaFile.PieceOffset[APiece.Index];

        try
          with OpenFile(fi) do
          begin
            { переход на смещение, соответствующее индексу куска }
            if first then
              Position := offset - fi.FileOffset
            else
              Position := 0;

            { запись }
            i := Min(Size - Position, buf.Len - got);
            got := got + Write(buf.DataPtr[got]^, i);
          end;
        except
          on E: Exception do
            raise EFileSystemWriteException.Create(Format('Piece write error (file: %s) - %s', [fi.FilePath, E.Message]));
        end;

        first := False;
      end;

      if Assigned(FOnChange) then
        FOnChange(Self);
    finally
      Unlock;
    end;
  end else
    raise EFileSystemCheckException.CreateFmt('Piece %d corrupted', [APiece.Index]);
end;

function TFileSystem.ReadPiece(APieceIndex: Integer): IPiece;
var
  fi: IFileItem;
  first: Boolean;
  offset: UInt64;
  got: Integer;
  buf: TUniString;
begin
  Lock;
  try
    { абсолютное смещение куска }
    got := 0;
    buf.Len := FMetaFile.PieceLength[APieceIndex];

    offset := FMetaFile.PieceOffset[APieceIndex];

    first := True;
    for fi in FMetaFile.FilesByPiece[APieceIndex] do
    begin
      with OpenFile(fi) do
      begin
        { переход на смещение, соответствующее индексу куска }
        if first then
          Position := offset - fi.FileOffset
        else
          Position := 0;

        { чтение }
        got := got + Read(buf.DataPtr[got]^, buf.Len - got);
      end;

      first := False;
    end;

    Assert(buf.Len = got, 'Unexpected buffer size');

    Result := TPiece.Create(APieceIndex, buf.Len, 0, buf,
      FMetaFile.PieceHash[APieceIndex]);
  finally
    Unlock;
  end;
end;

procedure TFileSystem.Lock;
begin
  System.TMonitor.Enter(FLock);
end;

procedure TFileSystem.SetDownloadFolder(Value: string);
begin
  FDownloadFolder := Value;
end;

procedure TFileSystem.SetOnChange(Value: TProc<IFileSystem>);
begin
  FOnChange := Value;
end;

procedure TFileSystem.Unlock;
begin
  System.TMonitor.Exit(FLock);
end;

{ TFileSystem.TFilePoolTriplet }

constructor TFileSystem.TFilePoolPair.Create(AStream: TStream;
  ALastRequest: TDateTime);
begin
  Stream := AStream;
  LastRequest := ALastRequest;
end;

{ TFileSystem.TPiecePoolPair }

constructor TFileSystem.TPiecePoolPair.Create(const APiece: IPiece;
  ALastRequest: TDateTime);
begin
  Piece := APiece;
  LastRequest := ALastRequest;
end;

end.
