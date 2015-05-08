unit Bittorrent.Piece;

interface

uses
  System.SysUtils, System.Generics.Collections,
  Basic.UniString,
  Bittorrent;

type
  TPiece = class(TInterfacedObject, IPiece)
  public
    const
      BlockLength = $4000;
  private
    FIndex: Integer; { индекс куска }
    FPieceLength: Integer; { размер куска }
    FBlocks: TDictionary<Integer, TUniString>; { список блоков (каждый по 16кб) }

    function GetCompleted: Boolean;
    procedure AddBlock(AOffset: Integer; const AData: TUniString);
    function GetData: TUniString;
    function GetPieceLength: Integer; inline;
    function GetIndex: Integer; inline;
  public
    constructor Create(AIndex, APieceLength, AOffset: Integer;
      const AData: TUniString);
    destructor Destroy; override;
  end;

implementation

{ TPiece }

procedure TPiece.AddBlock(AOffset: Integer; const AData: TUniString);
begin
  FBlocks.Add(AOffset, AData);
end;

constructor TPiece.Create(AIndex, APieceLength, AOffset: Integer;
  const AData: TUniString);
begin
  inherited Create;

  FIndex        := AIndex;
  FPieceLength  := APieceLength;
  FBlocks       := System.Generics.Collections.TDictionary<Integer, TUniString>.Create;

  Assert((AData.Len > 0) and (AData.Len <= APieceLength));
  AddBlock(AOffset, AData);
end;

destructor TPiece.Destroy;
begin
  FBlocks.Free;
  inherited;
end;

function TPiece.GetData: TUniString;
var
  offset: Integer;
begin
  Assert(GetCompleted, 'Piece is not completed yet');

  { собираем всё вместе }
  Result.Len := FPieceLength;
  for offset in FBlocks.Keys do
    Result.Insert(offset, FBlocks[offset]);
end;

function TPiece.GetIndex: Integer;
begin
  Result := FIndex;
end;

function TPiece.GetCompleted: Boolean;
var
  offset, size: Integer;
begin
  { проверем размер (надо бы еще проверять адекватность оффсетов) }
  size := 0;
  for offset in FBlocks.Keys do
    Inc(size, FBlocks[offset].Len);

  Result := size = FPieceLength;
end;

function TPiece.GetPieceLength: Integer;
begin
  Result := FPieceLength;
end;

end.
