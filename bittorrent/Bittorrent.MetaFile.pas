unit Bittorrent.MetaFile;

interface

uses
  System.Classes, System.SysUtils, System.Generics.Collections, System.Math,
  Spring.Collections,
  Bittorrent, Bittorrent.Utils,
  Basic.Bencoding, Basic.UniString;

type
  TMetafile = class(TInterfacedObject, IMetaFile)
  private
    const
      InfoKey         = 'info';
      FilesKey        = 'files';
      NameKey         = 'name';
      PathKey         = 'path';
      LengthKey       = 'length';
      PiecesKey       = 'pieces';
      PieceLengthKey  = 'piece length';
  private
    FTotalSize: UInt64;
    FFiles: TList<IFileItem>;
    FPieceLength: Integer;
    FInfoHash: TUniString;
    FInfoDict: IBencodedDictionary;
    FPieceHashes: TList<TUniString>; { список хешей кусоков }
    FMetadataSize: Integer;

    function GetTotalSize: UInt64; inline;
    function GetPieceHash(Index: Integer): TUniString; inline;
    function GetPieceLength(APieceIndex: Integer): Integer; inline;
    function GetPieceOffset(APieceIndex: Integer): Int64; inline;
    function GetPiecesCount: Integer; inline;
    function GetPiecesLength: Integer; inline;
    function GetFilesByPiece(Index: Integer): IList<IFileItem>;
    function GetFiles: TList<IFileItem>; inline;
    function GetInfoHash: TUniString; inline;
    function GetMetadataSize: Integer; inline;
    function GetMetadata: TUniString; inline;

    procedure LoadFromStream(AStream: TStream);
    procedure SaveToStream(AStream: TStream);
  public
    constructor Create(const AFileName: string); overload;
    constructor Create(const AData: TUniString); overload;
    constructor Create(AStream: TStream); overload;
    destructor Destroy; override;
  end;

implementation

uses
  Spring.Collections.Lists, Bittorrent.FileItem;

{ TMetafile }

constructor TMetafile.Create(const AFileName: string);
var
  fs: TFileStream;
begin
  fs := TFileStream.Create(AFileName, fmOpenRead);
  try
    Create(fs);
  finally
    fs.Free;
  end;
end;

constructor TMetafile.Create(const AData: TUniString);
var
  ms: TMemoryStream;
begin
  ms := TMemoryStream.Create;
  try
    ms.Write(AData.DataPtr[0]^, AData.Len);
    ms.Position := 0;
    Create(ms);
  finally
    ms.Free;
  end;
end;

constructor TMetafile.Create(AStream: TStream);
begin
  inherited Create;
  FFiles := System.Generics.Collections.TList<IFileItem>.Create;
  FPieceHashes := System.Generics.Collections.TList<TUniString>.Create;

  LoadFromStream(AStream);
end;

destructor TMetafile.Destroy;
begin
  FFiles.Free;
  FPieceHashes.Free;
  inherited;
end;

function TMetafile.GetFiles: System.Generics.Collections.TList<IFileItem>;
begin
  Result := FFiles;
end;

function TMetafile.GetFilesByPiece(Index: Integer): IList<IFileItem>;
var
  it: IFileItem;
  absOffset: UInt64;
begin
  Result := TList<IFileItem>.Create as IList<IFileItem>;

  absOffset := Index * FPieceLength; { абсолютное смещение }

  Assert(absOffset <= FTotalSize);

  for it in FFiles do
  begin
    if it.FileOffset + it.FileSize >= absOffset then
      Result.Add(it);

    if it.FileOffset + it.FileSize >= absOffset + FPieceLength then
      Break;
  end;

  Assert(Result.Count > 0);
end;

function TMetafile.GetInfoHash: TUniString;
begin
  Result := FInfoHash;
end;

function TMetafile.GetMetadata: TUniString;
begin
  Result := FInfoDict.Encode;
end;

function TMetafile.GetMetadataSize: Integer;
begin
  Result := FMetadataSize;
end;

function TMetafile.GetPieceHash(Index: Integer): TUniString;
begin
  Result.Len := 0;
  Result.Assign(FPieceHashes[Index]);
end;

function TMetafile.GetPieceLength(APieceIndex: Integer): Integer;
var
  offset: UInt64;
