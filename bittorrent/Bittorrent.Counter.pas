unit Bittorrent.Counter;

interface

uses
  System.Classes, System.SysUtils, System.DateUtils, System.Math,
  Bittorrent;

type
  TCounter = class(TInterfacedObject, ICounter, IMutableCounter)
  private
    const
      Interval: Double = 1; // секунда
      GroupLen = 5;
  private
    FLastUpdate: TDateTime;

    FTotalDownloaded: UInt64;
    FTotalUploaded: UInt64;

    // для выдачи наружу
    FDownloadSpeed: Single;
    FUploadSpeed: Single;

    // для внутренней калькуляции
    FDownSpeed: Single;
    FUpSpeed: Single;
    FDownSpeedGroup: TArray<Single>;
    FUpSpeedGroup: TArray<Single>;

    FLock: TObject;

    function GetTotalDownloaded: UInt64; inline;
    function GetTotalUploaded: UInt64; inline;
    function GetDownloadSpeed: Single; inline;
    function GetUploadSpeed: Single; inline;

    procedure Update(const ADownloaded, AUploaded: UInt64); inline;
    procedure Add(const ADownloaded, AUploaded: UInt64); inline;
    procedure ResetSpeed; inline;
  public
    constructor Create;
    destructor Destroy; override;
  end;

implementation

{ TCounter }

procedure TCounter.Add(const ADownloaded, AUploaded: UInt64);
begin
  TMonitor.Enter(FLock);
  try
    Update(FTotalDownloaded + ADownloaded, FTotalUploaded + AUploaded);
  finally
    TMonitor.Exit(FLock);
  end;
end;

constructor TCounter.Create;
begin
  inherited Create;

  FLastUpdate       := Now;
  FTotalDownloaded  := 0;
  FTotalUploaded    := 0;
  FDownloadSpeed    := 0.0;
  FUploadSpeed      := 0.0;

  FLock             := TObject.Create;
end;

destructor TCounter.Destroy;
begin
  FLock.Free;
  inherited;
end;

function TCounter.GetDownloadSpeed: Single;
begin
  Result := FDownloadSpeed;
end;

function TCounter.GetTotalDownloaded: UInt64;
begin
  Result := FTotalDownloaded;
end;

function TCounter.GetTotalUploaded: UInt64;
begin
  Result := FTotalUploaded;
end;

function TCounter.GetUploadSpeed: Single;
begin
  Result := FUploadSpeed;
end;

procedure TCounter.ResetSpeed;
begin
  FDownSpeed  := 0.0;
  FUpSpeed    := 0.0;

  FLastUpdate := Now;
end;

procedure TCounter.Update(const ADownloaded, AUploaded: UInt64);

  procedure AddGroup(var AGroup: TArray<Single>; AValue: Single); inline;
  begin
    if Length(AGroup) < GroupLen then
      SetLength(AGroup, Length(AGroup) + 1)
    else
    begin
      Delete(AGroup, Low(AGroup), 1);
      SetLength(AGroup, Length(AGroup) + 1);
    end;

    AGroup[High(AGroup)] := AValue;
  end;

var
  dDelta, uDelta: UInt64;
  span: Double;
begin
  TMonitor.Enter(FLock);
  try
    Assert(ADownloaded >= FTotalDownloaded );
    Assert(AUploaded   >= FTotalUploaded   );

    dDelta  := ADownloaded - FTotalDownloaded;
    uDelta  := AUploaded   - FTotalUploaded;

    FTotalDownloaded  := ADownloaded;
    FTotalUploaded    := AUploaded;

    span := SecondSpan(Now, FLastUpdate);
    if span >= Interval then
    begin
      AddGroup(FDownSpeedGroup, FDownSpeed / span);
      AddGroup(FUpSpeedGroup  , FUpSpeed   / span);

      // выдаем среднее значение за промежуток (не дольше, чем grouplen)
      FDownloadSpeed:= Mean(FDownSpeedGroup);
      FUploadSpeed  := Mean(FUpSpeedGroup);

      ResetSpeed;
    end;

    FDownSpeed      := FDownSpeed + dDelta;
    FUpSpeed        := FUpSpeed   + uDelta;
  finally
    TMonitor.Exit(FLock);
  end;
end;

end.
