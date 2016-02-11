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
    FFirstPiece,
    FLastPiece: Integer;

    function GetFilePath: string; inline;
    function GetFileSize: UInt64; inline;
    function GetFileOffset: UInt64; inline;
    function GetFirstPiece: Integer; inline;
    function GetLastPiece: Integer; inline;
    function GetPiecesCount: Integer; inline;
  public
    constructor Create(const AFilePath: string; const AFileSize,
      AFileOffset: UInt64; APieceLength: Integer);
  end;

implementation

{ TFileItem }

constructor TFileItem.Create(const AFilePath: string; const AFileSize,
  AFileOffset: UInt64; APieceLength: Integer);
begin
  inherited Create;

  Assert(APieceLength > 0);

  FFileParh   := AFilePath;
  FFileSize   := AFileSize;
  FFileOffset := AFileOffset;
  FFirstPiece := AFileOffset div APieceLength;
  FLastPiece  := (AFileOffset + AFileSize) div APieceLength;
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

function TFileItem.GetFirstPiece: Integer;
begin
  Result := FFirstPiece;
end;

function TFileItem.GetLastPiece: Integer;
begin
  Result := FLastPiece;
end;

function TFileItem.GetPiecesCount: Integer;
begin
  Result := FLastPiece - FFirstPiece;
end;

end.
