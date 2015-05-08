unit ThreadPool;

interface

uses
  System.SysUtils, System.DateUtils,
  System.Generics.Collections, System.Generics.Defaults,
  AccurateTimer,
  IdYarn, IdTask, IdSchedulerOfThreadPool, IdSchedulerOfThread;

type
  TThreadPool = class
  private
    type
      TTask = class(TIdTask)
      protected
        FOnRun: TFunc<TTask, Boolean>;
        FOnBeforeRun: TProc<TTask>;
        FOnAfterRun: TProc<TTask>;
        FOnException: TProc<TTask, Exception>;

        procedure BeforeRun; override;
        function Run: Boolean; override;
        procedure AfterRun; override;
        procedure HandleException(AException: Exception); override;
      public
        constructor Create(AYarn: TIdYarn;
          AOnRun: TFunc<TTask, Boolean>;
          AOnBeforeRun: TProc<TTask>;
          AOnAfterRun: TProc<TTask>;
          AOnException: TProc<TTask, Exception>); reintroduce;
      end;

      TJob = class
      private
        FOwner: TThreadPool;
        FYarn: TIdYarn;
        FTask: TTask;
        FOnRun: TFunc<Boolean>;
        FOnExcept: TProc<Exception>;
      public
        procedure Exec; inline;

        constructor Create(AOwner: TThreadPool);
        destructor Destroy; override;
      end;

      TConveyerElement = class
      private
        FExecTime: TDateTime;
        FOnRun: TFunc<Boolean>;
        FOnExcept: TProc<Exception>;
      public
        property ExecTime: TDateTime read FExecTime {write FExecTime};
        property OnRun: TFunc<Boolean> read FOnRun {write FOnRun};
        property OnExcept: TProc<Exception> read FOnExcept {write FOnExcept};

        constructor Create(AExecTime: TDateTime; AOnRun: TFunc<Boolean>;
          AOnExcept: TProc<Exception>);
      end;
  private
    FPool: TIdSchedulerOfThreadPool;
    FConveyers: TObjectDictionary<Integer, TObjectList<TConveyerElement>>;
    FLock: TObject;
    procedure Lock; inline;
    procedure Unlock; inline;

    procedure KickStart(AConveyer: Integer);

    function NewJob: TJob; inline;

    procedure WaitForFreeThreads; { ждать до первого свободного треда }
  public
    procedure Exec(AOnRun: TFunc<Boolean {Reloop}>); overload; { если результат ложный, то завершаем цикл }
    procedure Exec(AOnRun: TFunc<Boolean>; AOnExcept: TProc<Exception>); overload;

    procedure Exec(AConveyer: Integer; AOnRun: TFunc<Boolean>); overload;
    procedure Exec(AConveyer: Integer; AOnRun: TFunc<Boolean>;
      AOnExcept: TProc<Exception>); overload;

    procedure Schedule(AConveyer: Integer; ADelayMSec: Integer; AOnRun: TFunc<Boolean>); overload; inline;
    procedure Schedule(AConveyer: Integer; ADelayMSec: Integer; AOnRun: TFunc<Boolean>;
      AOnExcept: TProc<Exception>); overload;

    //property Pool: TIdSchedulerOfThreadPool read FPool;

    constructor Create(AMaxThreads: Integer = 100; APoolSize: Integer = 50);
    destructor Destroy; override;
  end;

implementation

function DateTimeToMilliseconds(const ADateTime: TDateTime): Int64; inline;
var
  LTimeStamp: TTimeStamp;
begin
  LTimeStamp := DateTimeToTimeStamp(ADateTime);
  Result := LTimeStamp.Date;
  Result := (Result * MSecsPerDay) + LTimeStamp.Time;
end;

{ TThreadPool }

constructor TThreadPool.Create(AMaxThreads, APoolSize: Integer);
begin
  FLock := TObject.Create;
  FConveyers := TObjectDictionary<Integer, TObjectList<TConveyerElement>>.Create([doOwnsValues]);

  FPool := TIdSchedulerOfThreadPool.Create(nil);
  FPool.MaxThreads := AMaxThreads;
  FPool.PoolSize := APoolSize;
  FPool.Init;
end;

destructor TThreadPool.Destroy;
begin
  FPool.TerminateAllYarns;

  FLock.Free;
  FConveyers.Free;
  FPool.Free;
  inherited;
end;

procedure TThreadPool.Exec(AOnRun: TFunc<Boolean>;
  AOnExcept: TProc<Exception>);
var
  job: TJob;
begin
  Lock;
  try
    WaitForFreeThreads;

    job := NewJob;
    job.FOnRun := AOnRun;
    job.FOnExcept := AOnExcept;
    job.Exec;
  finally
    Unlock;
  end;
end;

procedure TThreadPool.Lock;
begin
  TMonitor.Enter(FLock);
end;

procedure TThreadPool.Exec(AOnRun: TFunc<Boolean>);
begin
  Exec(AOnRun, nil);
end;

function TThreadPool.NewJob: TJob;
begin
  Result := TJob.Create(Self);
end;

procedure TThreadPool.Schedule(AConveyer: Integer; ADelayMSec: Integer;
  AOnRun: TFunc<Boolean>);
begin
  Schedule(AConveyer, ADelayMSec, AOnRun, nil);
end;

procedure TThreadPool.Schedule(AConveyer: Integer; ADelayMSec: Integer;
  AOnRun: TFunc<Boolean>; AOnExcept: TProc<Exception>);
