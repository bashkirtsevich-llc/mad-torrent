unit Bittorrent.MetaFile;

interface

uses
  System.Classes, System.SysUtils, System.Generics.Collections, System.Math,
  System.IOUtils, System.Types, System.Hash,
  Common.Prelude, Common.SHA1,
  Bittorrent, Basic.UniString, Basic.Bencoding;

type
  TMetafile = class(TInterfacedObject, IMetaFile)
  private
    const
      AnnounceKey     = 'announce';
      AnnounceListKey = 'announce-list';
      InfoKey         = 'info';
      FilesKey        = 'files';
      NameKey         = 'name';
      PathKey         = 'path';
      LengthKey       = 'length';
      PiecesKey       = 'pieces';
      PieceLengthKey  = 'piece length';
  private
    FInfoHash: TUniString;
    FMetadata: TUniString;
    FName: string;
    FFiles: TList<IFileItem>;
    FPieceHashes: TArray<TUniString>;
    FPieceLength: Integer;
    FTotalSize: UInt64;
    FTrackers: TList<string>;

    function GetName: string; inline;
    function GetTotalSize: UInt64; inline;
    function GetPieceHash(APieceIndex: Integer): TUniString; inline;
    function GetPieceLength(APieceIndex: Integer): Integer; inline;
    function GetPieceOffset(APieceIndex: Integer): Int64; inline;
    function GetPiecesCount: Integer; inline;
    function GetPiecesLength: Integer; inline;
    function GetFilesByPiece(APieceIndex: Integer): TArray<IFileItem>;
    function GetFiles: TEnumerable<IFileItem>; inline;
    function GetFilesCount: Integer; inline;
    function GetInfoHash: TUniString; inline;
    function GetMetadata: TUniString;
    function GetTrackers: TEnumerable<string>; inline;
  public
    constructor Create(const AFileName: string); overload;
    constructor Create(AStream: TStream); overload;
    constructor Create(const AMetadata: TUniString); overload;
    destructor Destroy; override;
  end;

implementation

uses
  Bittorrent.FileItem;

{ TMetafile }

