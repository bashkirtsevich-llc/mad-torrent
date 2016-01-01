unit Shareman.Bittorrent.FileSystem;

interface

uses
  System.SysUtils,
  Basic.UniString,
  Shareman.FileSystem;

type
  TBTFileSystem = class(TFileSystem)
  protected
    procedure PrepareData(APieceIndex: Integer; var AData: TUniString); override; final;
  end;

implementation

{ TBTFileSystem }

procedure TBTFileSystem.PrepareData(APieceIndex: Integer; var AData: TUniString);
begin
  Assert(AData.Len = FMetaFile.PieceLength[APieceIndex]);
end;

end.