begin
  Lock;
  try
    Assert(ADelayMSec >= 0);

    if not FConveyers.ContainsKey(AConveyer) then
    begin
      FConveyers.Add(AConveyer,
        TObjectList<TConveyerElement>.Create(
          TDelegatedComparer<TConveyerElement>.Create(
            function (const ALeft, ARight: TConveyerElement): Integer
            begin
              // самые долгоотложенные в начало
              Result := DateTimeToMilliseconds(ARight.ExecTime) - DateTimeToMilliseconds(ALeft.ExecTime);
            end
          ) as IComparer<TConveyerElement>));

      KickStart(AConveyer);
    end;

    with FConveyers[AConveyer] do
    begin
      if ADelayMSec > 0 then
        Add(TConveyerElement.Create(IncMilliSecond(Now, ADelayMSec), AOnRun, AOnExcept))
      else
        Add(TConveyerElement.Create(ADelayMSec, AOnRun, AOnExcept));

      FConveyers[AConveyer].Sort;
    end;
  finally
    Unlock;
  end;
end;

procedure TThreadPool.Unlock;
begin
  TMonitor.Exit(FLock);
end;

procedure TThreadPool.WaitForFreeThreads;
begin
  Lock;
  try
    while FPool.ActiveYarns.Count > FPool.MaxThreads do
      DelayMicSec(100);
  finally
    Unlock;
  end;
end;

procedure TThreadPool.Exec(AConveyer: Integer; AOnRun: TFunc<Boolean>);
begin
  Exec(AConveyer, AOnRun, nil);
end;

procedure TThreadPool.Exec(AConveyer: Integer; AOnRun: TFunc<Boolean>;
  AOnExcept: TProc<Exception>);
begin
  Schedule(AConveyer, 0, AOnRun, AOnExcept);
end;

procedure TThreadPool.KickStart(AConveyer: Integer);
begin
  Exec(function : Boolean
  var
    i: Integer;
    it: TConveyerElement;
  begin
    Result  := False;
    it      := nil;

    Lock;
    try
      if not FConveyers.ContainsKey(AConveyer) then
        Exit
      else
      if FConveyers[AConveyer].Count = 0 then
      begin
        FConveyers.Remove(AConveyer);
        Exit;
      end else
      begin
        with FConveyers[AConveyer] do
          for i := 0 to Count - 1 do
          begin
            it := Items[i];

            if (it.ExecTime = 0) or (CompareDateTime(Now, it.ExecTime) >= 0) then
              Break
            else
              it := nil;
          end;
      end;
    finally
      Unlock;
    end;

    if Assigned(it) then
    begin
      try
        while it.FOnRun() do;
      except
        on E: Exception do
          if Assigned(it.OnExcept) then
            it.OnExcept(E);
      end;

      Lock;
      try
        FConveyers[AConveyer].Remove(it);
      finally
        Unlock;
      end;
    end;

    DelayMicSec(100);
    Result := True;
  end);
end;

{ TThreadPool.TTask }

procedure TThreadPool.TTask.AfterRun;
begin
  inherited;

  if Assigned(FOnAfterRun) then
    FOnAfterRun(Self);
end;

procedure TThreadPool.TTask.BeforeRun;
begin
  inherited;

  if Assigned(FOnBeforeRun) then
    FOnBeforeRun(Self);
end;

constructor TThreadPool.TTask.Create(AYarn: TIdYarn; AOnRun: TFunc<TTask, Boolean>;
  AOnBeforeRun, AOnAfterRun: TProc<TTask>; AOnException: TProc<TTask, Exception>);
begin
  Assert(Assigned(TIdYarnOfThread(AYarn).Thread));
  inherited Create(AYarn);
  Assert(Assigned(TIdYarnOfThread(AYarn).Thread));

  FOnRun        := AOnRun;
  FOnBeforeRun  := AOnBeforeRun;
  FOnAfterRun   := AOnAfterRun;
  FOnException  := AOnException;
end;

procedure TThreadPool.TTask.HandleException(AException: Exception);
begin
  inherited;

  if Assigned(FOnException) then
    FOnException(Self, AException);
end;

function TThreadPool.TTask.Run: Boolean;
begin
  Result := False;

  if Assigned(FOnRun) then
    Result := FOnRun(Self);
end;

{ TThreadPoolEx.TJob }

constructor TThreadPool.TJob.Create(AOwner: TThreadPool);
begin
  FOwner := AOwner;

  FYarn := AOwner.FPool.AcquireYarn;

  Assert(Assigned(FYarn));
  Assert(Assigned(TIdYarnOfThread(FYarn).Thread));

  FTask := TTask.Create(FYarn,
    function (ASender: TTask): Boolean // run
    begin
      Result := False;

      if Assigned(FOnRun) then
      try
        Result := FOnRun;
      except
        on E: Exception do
        begin
          if Assigned(FOnExcept) then
            FOnExcept(E);

          raise;
        end;
      end;
    end, nil {before},
    procedure (ASender: TTask) // after
    begin
      Free;
    end, nil {on except}
  );

  Assert(Assigned(TIdYarnOfThread(FYarn).Thread));
end;

destructor TThreadPool.TJob.Destroy;
begin
  FOwner.Lock;
  try
    FOwner.FPool.TerminateYarn(FYarn);
  finally
    FOwner.Unlock;
  end;
  inherited;
end;

procedure TThreadPool.TJob.Exec;
begin
  Assert(Assigned(FOwner.FPool));
  Assert(Assigned(FYarn));
  Assert(Assigned(FTask));

  Assert(Assigned(FYarn));
  Assert(Assigned(TIdYarnOfThread(FYarn).Thread));
  FOwner.FPool.StartYarn(FYarn, FTask);
end;

{ TThreadPoolEx.TConveyerElement }

constructor TThreadPool.TConveyerElement.Create(AExecTime: TDateTime;
  AOnRun: TFunc<Boolean>; AOnExcept: TProc<Exception>);
begin
  FExecTime := AExecTime;
  FOnRun    := AOnRun;
  FOnExcept := AOnExcept;
end;

end.
