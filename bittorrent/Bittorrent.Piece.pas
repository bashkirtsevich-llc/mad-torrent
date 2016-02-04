unit Bittorrent.Piece;

interface

uses
  System.SysUtils, System.Generics.Collections, System.Math,
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
    function ContainsBlock(AOffset: Integer): Boolean; inline;
    procedure AddBlock(AOffset: Integer; const AData: TUniString); inline;
    function GetData: TUniString;
    function GetPieceLength: Integer; inline;
    function GetIndex: Integer; inline;
    procedure EnumBlocks(ACallBack: TProc<Integer, Integer>); overload; inline;
  public
    class procedure EnumBlocks(APieceLength: Integer;
      ACallBack: TProc<Integer, Integer>); overload;
  public
    constructor Create(AIndex, APieceLength, AOffset: Integer;
      const AData: TUniString); reintroduce;
    destructor Destroy; override;
  end;

implementation

{ TPiece }

procedure TPiece.AddBlock(AOffset: Integer; const AData: TUniString);
begin
  if not ContainsBlock(AOffset) then
    FBlocks.Add(AOffset, AData.Copy);
end;

function TPiece.ContainsBlock(AOffset: Integer): Boolean;
begin
  Result := FBlocks.ContainsKey(AOffset);
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

procedure TPiece.EnumBlocks(ACallBack: TProc<Integer, Integer>);
begin
  TPiece.EnumBlocks(FPieceLength, ACallBack);
end;

class procedure TPiece.EnumBlocks(APieceLength: Integer;
  ACallBack: TProc<Integer, Integer>);
var
  offset, size, len: Integer;
begin
  Assert(Assigned(ACallBack));
  Assert(APieceLength > 0);

  offset:= 0;
  size  := APieceLength;

  while size > 0 do
  begin
    len := Min(TPiece.BlockLength, size);
    ACallBack(offset, len);

    Inc(offset, len);
    Dec(size  , len);
  end;
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
