unit Forms.Main;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  System.Hash,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  FMX.Controls.Presentation, FMX.StdCtrls,
  Basic.UniString,
  Common.SHA1,
  Bittorrent, Bittorrent.MetaFile, Bittorrent.MagnetLink, FMX.Edit;

type
  TfrmMain = class(TForm)
    btn1: TButton;
    edtMagnet: TEdit;
    procedure FormCreate(Sender: TObject);
    procedure btn1Click(Sender: TObject);
  private
    bt: IBittorrent;
  public
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.fmx}

procedure TfrmMain.btn1Click(Sender: TObject);
begin
  //magnet:?xt=urn:btih:b3a069319e7b1decd26cdcd3b7c1c1fb0a38b21d
  //magnet:?xt=urn:btih:F9B40E91088D78F922989C9458AAE8495AA4ADC5
  //magnet:?xt=urn:btih:520A9A81C1F854271002CE80CF6A24D105FE5699
  //magnet:?xt=urn:btih:501ec472144d20a4461c08f3305d138db6f3a534
  //magnet:?xt=urn:btih:afa82991982331cb7d0dd03b6994f7718dac696b
  bt.AddTorrent(TMagnetLink.Create(edtMagnet.Text), 'c:\downloads')
    .OnMetadataLoaded := procedure (ASeeding: ISeeding; AMetaFile: IMetaFile)
    var
      fs: TFileStream;
      md: TUniString;
    begin
      fs := TFileStream.Create(AMetaFile.InfoHash.ToHexString + '.torrent', fmCreate);
      try
        md := AMetaFile.Metadata;
        fs.Write(md.DataPtr[0]^, md.Len);
      finally
        fs.Free;
      end;
    end;
end;

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  bt := TBittorrent.Create('MT-12345678912345678', 12346, 12346);
  bt.Start;
end;

end.
