unit Bittorrent.SeedingItem;

interface

uses
  System.Classes, System.SysUtils,
  Bittorrent, Bittorrent.Bitfield,
  IdGlobal;

type
  TSeedingItem = class(TInterfacedObject, ISeedingItem)
  private
    FPriority: TFilePriority;
    FDownloadPath: string;
    FFileItem: IFileItem;
    FPieceLength: Integer;
    FOnGetBitField: TProc<TProc<TBitField>>;
    FOnGetStates: TFunc<ISeedingItem, TSeedingStates>;
    FOnRequire: TFunc<ISeedingItem, Int64, Int64, Boolean>;

    function GetPriority: TFilePriority; inline;
    procedure SetPriority(const Value: TFilePriority); inline;
    function GetPath: string; inline;
    function GetSize: Int64; inline;
    function GetFirstPiece: Integer; inline;
    function GetLastPiece: Integer; inline;
    function GetPiecesCount: Integer; inline;
    function GetPercentComplete: Double;

    procedure CheckArguments(AOffset, ALength: Int64); inline;

    function IsLoaded(AOffset, ALength: Int64): Boolean;
    function Require(AOffset, ALength: Int64): Boolean;
  public
    constructor Create(const ADownloadPath: string; AFileItem: IFileItem;
      APieceLength: Integer; AOnGetBitField: TProc<TProc<TBitField>>;
      AOnGetStates: TFunc<ISeedingItem, TSeedingStates>;
      AOnRequire: TFunc<ISeedingItem, Int64, Int64, Boolean>); reintroduce;
  end;

implementation

{ TSeedingItem }

procedure TSeedingItem.CheckArguments(AOffset, ALength: Int64);
begin
  Assert(Assigned(FFileItem) and
         (AOffset >= 0) and (AOffset <= FFileItem.FileSize) and
         (ALength >= 0) and (AOffset + ALength <= FFileItem.FileSize));
end;

constructor TSeedingItem.Create(const ADownloadPath: string;
  AFileItem: IFileItem; APieceLength: Integer;
  AOnGetBitField: TProc<TProc<TBitField>>;
  AOnGetStates: TFunc<ISeedingItem, TSeedingStates>;
  AOnRequire: TFunc<ISeedingItem, Int64, Int64, Boolean>);
begin
  inherited Create;

  FDownloadPath   := ADownloadPath;
  FFileItem       := AFileItem;
  FPieceLength    := APieceLength;

  Assert(Assigned(AOnGetBitField));
  FOnGetBitField  := AOnGetBitField;
  FOnGetStates    := AOnGetStates;
  FOnRequire      := AOnRequire;

  FPriority       := fpNormal;
end;

function TSeedingItem.GetPercentComplete: Double;
var
  reslt: Double;
begin
  Assert(Assigned(FOnGetBitField));

  FOnGetBitField(
    procedure (ABitField: TBitField)
    begin
      with FFileItem do
        reslt := ABitField.CheckedCountInRange(FirstPiece, LastPiece) / PiecesCount * 100;
    end);

  Result := reslt;
end;

function TSeedingItem.GetFirstPiece: Integer;
begin
  Result := FFileItem.FirstPiece;
end;

function TSeedingItem.GetLastPiece: Integer;
begin
  Result := FFileItem.LastPiece;
end;

function TSeedingItem.GetPiecesCount: Integer;
begin
  Result := FFileItem.PiecesCount;
end;

function TSeedingItem.GetPath: string;
begin
  Result := IncludeTrailingPathDelimiter(FDownloadPath) + FFileItem.FilePath;
end;

function TSeedingItem.GetPriority: TFilePriority;
begin
  Result := FPriority;
end;

function TSeedingItem.GetSize: Int64;
begin
  Result := FFileItem.FileSize;
end;

function TSeedingItem.IsLoaded(AOffset, ALength: Int64): Boolean;
var
  reslt: Boolean;
begin
  CheckArguments(AOffset, ALength);

  if FPriority <> fpSkip then
  begin
    Assert(Assigned(FOnGetBitField));
    Assert(Assigned(FOnGetStates));

    Result := ssCompleted in FOnGetStates(Self); { оптимизация }
    if not Result then
    begin
      FOnGetBitField(
        procedure (ABitField: TBitField)
        var
          i: Int64;
        begin
          reslt := True;
          i     := 0;

          while reslt and (i < ALength) do
          begin
            reslt := reslt and ABitField[FFileItem.FirstPiece + ((i + AOffset) div FPieceLength)];
            Inc(i, FPieceLength);
          end;
        end);

      Result := reslt;
    end;
  end else
    Result := False;
end;

function TSeedingItem.Require(AOffset, ALength: Int64): Boolean;
begin
  CheckArguments(AOffset, ALength);

  Result := FPriority <> fpSkip;
  if Result then
  begin
    Assert(Assigned(FOnRequire));
    Result := FOnRequire(Self, AOffset, ALength);
  end;
end;

procedure TSeedingItem.SetPriority(const Value: TFilePriority);
begin
  FPriority := Value;
end;

end.
