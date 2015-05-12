{***************************************************************************}
{                                                                           }
{           Spring Framework for Delphi                                     }
{                                                                           }
{           Copyright (c) 2009-2013 Spring4D Team                           }
{                                                                           }
{           http://www.spring4d.org                                         }
{                                                                           }
{***************************************************************************}
{                                                                           }
{  Licensed under the Apache License, Version 2.0 (the "License");          }
{  you may not use this file except in compliance with the License.         }
{  You may obtain a copy of the License at                                  }
{                                                                           }
{      http://www.apache.org/licenses/LICENSE-2.0                           }
{                                                                           }
{  Unless required by applicable law or agreed to in writing, software      }
{  distributed under the License is distributed on an "AS IS" BASIS,        }
{  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. }
{  See the License for the specific language governing permissions and      }
{  limitations under the License.                                           }
{                                                                           }
{***************************************************************************}

unit Spring.Collections.Lists;

interface

uses
  Generics.Defaults,
  Generics.Collections,
  Spring.Collections,
  Spring.Collections.Base;

type

  ///	<summary>
  ///	  Provides an array-based implementation of IList{T}.
  ///	</summary>
  TList<T> = class(TListBase<T>)
  private
    fItems: array of T;
    fCount: Integer;
  protected
    function GetCapacity: Integer;
    function GetCount: Integer; override;
    function GetItem(index: Integer): T; override;
    procedure SetCapacity(value: Integer);
    procedure SetItem(index: Integer; const value: T); override;
    procedure DoInsert(index: Integer; const item: T); override;
    procedure DoDelete(index: Integer; notification: TCollectionChangedAction); override;
    procedure DoDeleteRange(startIndex, count: Integer; notification: TCollectionChangedAction); override;
    procedure DoSort(const comparer: IComparer<T>); override;
    function EnsureCapacity(value: Integer): Integer;
    property Capacity: Integer read GetCapacity write SetCapacity;
  public
    procedure Clear; override;
    procedure Exchange(index1, index2: Integer); override;
    procedure Move(currentIndex, newIndex: Integer); override;
    procedure Reverse; override;
  end;

  TObjectList<T: class> = class(TList<T>, ICollectionOwnership)
  private
    fOwnsObjects: Boolean;
    function GetOwnsObjects: Boolean;
    procedure SetOwnsObjects(const value: Boolean);
  protected
    procedure Changed(const item: T; action: TCollectionChangedAction); override;
  public
    constructor Create(ownsObjects: Boolean = True); overload;
    constructor Create(const comparer: IComparer<T>; ownsObjects: Boolean = True); overload;
    constructor Create(collection: TEnumerable<T>; ownsObjects: Boolean = True); overload;

    property OwnsObjects: Boolean read GetOwnsObjects write SetOwnsObjects;
  end;

implementation

uses
  SysUtils,
  Spring;


{$REGION 'TList<T>'}

function TList<T>.GetCount: Integer;
begin
  Result := fCount;
end;

function TList<T>.GetItem(index: Integer): T;
begin
  Guard.CheckRange((index >= 0) and (index < Count), 'index');

  Result := fItems[index];
end;

procedure TList<T>.SetItem(index: Integer; const value: T);
var
  oldItem: T;
begin
  Guard.CheckRange((index >= 0) and (index < Count), 'index');

  oldItem := fItems[index];
  fItems[index] := value;

  Changed(oldItem, caRemoved);
  Changed(value, caAdded);
end;

procedure TList<T>.DoInsert(index: Integer; const item: T);
begin
  EnsureCapacity(Count + 1);
  if index <> Count then
  begin
    System.Move(fItems[index], fItems[index + 1], (Count - index) * SizeOf(T));
    FillChar(fItems[index], SizeOf(fItems[index]), 0);
  end;
  fItems[index] := item;
  Inc(fCount);
  Changed(item, caAdded);
end;

procedure TList<T>.DoDelete(index: Integer;
  notification: TCollectionChangedAction);
var
  oldItem: T;
begin
  Assert((index >= 0) and (index <= Count));

  oldItem := fItems[index];
  fItems[index] := Default(T);
  Dec(fCount);
  if index <> Count then
  begin
    System.Move(fItems[index + 1], fItems[index], (Count - index) * SizeOf(T));
    FillChar(fItems[Count], SizeOf(T), 0);
  end;
  Changed(oldItem, notification);
end;

procedure TList<T>.DoDeleteRange(startIndex, count: Integer;
  notification: TCollectionChangedAction);
var
  oldItems: array of T;
  tailCount,
  i: Integer;
begin
  SetLength(oldItems, count);
  System.Move(fItems[startIndex], oldItems[0], count * SizeOf(T));

  tailCount := Self.Count - (startIndex + count);
  if tailCount > 0 then
  begin
    System.Move(fItems[startIndex + count], fItems[startIndex], tailCount * SizeOf(T));
    FillChar(fItems[Self.Count - count], count * SizeOf(T), 0);
  end
  else
  begin
    FillChar(fItems[startIndex], count * SizeOf(T), 0);
  end;
  Dec(fCount, count);

  for i := 0 to Length(oldItems) - 1 do
  begin
    Changed(oldItems[i], caRemoved);
  end;
end;

procedure TList<T>.DoSort(const comparer: IComparer<T>);
begin
  TArray.Sort<T>(fItems, comparer, 0, Count);
end;

procedure TList<T>.Move(currentIndex, newIndex: Integer);
var
  temp: T;
begin
  temp := fItems[currentIndex];
  fItems[currentIndex] := Default(T);
  if currentIndex < newIndex then
    System.Move(fItems[currentIndex + 1], fItems[currentIndex], (newIndex - currentIndex) * SizeOf(T))
  else
    System.Move(fItems[newIndex], fItems[newIndex + 1], (currentIndex - newIndex) * SizeOf(T));

  FillChar(fItems[newIndex], SizeOf(T), 0);
  fItems[newIndex] := temp;

  Changed(temp, caMoved);
end;

procedure TList<T>.Clear;
begin
  inherited;
  Capacity := 0;
end;

function TList<T>.EnsureCapacity(value: Integer): Integer;
var
  newCapacity: Integer;
begin
  newCapacity := Length(fItems);
  if newCapacity >= value then
    Exit(newCapacity);

  if newCapacity = 0 then
    newCapacity := value
  else
    repeat
      newCapacity := newCapacity * 2;
      if newCapacity < 0 then
        OutOfMemoryError;
    until newCapacity >= value;
  Capacity := newCapacity;
  Result := newCapacity;
end;

procedure TList<T>.Exchange(index1, index2: Integer);
var
  temp: T;
begin
  Guard.CheckRange((index1 >= 0) and (index1 < Count), 'index1');
  Guard.CheckRange((index2 >= 0) and (index2 < Count), 'index2');

  temp := fItems[index1];
  fItems[index1] := fItems[index2];
  fItems[index2] := temp;

  Changed(fItems[index2], caMoved);
  Changed(fItems[index1], caMoved);
end;

function TList<T>.GetCapacity: Integer;
begin
  Result := Length(fItems);
end;

procedure TList<T>.Reverse;
var
  tmp: T;
  b, e: Integer;
begin
  b := 0;
  e := Count - 1;
  while b < e do
  begin
    Exchange(b, e);
    Inc(b);
    Dec(e);
  end;
end;

procedure TList<T>.SetCapacity(value: Integer);
begin
  if value < Count then
  begin
    DeleteRange(Count - value + 1, Count - value);
  end;
  SetLength(fItems, value);
end;

{$ENDREGION}


{$REGION 'TObjectList<T>'}

constructor TObjectList<T>.Create(ownsObjects: Boolean);
begin
  Create(TComparer<T>.Default, ownsObjects);
end;

constructor TObjectList<T>.Create(const comparer: IComparer<T>;
  ownsObjects: Boolean);
begin
  inherited Create(comparer);
  fOwnsObjects := ownsObjects;
end;

constructor TObjectList<T>.Create(collection: TEnumerable<T>;
  ownsObjects: Boolean);
begin
  Create(TComparer<T>.Default, ownsObjects);
  AddRange(collection);
end;

function TObjectList<T>.GetOwnsObjects: Boolean;
begin
  Result := fOwnsObjects;
end;

procedure TObjectList<T>.SetOwnsObjects(const value: Boolean);
begin
  fOwnsObjects := value;
end;

procedure TObjectList<T>.Changed(const item: T; action: TCollectionChangedAction);
begin
  inherited;
  if OwnsObjects and (action = caRemoved) then
    item.Free;
end;

{$ENDREGION}

end.