begin
  offset := GetPieceOffset(APieceIndex);
  Result := Min(FPieceLength, FTotalSize - offset);
end;

function TMetafile.GetPieceOffset(APieceIndex: Integer): Int64;
begin
  Assert(APieceIndex < GetPiecesCount);
  Result := APieceIndex;
  Result := Result * FPieceLength;
end;

function TMetafile.GetPiecesCount: Integer;
begin
  { надеюсь здесь он их как int64 обработает }
  Result := FTotalSize div Int64(FPieceLength);
  if (FTotalSize mod Int64(FPieceLength)) <> 0 then
    Inc(Result);
end;

function TMetafile.GetPiecesLength: Integer;
begin
  Result := FPieceLength;
end;

function TMetafile.GetTotalSize: UInt64;
begin
  Result := FTotalSize;
end;

procedure TMetafile.LoadFromStream(AStream: TStream);
var
  buf: TUniString;
begin
  FTotalSize := 0;

  FMetadataSize := AStream.Size - AStream.Position;
  buf.Len := FMetadataSize;
  AStream.Read(buf.DataPtr[0]^, FMetadataSize);

  BencodeParse(buf, False,
    function (ALen: Integer; AValue: IBencodedValue): Boolean
    var
      it1, it2: IBencodedValue;
      i: Integer;
      fPath: string;
      fSize: UInt64;
    begin
      Assert(Supports(AValue, IBencodedDictionary));

      FInfoDict := AValue as IBencodedDictionary;
      if FInfoDict.ContainsKey(InfoKey) then
      begin
        Assert(Supports(FInfoDict[InfoKey], IBencodedDictionary));
        FInfoDict := FInfoDict[InfoKey] as IBencodedDictionary;
      end;

      with FInfoDict do
      begin
        FInfoHash := SHA1(Encode);

        Assert(ContainsKey(PiecesKey));
        it1 := (Items[PiecesKey] as IBencodedString);
        with it1 as IBencodedString do
        begin
          Assert(Value.Len mod 20 = 0);
          { проверить, что суммарный объем кусков не превышает размер торрента }

          for i := 0 to (Value.Len div 20) - 1 do
            FPieceHashes.Add(Value.Copy(i*20, 20));
        end;

        Assert(ContainsKey(PieceLengthKey));
        it1 := (Items[PieceLengthKey] as IBencodedInteger);
        FPieceLength := (it1 as IBencodedInteger).Value;

        if ContainsKey(FilesKey) then
        begin
          for it1 in (Items[FilesKey] as IBencodedList).Childs do
          begin
            Assert(Supports(it1, IBencodedDictionary));
            with it1 as IBencodedDictionary do
            begin
              fPath := '';

              Assert(ContainsKey(PathKey));
              Assert(Supports(Items[PathKey], IBencodedList));

              { вычленяем путь }
              for it2 in (Items[PathKey] as IBencodedList).Childs do
              begin
                Assert(Supports(it2, IBencodedString));
                fPath := fPath + PathDelim + (it2 as IBencodedString).Value.AsString;
              end;

              Assert(ContainsKey(LengthKey));
              fSize := (Items[LengthKey] as IBencodedInteger).Value;

              // FTotalSize в данном случае есть абсолютное смещение
              FFiles.Add(TFileItem.Create(fPath, fSize, FTotalSize) as IFileItem);
              Inc(FTotalSize, fSize);
            end;
          end;
        end else
        begin
          if ContainsKey(NameKey) and ContainsKey(LengthKey) then
          begin
            { торрент с одним файлом }
            Assert(Supports(Items[NameKey], IBencodedString));

            fPath := (Items[NameKey] as IBencodedString).Value;
            Assert(Supports(Items[LengthKey], IBencodedInteger));

            fSize := (Items[LengthKey] as IBencodedInteger).Value;
            FFiles.Add(TFileItem.Create(fPath, fSize, FTotalSize) as IFileItem);
            Inc(FTotalSize, fSize);
          end else
            raise Exception.Create('Invalid metafile structure');
        end;
      end;

      Result := True;
    end);
end;

procedure TMetafile.SaveToStream(AStream: TStream);
var
  data: TUniString;
begin
  data := GetMetadata;
  AStream.Write(data.DataPtr[0]^, data.Len);
end;

end.
