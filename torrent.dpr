program torrent;

uses
  Vcl.Forms,
  main_u in 'main_u.pas' {Form1},
  Basic.UniString in 'Basic.UniString.pas',
  IdIOHandlerHelper in 'IdIOHandlerHelper.pas',
  Common.SortedList in 'Common.SortedList.pas',
  BusyObj in 'BusyObj.pas',
  Bittorrent in 'bittorrent\Bittorrent.pas',
  Bittorrent.Bitfield in 'bittorrent\Bittorrent.Bitfield.pas',
  Bittorrent.Connection in 'bittorrent\Bittorrent.Connection.pas',
  Bittorrent.Extensions in 'bittorrent\Bittorrent.Extensions.pas',
  Bittorrent.FileItem in 'bittorrent\Bittorrent.FileItem.pas',
  Bittorrent.FileSystem in 'bittorrent\Bittorrent.FileSystem.pas',
  Bittorrent.MagnetURI in 'bittorrent\Bittorrent.MagnetURI.pas',
  Bittorrent.Messages in 'bittorrent\Bittorrent.Messages.pas',
  Bittorrent.MetaFile in 'bittorrent\Bittorrent.MetaFile.pas',
  Bittorrent.Peer in 'bittorrent\Bittorrent.Peer.pas',
  Bittorrent.Piece in 'bittorrent\Bittorrent.Piece.pas',
  Bittorrent.PiecePicker in 'bittorrent\Bittorrent.PiecePicker.pas',
  Bittorrent.Seeding in 'bittorrent\Bittorrent.Seeding.pas',
  Bittorrent.Server in 'bittorrent\Bittorrent.Server.pas',
  Bittorrent.Utils in 'bittorrent\Bittorrent.Utils.pas',
  AccurateTimer in 'AccurateTimer.pas',
  Bittorrent.ThreadPool in 'bittorrent\Bittorrent.ThreadPool.pas',
  Basic.Bencoding in 'Basic.Bencoding.pas',
  Bittorrent.Tracker in 'bittorrent\Bittorrent.Tracker.pas',
  Network.URI in 'Network.URI.pas';

{$R *.res}

begin
  ReportMemoryLeaksOnShutdown := True;
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
