unit Bittorrent.FileItem;

interface

uses
  Bittorrent;

type
  TFileItem = class sealed(TInterfacedObject, IFileItem)
  private
    FFileParh: string;
    FFileSize,
    FFileOffset: UInt64;
//    FFirstPiece,
//    FLastPiece: Cardinal; { для выборочной загрузки файлов }
    function GetFilePath: string; inline;
    function GetFileSize: UInt64; inline;
    function GetFileOffset: UInt64; inline;
  public
    constructor Create(const AFilePath: string; const AFileSize,
      AFileOffset: UInt64);
  end;

implementation

{ TFileItem }

constructor TFileItem.Create(const AFilePath: string; const AFileSize,
  AFileOffset: UInt64);
begin
  inherited Create;

  FFileParh   := AFilePath;
  FFileSize   := AFileSize;
  FFileOffset := AFileOffset;
end;

function TFileItem.GetFilePath: string;
begin
  Result := FFileParh;
end;

function TFileItem.GetFileOffset: UInt64;
begin
  Result := FFileOffset;
end;

function TFileItem.GetFileSize: UInt64;
begin
  Result := FFileSize;
end;

end.
