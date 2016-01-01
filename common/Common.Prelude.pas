unit Common.Prelude;

interface

uses
  System.SysUtils, System.StrUtils, System.Generics.Collections,
  System.Generics.Defaults;

type
  TPrelude = class sealed
  public
    { Fold (FoldL only) }
    class function Fold<T>(const AData: TArray<T>; const AInitial: T;
      ACallBack: TFunc<T, T, T>): T; overload; static; inline;
    class function Fold<T, TResult>(const AData: TArray<T>; const AInitial: TResult;
      ACallBack: TFunc<TResult, T, TResult>): TResult; overload; static;
    { Map }
    class function Map<T>(const AData: TArray<T>;
      ACallBack: TFunc<T, T>): TArray<T>; overload; static; inline;
    class function Map<T, TResult>(const AData: TArray<T>;
      ACallBack: TFunc<T, TResult>): TArray<TResult>; overload; static;
    { foreach }
    class procedure Foreach<T>(const AData: TArray<T>; ACallBack: TProc<T>); static;
    { GroupBy }
    class function GroupBy<T>(const AData: TArray<T>;
      ACallBack: TFunc<T, T, Boolean>): TArray<TArray<T>>; static;
    { Sort }
    class function Sort<T>(const AData: TArray<T>;
      AComparer: IComparer<T>): TArray<T>; static; inline;
    { Filter }
    class function Filter<T>(const AData: TArray<T>;
      ACallBack: TPredicate<T>): TArray<T>; static;
  end;

  TAppender = class sealed
    class procedure Append<T>(var Arr: TArray<T>; Value: T); static; inline;
  end;

function ConcatList(const ASeparator: string = sLineBreak): TFunc<string, string, string>;

implementation

function ConcatList(const ASeparator: string = sLineBreak): TFunc<string, string, string>;
begin
  Result := function (X, Y: string): string
  begin
    Result := X + IfThen(not X.IsEmpty, ASeparator) + Y;
  end;
end;

{ TPrelude }

class function TPrelude.Fold<T>(const AData: TArray<T>; const AInitial: T;
  ACallBack: TFunc<T, T, T>): T;
begin
  Result := TPrelude.Fold<T, T>(AData, AInitial, ACallBack);
end;

class procedure TPrelude.Foreach<T>(const AData: TArray<T>;
  ACallBack: TProc<T>);
var
  it: T;
begin
  Assert(Assigned(ACallBack));

  for it in AData do
    ACallBack(it);
end;

class function TPrelude.GroupBy<T>(const AData: TArray<T>;
  ACallBack: TFunc<T, T, Boolean>): TArray<TArray<T>>;
var
  it: T;
begin
  Assert(Assigned(ACallBack));

  SetLength(Result, 0, 0);

  for it in AData do
  begin
    if (Length(Result) > 0) and ACallBack(Result[Length(Result) - 1][0], it) then
    begin
      SetLength(Result[Length(Result) - 1], Length(Result[Length(Result) - 1]) + 1);
      Result[Length(Result) - 1][Length(Result[Length(Result) - 1]) - 1] := it; // append
    end else
    begin
      SetLength(Result, Length(Result) + 1);
      SetLength(Result[Length(Result) - 1], 1);
      Result[Length(Result) - 1, 0] := it; // add
    end;
  end;
end;

class function TPrelude.Filter<T>(const AData: TArray<T>;
  ACallBack: TPredicate<T>): TArray<T>;
var
  it: T;
begin
  Assert(Assigned(ACallBack));

  SetLength(Result, 0);

  for it in AData do
    if ACallBack(it) then
      TAppender.Append<T>(Result, it);
end;

class function TPrelude.Fold<T, TResult>(const AData: TArray<T>;
  const AInitial: TResult; ACallBack: TFunc<TResult, T, TResult>): TResult;
var
  it: T;
begin
  Assert(Assigned(ACallBack));

  Result := AInitial;

  for it in AData do
    Result := ACallBack(Result, it);
end;

class function TPrelude.Map<T>(const AData: TArray<T>;
  ACallBack: TFunc<T, T>): TArray<T>;
begin
  Result := TPrelude.Map<T, T>(AData, ACallBack);
end;

class function TPrelude.Sort<T>(const AData: TArray<T>;
  AComparer: IComparer<T>): TArray<T>;
begin
  Result := Copy(AData, 0, Length(AData));
  TArray.Sort<T>(Result, AComparer);
end;

class function TPrelude.Map<T, TResult>(const AData: TArray<T>;
  ACallBack: TFunc<T, TResult>): TArray<TResult>;
var
  i: Integer;
begin
  Assert(Assigned(ACallBack));

  SetLength(Result, Length(AData));

  for i := 0 to Length(AData) - 1 do
    Result[i] := ACallBack(AData[i]);
end;

{ TAppender }

class procedure TAppender.Append<T>(var Arr: TArray<T>; Value: T);
begin
  SetLength(Arr, Length(Arr) + 1);
  Arr[High(Arr)] := Value;
end;

end.
