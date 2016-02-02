unit Bittorrent.Tracker.UDP;

interface

uses
  System.Classes, System.SysUtils, System.StrUtils,
  Basic.Bencoding, Basic.UniString,
  Common.ThreadPool,
  Bittorrent, Bittorrent.Tracker,
  UDP.Client,
  IdGlobal, IdStack, IdUDPClient, IdBuffer, IdURI, IdIPAddress;

type
  TUDPTrackerAction = (taConnect, taAnnounce, taScrape);

  TUDPTrackerActionHelper = record helper for TUDPTrackerAction
  private
    const
      ActionValues: array[TUDPTrackerAction] of Integer = (0, 1, 2);
  private
    function GetAsInteger: Integer; inline;
  public
    property AsInteger: Integer read GetAsInteger;
  end;

  TUDPTracker = class(TWebTracker, IUDPTracker)
  private
    const
      ConnectionID: Int64 = $041727101980;
  private
    FTrackerURI: TIdURI;
    FKey: Integer;
    FPeerID: TUniString;
    FConnectionID: Int64;
    FTransactionID: Integer;
    FConnected: Boolean;
    FLeechers: Integer;
    FSeeders: Integer;
    procedure GenTransactionID;
    procedure RaiseTrackerNoResponse; inline;
    procedure RaiseTrackerInvalidResponse; inline;
    procedure UDPRequest(ACallback: TProc<TUDPClient>);
  protected
    procedure DoAnnounce; override; final;
    procedure DoRetrack; override; final;
  public
    constructor Create(AThreadPool: TThreadPool; const AInfoHash: TUniString;
      AAnnouncePort: TIdPort; AAnnounceInterval, ARetrackInterval: Integer;
      ATrackerURL: string; const APeerID: TUniString); reintroduce;
    destructor Destroy; override;
  end;

implementation

{ TUDPTrackerActionHelper }

function TUDPTrackerActionHelper.GetAsInteger: Integer;
begin
  Result := ActionValues[Self];
end;

{ TUDPTracker }

constructor TUDPTracker.Create(AThreadPool: TThreadPool;
  const AInfoHash: TUniString; AAnnouncePort: TIdPort; AAnnounceInterval,
  ARetrackInterval: Integer; ATrackerURL: string; const APeerID: TUniString);
begin
  inherited Create(AThreadPool, AInfoHash, AAnnouncePort, AAnnounceInterval,
    ARetrackInterval, ATrackerURL);

  FTrackerURI := TIdURI.Create(ATrackerURL);
  Assert(not FTrackerURI.Port.IsEmpty);

  FPeerID.Assign(APeerID);
  FConnected  := False;
  FKey        := Random(Integer.MaxValue);
end;

destructor TUDPTracker.Destroy;
begin
  FTrackerURI.Free;
  inherited;
end;

procedure TUDPTracker.DoAnnounce;
var
  peerPort: TIdPort;
begin
  try
    UDPRequest(procedure (AUDP: TUDPClient)
    begin
      if not FConnected then
      begin
        GenTransactionID;

        with AUDP do
        begin
          WriteBufferOpen;

          Write(ConnectionID);
          Write(taConnect.AsInteger);
          Write(FTransactionID);

          WriteBufferFlush;

          if not CheckForDataOnSource then
            RaiseTrackerNoResponse
          else
            FConnected := (ReadInt32 = taConnect.AsInteger) and
                          (ReadInt32 = FTransactionID);

          if FConnected then
            FConnectionID := ReadInt64
          else
            RaiseTrackerInvalidResponse;
        end;
      end;

      { Announce }

      with AUDP do
      begin
        WriteBufferOpen;

        Write(FConnectionID);
        Write(taAnnounce.AsInteger);
        Write(FTransactionID);
        WriteUniString(FInfoHash);
        WriteUniString(FPeerID);
        Write(FBytesDownloaded);
        Write(FBytesLeft);
        Write(FBytesUploaded);
        Write(Integer(0));  // event
        Write(Integer(0));  // ip-address
        Write(FKey);        // key
        Write(Integer(-1)); // num_want
        Write(FAnnouncePort);

        WriteBufferFlush;

        if not CheckForDataOnSource then
          RaiseTrackerNoResponse
        else
        if (InputBufferSize < 20) or
           (ReadInt32 <> taAnnounce.AsInteger) or
           (ReadInt32 <> FTransactionID) then
          RaiseTrackerInvalidResponse
        else
        begin
          { announce response }
          FAnnounceInterval := ReadInt32;

          FLeechers := ReadInt32;
          FSeeders  := ReadInt32;

          { peers }
          while not InputBufferIsEmpty and (InputBufferSize mod 6 = 0) do
          begin
            with TIdIPAddress.Create do
            try
              IPv4      := ReadUInt32;
              peerPort  := ReadUInt16;

              ResponsePeerInfo(IPv4AsString, peerPort);
            finally
              Free;
            end;
          end;
        end;
      end;
    end);
  except
    FAnnounceInterval := 60;
  end;

  inherited DoAnnounce;
end;

procedure TUDPTracker.DoRetrack;
begin
  if FConnected then
    UDPRequest(procedure (AUDP: TUDPClient)
    var
      s{, l, c}: Integer;
    begin
      { Scrape }

      with AUDP do
      begin
        WriteBufferOpen;

        Write(FConnectionID);
        Write(taScrape.AsInteger);
        Write(FTransactionID);
        WriteUniString(FInfoHash);

        WriteBufferFlush;

        if not CheckForDataOnSource then
          RaiseTrackerNoResponse
        else
        if (InputBufferSize < 8) or
           (ReadInt32 <> taScrape.AsInteger) or
           (ReadInt32 <> FTransactionID) then
          RaiseTrackerInvalidResponse
        else
        begin
          { scrape response }
          s := ReadInt32;
          {c := ReadInt32;
          l := ReadInt32;}

          { сигналим, что надо сделать реаннонс для получения списка пиров }
          if s > FSeeders then
            FAnnounceInterval := 1;
        end;
      end;
    end);

  inherited DoRetrack;
end;

procedure TUDPTracker.GenTransactionID;
var
  oldTID: Integer;
begin
  oldTID := FTransactionID;
  repeat
    FTransactionID := Random(Integer.MaxValue);
  until FTransactionID <> oldTID;
end;

procedure TUDPTracker.RaiseTrackerInvalidResponse;
begin
  raise ETrackerFailure.Create('UDP tracker invalid response');
end;

procedure TUDPTracker.RaiseTrackerNoResponse;
begin
  raise ETrackerNoResponse.Create('UDP tracker has no response');
end;

procedure TUDPTracker.UDPRequest(ACallback: TProc<TUDPClient>);
var
  udp: TUDPClient;
begin
  Assert(Assigned(ACallback));

  udp := TUDPClient.Create(nil);
  try
    udp.Host := FTrackerURI.Host;
    udp.Port := FTrackerURI.Port.ToInteger;

    udp.Connect;

    ACallback(udp);
  finally
    if udp.Connected then
      udp.Disconnect;

    udp.Free;
  end;
end;

end.