constructor TMetafile.Create(const AMetadata: TUniString);
begin
  inherited Create;

  FFiles    := TList<IFileItem>.Create;
  FTrackers := TList<string>.Create;
  FName     := string.Empty;

  BencodeParse(AMetadata, False,
    function (ALen: Integer; AValue: IBencodedValue): Boolean
    var
      infoDict: IBencodedDictionary;
    begin
      Assert(Supports(AValue, IBencodedDictionary));

      infoDict := AValue as IBencodedDictionary;

      if infoDict.ContainsKey(AnnounceKey) then
      begin
        Assert(Supports(infoDict[AnnounceKey], IBencodedString));

        with infoDict[AnnounceKey] as IBencodedString do
          FTrackers.Add(string(Value));
      end;

      if infoDict.ContainsKey(AnnounceListKey) then
      begin
        Assert(Supports(infoDict[AnnounceListKey], IBencodedList));

        TPrelude.Foreach<IBencodedValue>(
          (infoDict[AnnounceListKey] as IBencodedList).Childs.ToArray,
          procedure (AItem1: IBencodedValue)
          begin
            Assert(Supports(AItem1, IBencodedList));

            TPrelude.Foreach<IBencodedValue>(
              (AItem1 as IBencodedList).Childs.ToArray,
              procedure (AItem2: IBencodedValue)
              begin
                Assert(Supports(AItem2, IBencodedString));

                with AItem2 as IBencodedString do
                  if not FTrackers.Contains(string(Value)) then
                    FTrackers.Add(string(Value));
              end);
          end);
      end;

      if infoDict.ContainsKey(InfoKey) then
      begin
        Assert(Supports(infoDict[InfoKey], IBencodedDictionary));
        infoDict := infoDict[InfoKey] as IBencodedDictionary;
      end;

      with infoDict do
      begin
        FMetadata.Assign(Encode);

        FInfoHash := SHA1(FMetadata);

        Assert(ContainsKey(PiecesKey));
        with Items[PiecesKey] as IBencodedString do
          FPieceHashes := Value.Split(SHA1HashLen);

        Assert(ContainsKey(PieceLengthKey));
        with Items[PieceLengthKey] as IBencodedInteger do
          FPieceLength := Value;

        if ContainsKey(NameKey) then
        begin
          Assert(Supports(Items[NameKey], IBencodedString));
          FName := UTF8ToString((Items[NameKey] as IBencodedString).Value.AsRawByteString);
        end;

        FTotalSize := 0;

        if ContainsKey(FilesKey) then
        begin
          { торрент с множеством файлов }
          TPrelude.Foreach<IBencodedValue>(
            (Items[FilesKey] as IBencodedList).Childs.ToArray,
            procedure (AItem: IBencodedValue)
            begin
              Assert(Supports(AItem, IBencodedDictionary));

              with AItem as IBencodedDictionary do
              begin
                Assert(ContainsKey(PathKey) and Supports(Items[PathKey],
                  IBencodedList));
                Assert(ContainsKey(LengthKey) and Supports(Items[LengthKey],
                  IBencodedInteger));

                Inc(FTotalSize, FFiles[FFiles.Add(
                  TFileItem.Create(
                    TPrelude.Fold<IBencodedValue, string>(
                      (Items[PathKey] as IBencodedList).Childs.ToArray,
                      string.Empty, function (X: string; Y: IBencodedValue): string
                      begin
                        Assert(Supports(Y, IBencodedString));

                        Result := X + PathDelim + UTF8ToString(
                          (Y as IBencodedString).Value.AsRawByteString
                        );
                      end),
                    (Items[LengthKey] as IBencodedInteger).Value,
                    FTotalSize,
                    FPieceLength
                  ))].FileSize
                );
              end;
            end
          );
        end else
        if not FName.IsEmpty and ContainsKey(LengthKey) then
        begin
          { торрент с одним файлом }
          Assert(Supports(Items[LengthKey], IBencodedInteger));

          FTotalSize := FFiles[FFiles.Add(TFileItem.Create(
              FName,
              (Items[LengthKey] as IBencodedInteger).Value,
              0,
              FPieceLength)
          )].FileSize;
        end else
          raise EMetafileException.Create('Invalid metafile structure');
      end;

      Result := True;
    end);
end;

constructor TMetafile.Create(const AFileName: string);
var
  fs: TFileStream;
begin
  fs := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    Create(fs);
  finally
    fs.Free;
  end;
end;

constructor TMetafile.Create(AStream: TStream);
var
  md: TUniString;
begin
  md.Len := AStream.Size;
  AStream.Read(md.DataPtr[0]^, AStream.Size);

  Create(md);
end;

destructor TMetafile.Destroy;
begin
  FFiles.Free;
  FTrackers.Free;
  inherited;
end;

function TMetafile.GetFilesCount: Integer;
begin
  Result := FFiles.Count;
end;

function TMetafile.GetFiles: TEnumerable<IFileItem>;
begin
  Result := FFiles;
end;

function TMetafile.GetFilesByPiece(APieceIndex: Integer): TArray<IFileItem>;
var
  it: IFileItem;
  offs, absOffset: UInt64;
begin
  { абсолютное смещение }
  absOffset := UInt64(UInt64(APieceIndex) * UInt64(FPieceLength));

  Assert(absOffset <= FTotalSize);

  for it in FFiles do
  begin
    offs := it.FileOffset + it.FileSize;
    if offs >= absOffset then
      TAppender.Append<IFileItem>(Result, it);

    if offs >= absOffset + FPieceLength then
      Break;
  end;

  Assert(Length(Result) > 0);
end;

function TMetafile.GetInfoHash: TUniString;
begin
  Result := FInfoHash;
end;

function TMetafile.GetMetadata: TUniString;
begin
  Result := FMetadata;
end;

function TMetafile.GetName: string;
begin
  Result := FName;
end;

function TMetafile.GetPieceHash(APieceIndex: Integer): TUniString;
begin
  Result := FPieceHashes[APieceIndex];
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

function TMetafile.GetTrackers: TEnumerable<string>;
begin
  Result := FTrackers;
end;

end.
