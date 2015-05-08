unit Bittorrent.FileSystem;

interface

uses
  System.Classes, System.SysUtils, System.Generics.Collections, System.DateUtils,
  System.Math,
  Bittorrent, Bittorrent.Bitfield, Bittorrent.Utils, Basic.UniString;

type
  TFileSystem = class(TInterfacedObject, IFileSystem)
  private
    const
      FileTTL       = 30; { секунд }
      PieceTTL      = 5;  { секунд }
  private
    type
      TFilePoolTriplet = record
        FilePath: string;
        Stream: TStream;
        LastRequest: TDateTime;
        constructor Create(const AFilePath: string; AStream: TStream;
          ALastRequest: TDateTime);
      end;

      TPiecePoolPair = record
        Piece: IPiece;
        LastRequest: TDateTime;
        constructor Create(const APiece: IPiece; ALastRequest: TDateTime);
      end;
  private
    FMetaFile: IMetaFile; { метаинформация }
    FDownloadFolder: string;
    FFileCache: TList<TFilePoolTriplet>;
    FPieceCache: TList<TPiecePoolPair>;
    FLock: TObject;
    FOnChange: TProc<IFileSystem>;
  private
    procedure Lock; inline;
    procedure Unlock; inline;

    function GetDownloadFolder: string; inline;
    procedure SetDownloadFolder(Value: string); inline;
    function GetOnChange: TProc<IFileSystem>; inline;
    procedure SetOnChange(Value: TProc<IFileSystem>); inline;

    procedure ClearCaches;
    function CheckFiles: TBitField;

    procedure DeleteFiles;

    function PieceCheck(APiece: IPiece): Boolean; inline;
    procedure PieceWrite(APiece: IPiece);
    function GetPiece(APieceIndex: Integer): IPiece;

    function OpenFile(AFileItem: IFileItem): TStream;
  public
    constructor Create(AMetaFile: IMetaFile; const ADownloadFolder: string);
    destructor Destroy; override;
  end;

implementation

uses
  Bittorrent.Piece, Bittorrent.MetaFile;

{ TFileSystem }

procedure TFileSystem.ClearCaches;
var
  i: Integer;
begin
  { удаляем из пула то, что давно не используется }
  Lock;
  try
    for i := FFileCache.Count - 1 downto 0 do
      with FFileCache[i] do
        if SecondsBetween(UtcNow, LastRequest) >= FileTTL then
        begin
          Stream.Free;
          FFileCache.Delete(i);
        end;

    for i := FPieceCache.Count - 1 downto 0 do
      with FPieceCache[i] do
        if SecondsBetween(UtcNow, LastRequest) >= PieceTTL then
          FPieceCache.Delete(i);
  finally
    Unlock;
  end;
end;

constructor TFileSystem.Create(AMetaFile: IMetaFile;
  const ADownloadFolder: string);
begin
  FMetaFile := AMetaFile;
  FDownloadFolder := ADownloadFolder;

  FFileCache := TList<TFilePoolTriplet>.Create;
  FPieceCache := TList<TPiecePoolPair>.Create;
  FLock := TObject.Create;
end;

procedure TFileSystem.DeleteFiles;
var
  it: IFileItem;
  s: string;
begin
  Lock;
  try
    ClearCaches;

    for it in FMetaFile.Files do
    begin
      s := IncludeTrailingPathDelimiter(FDownloadFolder) + it.FilePath;
      //FileSetAttr(s, 0);
      DeleteFile(s);
    end;
  finally
    Unlock;
  end;
end;

destructor TFileSystem.Destroy;
var
  it: TFilePoolTriplet;
begin
  // удаляем всё из пула
  for it in FFileCache do
    it.Stream.Free;

  FPieceCache.Free;
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
  i: Integer;
  it: TPiecePoolPair;
  fi: IFileItem;
  first: Boolean;
  offset: UInt64;
  got: Integer;
  buf: TUniString;
begin
  Lock;
  try
    for i := 0 to FPieceCache.Count - 1 do
    begin
      it := FPieceCache[i];
      if it.Piece.Index = APieceIndex then
      begin
        it.LastRequest := UtcNow;
        FPieceCache[i] := it;
        Exit(it.Piece);
      end;
    end;

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

    Assert(buf.Len = got, 'unexpected buffer size');
    Result := TPiece.Create(APieceIndex, buf.Len, 0, buf);

    FPieceCache.Add(TPiecePoolPair.Create(Result, UtcNow));
  finally
    Unlock;
  end;
end;

function TFileSystem.CheckFiles: TBitField;
var
  p: IPiece;
  i: Integer;
begin
  Assert(Assigned(FMetaFile));

  Result := TBitField.Create(FMetaFile.PiecesCount);

  Lock;
  try
    i := 0;
    while i < FMetaFile.PiecesCount do
    begin
      // надо пропускать только что созданные файлы, на них падает скорость
      p := GetPiece(i);
      Result[i] := Assigned(p) and PieceCheck(p);
      Inc(i);
    end;
  finally
    Unlock;
  end;
end;

function TFileSystem.OpenFile(AFileItem: IFileItem): TStream;
var
  it: TFilePoolTriplet;
  i: Integer;
  s: string;
begin
  { ищем в пуле }
  for i := 0 to FFileCache.Count - 1 do
  begin
    it := FFileCache[i];

    if it.FilePath = AFileItem.FilePath then
    begin
      it.LastRequest := UtcNow; { обновляем время }
      FFileCache[i] := it;
      Exit(it.Stream);
    end;
  end;

  { создаем/открываем новый }
  s := IncludeTrailingPathDelimiter(FDownloadFolder) + AFileItem.FilePath;
  ForceDirectories(ExtractFilePath(s));
  Result := TFileStream.Create(s, System.Math.IfThen(FileExists(s), fmOpenReadWrite,
    fmCreate));
  Result.Size := AFileItem.FileSize;

  FFileCache.Add(TFilePoolTriplet.Create(AFileItem.FilePath, Result, UtcNow));
end;

function TFileSystem.PieceCheck(APiece: IPiece): Boolean;
begin
  Result := FMetaFile.PieceHash[APiece.Index] = SHA1(APiece.Data);
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

constructor TFileSystem.TFilePoolTriplet.Create(const AFilePath: string;
  AStream: TStream; ALastRequest: TDateTime);
begin
  FilePath := AFilePath;
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
