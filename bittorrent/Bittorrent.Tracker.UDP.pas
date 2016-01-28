unit Bittorrent.Tracker.UDP;

interface

uses
  System.Classes, System.SysUtils, System.StrUtils,
  Basic.Bencoding, Basic.UniString,
  Common.ThreadPool,
  Bittorrent, Bittorrent.Tracker,
  UDP.Client,
  IdGlobal, IdStack, IdUDPClient, IdBuffer, IdURI;

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
    FTransactionID: Integer;
    FConnected: Boolean;
    procedure GenTransactionID;
  protected
    procedure DoAnnounce; override; final;
    procedure DoRetrack; override; final;
  public
    constructor Create(AThreadPool: TThreadPool; const AInfoHash: TUniString;
      AAnnouncePort: TIdPort; AAnnounceInterval, ARetrackInterval: Integer;
      ATrackerURL: string); reintroduce;
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
  ARetrackInterval: Integer; ATrackerURL: string);
begin
  inherited Create(AThreadPool, AInfoHash, AAnnouncePort, AAnnounceInterval,
    ARetrackInterval, ATrackerURL);

  FTrackerURI := TIdURI.Create(ATrackerURL);
  FConnected  := False;
end;

destructor TUDPTracker.Destroy;
begin
  FTrackerURI.Free;
  inherited;
end;

procedure TUDPTracker.DoAnnounce;
var
  udp: TUDPClient;
begin
  try
    udp := TUDPClient.Create(nil);
    try
      udp.Host := FTrackerURI.Host;
      udp.Port := FTrackerURI.Port.ToInteger;

      if not FConnected then
      begin
        GenTransactionID;

        with udp do
        begin
          WriteBufferOpen;

          Write(ConnectionID);
          Write(TUDPTrackerAction.taConnect.AsInteger);
          Write(FTransactionID);

          WriteBufferFlush;

          if CheckForDataOnSource then
          begin
            if (ReadInt32 <> TUDPTrackerAction.taConnect.AsInteger) or
               (ReadInt32 <> FTransactionID) or
               (ReadInt64 <> ConnectionID) then
              raise ETrackerFailure.Create('UDP tracker invalid response');
          end else
            raise ETrackerNoResponse.Create('UDP tracker has no response');
        end;
      end;

      { Announce }

    finally
      udp.Free;
    end;
  except
    FAnnounceInterval := 60;
  end;
end;

procedure TUDPTracker.DoRetrack;
begin

end;

procedure TUDPTracker.GenTransactionID;
var
  oldTID: Integer;
begin
  oldTID := FTransactionID;
  repeat
    FTransactionID := Random(Integer.MaxValue);
  until (FTransactionID = oldTID);
end;

end.
