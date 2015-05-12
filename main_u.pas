unit main_u;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  System.DateUtils,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  Bittorrent, Bittorrent.Bitfield, Bittorrent.ThreadPool, Basic.UniString;

type
  TForm1 = class(TForm)
    btn2: TButton;
    btn3: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure btn2Click(Sender: TObject);
    procedure btn3Click(Sender: TObject);
  private
    torrent: TBittorrent;
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

procedure TForm1.btn2Click(Sender: TObject);
var
  s: string;
  ihash: TUniString;
begin
  s := IncludeTrailingPathDelimiter(
    ExtractFilePath(ParamStr(0))
  ) + 'test';
  ihash := torrent.AddTorrent('E:\uTorrent\games.torrent', s);

  torrent.AddPeer(ihash, '127.0.0.1', 62402);
  torrent.Start;
end;

procedure TForm1.btn3Click(Sender: TObject);
var
  s: string;
  ihash: TUniString;
begin
  s := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + 'test';
  ihash := torrent.AddTorrent('4F4E8F9F72FC50974324A38BD2FA73B5A6FAB655.torrent', s);

  s := s + '_2';
  ihash := torrent.AddMagnetURI('magnet:?xt=urn:btih:A86F6AA42F1A748673E9E6053CCD2792EC3527B3&dn=%21torrent_test', s);

  torrent.Start;
end;

procedure TForm1.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  torrent.Free;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  torrent := TBittorrent.Create(0 {47494});
end;

end.
