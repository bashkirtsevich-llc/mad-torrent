program mtp;

uses
  System.StartUpCopy,
  FMX.Forms,
  Forms.Main in 'Forms.Main.pas' {frmMain},
  Basic.Bencoding in 'basic\Basic.Bencoding.pas',
  Basic.BigInteger in 'basic\Basic.BigInteger.pas',
  Basic.UniString in 'basic\Basic.UniString.pas',
  Common.AccurateTimer in 'common\Common.AccurateTimer.pas',
  Common.BusyObj in 'common\Common.BusyObj.pas',
  Common.InterfacedObjHolder in 'common\Common.InterfacedObjHolder.pas',
  Common.Prelude in 'common\Common.Prelude.pas',
  Common.SHA1 in 'common\Common.SHA1.pas',
  Common.SortedList in 'common\Common.SortedList.pas',
  Common.StringHelper in 'common\Common.StringHelper.pas',
  Common.ThreadPool in 'common\Common.ThreadPool.pas',
  DHT in 'dht\DHT.pas',
  DHT.Bucket in 'dht\DHT.Bucket.pas',
  DHT.Common in 'dht\DHT.Common.pas',
  DHT.Engine in 'dht\DHT.Engine.pas',
  DHT.Listener in 'dht\DHT.Listener.pas',
  DHT.Messages in 'dht\DHT.Messages.pas',
  DHT.Messages.MessageLoop in 'dht\DHT.Messages.MessageLoop.pas',
  DHT.Node in 'dht\DHT.Node.pas',
  DHT.NodeID in 'dht\DHT.NodeID.pas',
  DHT.Peer in 'dht\DHT.Peer.pas',
  DHT.RoutingTable in 'dht\DHT.RoutingTable.pas',
  DHT.Tasks in 'dht\DHT.Tasks.pas',
  DHT.Tasks.Events in 'dht\DHT.Tasks.Events.pas',
  DHT.TokenManager in 'dht\DHT.TokenManager.pas',
  Bittorrent in 'bittorrent\Bittorrent.pas',
  Bittorrent.Bitfield in 'bittorrent\Bittorrent.Bitfield.pas',
  Bittorrent.Connection in 'bittorrent\Bittorrent.Connection.pas',
  Bittorrent.Counter in 'bittorrent\Bittorrent.Counter.pas',
  Bittorrent.FileItem in 'bittorrent\Bittorrent.FileItem.pas',
  Bittorrent.FileSystem in 'bittorrent\Bittorrent.FileSystem.pas',
  Bittorrent.Messages in 'bittorrent\Bittorrent.Messages.pas',
  Bittorrent.MetaFile in 'bittorrent\Bittorrent.MetaFile.pas',
  Bittorrent.Peer in 'bittorrent\Bittorrent.Peer.pas',
  Bittorrent.Piece in 'bittorrent\Bittorrent.Piece.pas',
  Bittorrent.PiecePicker in 'bittorrent\Bittorrent.PiecePicker.pas',
  Bittorrent.Seeding in 'bittorrent\Bittorrent.Seeding.pas',
  Bittorrent.SeedingItem in 'bittorrent\Bittorrent.SeedingItem.pas',
  Bittorrent.Server in 'bittorrent\Bittorrent.Server.pas',
  Bittorrent.Tracker in 'bittorrent\Bittorrent.Tracker.pas',
  IdIOHandlerHelper in 'indy\IdIOHandlerHelper.pas',
  Bittorrent.Extensions in 'bittorrent\Bittorrent.Extensions.pas',
  Bittorrent.Tracker.HTTP in 'bittorrent\Bittorrent.Tracker.HTTP.pas',
  Bittorrent.Tracker.DHT in 'bittorrent\Bittorrent.Tracker.DHT.pas',
  Bittorrent.MagnetLink in 'bittorrent\Bittorrent.MagnetLink.pas',
  Bittorrent.Tracker.UDP in 'bittorrent\Bittorrent.Tracker.UDP.pas',
  UDP.Server in 'udp\UDP.Server.pas',
  UDP.Client in 'udp\UDP.Client.pas',
  Frames.Overlay in 'Frames.Overlay.pas',
  Frames.Player in 'Frames.Player.pas',
  VLC.Player in 'vlc\VLC.Player.pas',
  PasLibVlcUnit in 'vlc\PasLibVlcUnit.pas';

{$R *.res}

begin
  ReportMemoryLeaksOnShutdown := True;
  Application.Initialize;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
