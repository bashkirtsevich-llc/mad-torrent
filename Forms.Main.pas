unit Forms.Main;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  System.Hash,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  FMX.Controls.Presentation, FMX.StdCtrls,
  Basic.UniString,
  Common.SHA1,
  Bittorrent, Bittorrent.MetaFile, Bittorrent.MagnetLink, FMX.Edit,
  FMX.TabControl, FMX.ExtCtrls, FMX.ListView.Types, FMX.ListView, FMX.Layouts,
  FMX.ListBox, Frames.Overlay, Frames.Player;

type
  TfrmMain = class(TForm)
    tbcPages: TTabControl;
    tbtmAdd: TTabItem;
    tbtmPlayer: TTabItem;
    edtMagnet: TEdit;
    btnAddMagnet: TButton;
    frmPlayer: TfrmPlayer;
    procedure FormCreate(Sender: TObject);
    procedure btnAddMagnetClick(Sender: TObject);
    procedure lstFilesDblClick(Sender: TObject);
  private
    bt: IBittorrent;
  public
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.fmx}

procedure TfrmMain.btnAddMagnetClick(Sender: TObject);
begin
  frmPlayer.Seeding := bt.AddTorrent(TMagnetLink.Create(edtMagnet.Text), 'e:\downloads');

  { переброс на страницу плеера }
  tbtmPlayer.IsSelected := True;
end;

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  bt := TBittorrent.Create('MT-12345678912345678', 12346, 12346);
  bt.Start;
end;

procedure TfrmMain.lstFilesDblClick(Sender: TObject);
begin
//
end;

end.
