unit Shareman.Bittorrent.Seeding;

interface

uses
  System.SysUtils,
  Shareman, Shareman.Seeding,
  Basic.UniString,
  IdGlobal;

type
  TBTSeeding = class(TSeeding)
  protected
    function CreatePeer(const AIP: string; APort: Word;
      AIPVer: TIdIPVersion): IPeer; override;
    procedure PrepareWritePiece(APiece: IPiece); override;
    function CreateFileSystem(AMetaFile: IMetaFile;
      const ADownloadFolder: string): IFileSystem; override;
    function CreateTracker(const AURL: string; APort: TIdPort): ITracker; override;
  end;

implementation

uses
  Shareman.Bittorrent.Peer, Shareman.Bittorrent.FileSystem,
  Shareman.Bittorrent.Tracker;

{ TBTSeeding }

function TBTSeeding.CreateFileSystem(AMetaFile: IMetaFile;
  const ADownloadFolder: string): IFileSystem;
begin
  Result := TBTFileSystem.Create(AMetaFile, ADownloadFolder);
end;

function TBTSeeding.CreatePeer(const AIP: string; APort: Word;
  AIPVer: TIdIPVersion): IPeer;
begin
  Result := TBTPeer.Create(FThreadPool, AIP, APort, FInfoHash, FClientID, AIPVer);
end;

function TBTSeeding.CreateTracker(const AURL: string; APort: TIdPort): ITracker;
begin
  Result := TBTTracker.Create(FThreadPool, AURL, FInfoHash, APort, FClientID);
end;

procedure TBTSeeding.PrepareWritePiece(APiece: IPiece);
begin
  { заполнить дерево хешей }
  APiece.HashTree := FMetaFile.PieceHash[APiece.Index]; { костыльное решение для обычных торрентов }
  inherited PrepareWritePiece(APiece);
end;

end.
