program mtp;

uses
  System.StartUpCopy,
  FMX.Forms,
  Forms.Main in 'Forms.Main.pas' {frmMain},
  Frames.Overlay in 'Frames.Overlay.pas' {frmOverlay: TFrame},
  Frames.Player in 'Frames.Player.pas' {frmPlayer: TFrame},
  VLC.Player in 'vlc\VLC.Player.pas',
  PasLibVlcUnit in 'vlc\PasLibVlcUnit.pas',
  Basic.Bencoding in 'lib\libmadtorrent\src\basic\Basic.Bencoding.pas',
  Basic.BigInteger in 'lib\libmadtorrent\src\basic\Basic.BigInteger.pas',
  Basic.UniString in 'lib\libmadtorrent\src\basic\Basic.UniString.pas',
  Bittorrent.Bitfield in 'lib\libmadtorrent\src\bittorrent\Bittorrent.Bitfield.pas',
  Bittorrent.Connection in 'lib\libmadtorrent\src\bittorrent\Bittorrent.Connection.pas',
  Bittorrent.Counter in 'lib\libmadtorrent\src\bittorrent\Bittorrent.Counter.pas',
  Bittorrent.Extensions in 'lib\libmadtorrent\src\bittorrent\Bittorrent.Extensions.pas',
  Bittorrent.FileItem in 'lib\libmadtorrent\src\bittorrent\Bittorrent.FileItem.pas',
  Bittorrent.FileSystem in 'lib\libmadtorrent\src\bittorrent\Bittorrent.FileSystem.pas',
  Bittorrent.MagnetLink in 'lib\libmadtorrent\src\bittorrent\Bittorrent.MagnetLink.pas',
  Bittorrent.Messages in 'lib\libmadtorrent\src\bittorrent\Bittorrent.Messages.pas',
  Bittorrent.MetaFile in 'lib\libmadtorrent\src\bittorrent\Bittorrent.MetaFile.pas',
  Bittorrent in 'lib\libmadtorrent\src\bittorrent\Bittorrent.pas',
  Bittorrent.Peer in 'lib\libmadtorrent\src\bittorrent\Bittorrent.Peer.pas',
  Bittorrent.Piece in 'lib\libmadtorrent\src\bittorrent\Bittorrent.Piece.pas',
  Bittorrent.PiecePicker in 'lib\libmadtorrent\src\bittorrent\Bittorrent.PiecePicker.pas',
  Bittorrent.Seeding in 'lib\libmadtorrent\src\bittorrent\Bittorrent.Seeding.pas',
  Bittorrent.SeedingItem in 'lib\libmadtorrent\src\bittorrent\Bittorrent.SeedingItem.pas',
  Bittorrent.Server in 'lib\libmadtorrent\src\bittorrent\Bittorrent.Server.pas',
  Bittorrent.Tracker.DHT in 'lib\libmadtorrent\src\bittorrent\Bittorrent.Tracker.DHT.pas',
  Bittorrent.Tracker.HTTP in 'lib\libmadtorrent\src\bittorrent\Bittorrent.Tracker.HTTP.pas',
  Bittorrent.Tracker in 'lib\libmadtorrent\src\bittorrent\Bittorrent.Tracker.pas',
  Bittorrent.Tracker.UDP in 'lib\libmadtorrent\src\bittorrent\Bittorrent.Tracker.UDP.pas',
  Common.AccurateTimer in 'lib\libmadtorrent\src\common\Common.AccurateTimer.pas',
  Common.BusyObj in 'lib\libmadtorrent\src\common\Common.BusyObj.pas',
  Common.InterfacedObjHolder in 'lib\libmadtorrent\src\common\Common.InterfacedObjHolder.pas',
  Common.Prelude in 'lib\libmadtorrent\src\common\Common.Prelude.pas',
  Common.SHA1 in 'lib\libmadtorrent\src\common\Common.SHA1.pas',
  Common.SortedList in 'lib\libmadtorrent\src\common\Common.SortedList.pas',
  Common.StringHelper in 'lib\libmadtorrent\src\common\Common.StringHelper.pas',
  Common.ThreadPool in 'lib\libmadtorrent\src\common\Common.ThreadPool.pas',
  DHT.Bucket in 'lib\libmadtorrent\src\dht\DHT.Bucket.pas',
  DHT.Common in 'lib\libmadtorrent\src\dht\DHT.Common.pas',
  DHT.Engine in 'lib\libmadtorrent\src\dht\DHT.Engine.pas',
  DHT.Listener in 'lib\libmadtorrent\src\dht\DHT.Listener.pas',
  DHT.Messages.MessageLoop in 'lib\libmadtorrent\src\dht\DHT.Messages.MessageLoop.pas',
  DHT.Messages in 'lib\libmadtorrent\src\dht\DHT.Messages.pas',
  DHT.Node in 'lib\libmadtorrent\src\dht\DHT.Node.pas',
  DHT.NodeID in 'lib\libmadtorrent\src\dht\DHT.NodeID.pas',
  DHT in 'lib\libmadtorrent\src\dht\DHT.pas',
  DHT.Peer in 'lib\libmadtorrent\src\dht\DHT.Peer.pas',
  DHT.RoutingTable in 'lib\libmadtorrent\src\dht\DHT.RoutingTable.pas',
  DHT.Tasks.Events in 'lib\libmadtorrent\src\dht\DHT.Tasks.Events.pas',
  DHT.Tasks in 'lib\libmadtorrent\src\dht\DHT.Tasks.pas',
  DHT.TokenManager in 'lib\libmadtorrent\src\dht\DHT.TokenManager.pas',
  IdIOHandlerHelper in 'lib\libmadtorrent\src\indy\IdIOHandlerHelper.pas',
  UDP.Client in 'lib\libmadtorrent\src\udp\UDP.Client.pas',
  UDP.Server in 'lib\libmadtorrent\src\udp\UDP.Server.pas';

{$R *.res}

begin
  ReportMemoryLeaksOnShutdown := True;
  Application.Initialize;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
