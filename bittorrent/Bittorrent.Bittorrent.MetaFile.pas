unit Shareman.Bittorrent.MetaFile;

interface

uses
  System.Classes, System.SysUtils, System.Generics.Collections,
  Basic.UniString, Basic.Bencoding,
  Hash, Hash.Merkle, Hash.SHA1,
  Shareman.MetaFile;

type
  TBTMetaFile = class(TMetafile)
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
  public
    constructor Create(const AFileName: string); overload;
    constructor Create(const AData: TUniString); overload;
    constructor Create(AStream: TStream); overload;
  end;

implementation

{ TBTMetaFile }

constructor TBTMetaFile.Create(const AFileName: string);
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

constructor TBTMetaFile.Create(const AData: TUniString);
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

constructor TBTMetaFile.Create(AStream: TStream);
var
  iHash, uHash, pHash: TUniString;
  digest: TMerkleHashDigest;
  pieceLen: Integer;
  files, tr: TList<string>;
begin
  files := TList<string>.Create;
  tr    := TList<string>.Create;
  try
    {$REGION 'BencodeParse'}
    BencodeParse(AStream, False,
      function (ALen: Integer; AValue: IBencodedValue): Boolean
      var
        it1, it2: IBencodedValue;
        fPath, s: string;
        fSize: UInt64;
        infoDict: IBencodedDictionary;
        i: Integer;
        ctx: TMerkleHashContext;
        tmp: TUniString;
        tail: TArray<TUniString>;
      begin
        Assert(Supports(AValue, IBencodedDictionary));

        infoDict := AValue as IBencodedDictionary;

        if infoDict.ContainsKey(AnnounceKey) then
        begin
          Assert(Supports(infoDict[AnnounceKey], IBencodedString));

          s := (infoDict[AnnounceKey] as IBencodedString).Value;
          if s.Contains('http://') then
            tr.Add(s);
        end;

        if infoDict.ContainsKey(AnnounceListKey) then
        begin
          Assert(Supports(infoDict[AnnounceListKey], IBencodedList));

          for it1 in (infoDict[AnnounceListKey] as IBencodedList).Childs do
          begin
            Assert(Supports(it1, IBencodedList));

            for it2 in (it1 as IBencodedList).Childs do
            begin
              Assert(Supports(it2, IBencodedString));

              with (it2 as IBencodedString) do
              begin
                s := Value;

                if s.Contains('http://') and not tr.Contains(s) then
                  tr.Add(s);
              end;
            end;
          end;
        end;

        if infoDict.ContainsKey(InfoKey) then
        begin
          Assert(Supports(infoDict[InfoKey], IBencodedDictionary));
          infoDict := infoDict[InfoKey] as IBencodedDictionary;
        end;

        with infoDict do
        begin
          iHash := SHA1(Encode);

          Assert(ContainsKey(PiecesKey));
          it1 := (Items[PiecesKey] as IBencodedString);
          with it1 as IBencodedString do
          begin
            Assert(Value.Len mod TMetafile.HashLen = 0);
            { перевод в хеш мёркла }
            MerkleHashInit(ctx, procedure(AHash: TMerkleHashDigest; ALevel: Integer)
            begin
              if ALevel+1 > Length(tail) then
                SetLength(tail, ALevel+1);

              tail[ALevel] := tail[ALevel] + MerkleHashDigestToUniString(AHash);
            end);

            Assert(value.Len mod HashLen = 0);
            SetLength(tail, 1);

            for i := 0 to value.Len div HashLen - 1 do
            begin
              tmp := value.Copy(i * HashLen, HashLen);
              tail[0] := tail[0] + tmp;

              Move(tmp.DataPtr[0]^, digest, HashLen);
              MerkleHashAdd(ctx, digest);
            end;

            uHash := MerkleHashDigestToUniString(MerkleHashFinal(ctx));

            for i := Length(tail)-1 downto 0 do
              pHash := pHash + tail[i];
          end;

          Assert(ContainsKey(PieceLengthKey));
          it1 := (Items[PieceLengthKey] as IBencodedInteger);
          pieceLen := (it1 as IBencodedInteger).Value;

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
                  fPath := fPath + PathDelim + UTF8ToString(((it2 as IBencodedString).Value.AsRawByteString));
                end;

                Assert(ContainsKey(LengthKey));
                fSize := (Items[LengthKey] as IBencodedInteger).Value;

                files.Add(Format('%s|%x', [fPath, fSize]));
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

              files.Add(Format('%s|%x', [fPath, fSize]));
            end else
              raise Exception.Create('Invalid metafile structure');
          end;
        end;

        Result := True;
      end);
      {$ENDREGION}

    inherited Create(iHash, uHash, pHash, files.ToArray, pieceLen);

    FTrackers.AddRange(tr.ToArray);
  finally
    files.Free;
    tr.Free;
  end;
end;

end.
