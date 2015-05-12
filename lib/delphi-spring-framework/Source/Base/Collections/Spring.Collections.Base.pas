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

unit Spring.Collections.Base;

interface

uses
  SysUtils,
  TypInfo,
  Generics.Collections,
  Generics.Defaults,
  Rtti,
  Spring,
  Spring.Collections;

type
  ///	<summary>
  ///	  Provides an abstract implementation for the
  ///	  <see cref="IEnumerator">IEnumerator</see> interface.
  ///	</summary>
  TEnumeratorBase = class abstract(TInterfacedObject, IEnumerator)
  protected
    function NonGenericGetCurrent: TValue; virtual; abstract;
    function IEnumerator.GetCurrent = NonGenericGetCurrent;
  public
    function MoveNext: Boolean; virtual;
    procedure Reset; virtual;
    property Current: TValue read NonGenericGetCurrent;
  end;

  ///	<summary>
  ///	  Provides an abstract implementation for the
  ///	  <see cref="IEnumerator{T}">IEnumerator&lt;T&gt;</see> interface.
  ///	</summary>
  TEnumeratorBase<T> = class abstract(TEnumeratorBase, IEnumerator<T>)
  protected
    function NonGenericGetCurrent: TValue; override; final;
    function GetCurrent: T; virtual; abstract;
  public
    property Current: T read GetCurrent;
  end;

  ///	<summary>
  ///	  Provides an abstract implementation for the
  ///	  <see cref="IEnumerable">IEnumerable</see> interface.
  ///	</summary>
  TEnumerableBase = class abstract(TInterfacedObject, IInterface, IEnumerable)
  protected
    function NonGenericGetEnumerator: IEnumerator; virtual; abstract;

    function NonGenericTryGetFirst(out value: TValue): Boolean; virtual; abstract;
    function NonGenericTryGetLast(out value: TValue): Boolean; virtual; abstract;
    function NonGenericFirst: TValue; virtual; abstract;
    function NonGenericFirstOrDefault: TValue; virtual; abstract;
    function NonGenericLast: TValue; virtual; abstract;
    function NonGenericLastOrDefault: TValue; virtual; abstract;
    function NonGenericSingle: TValue; virtual; abstract;
    function NonGenericSingleOrDefault: TValue; virtual; abstract;
    function NonGenericElementAt(index: Integer): TValue; virtual; abstract;
    function NonGenericElementAtOrDefault(index: Integer): TValue; virtual; abstract;
    function NonGenericContains(const item: TValue): Boolean; virtual; abstract;
    function NonGenericMin: TValue; virtual; abstract;
    function NonGenericMax: TValue; virtual; abstract;
    function NonGenericSkip(count: Integer): IEnumerable; virtual; abstract;
    function NonGenericTake(count: Integer): IEnumerable; virtual; abstract;
    function NonGenericConcat(const collection: IEnumerable): IEnumerable; virtual; abstract;
    function NonGenericReversed: IEnumerable; virtual; abstract;
    function NonGenericEqualsTo(const collection: IEnumerable): Boolean; virtual; abstract;
    function NonGenericToList: IList; virtual; abstract;
    function NonGenericToSet: ISet; virtual; abstract;

    function IEnumerable.GetEnumerator = NonGenericGetEnumerator;
    function IEnumerable.TryGetFirst = NonGenericTryGetFirst;
    function IEnumerable.TryGetLast = NonGenericTryGetLast;
    function IEnumerable.First = NonGenericFirst;
    function IEnumerable.FirstOrDefault = NonGenericFirstOrDefault;
    function IEnumerable.Last = NonGenericLast;
    function IEnumerable.LastOrDefault = NonGenericLastOrDefault;
    function IEnumerable.Single = NonGenericSingle;
    function IEnumerable.SingleOrDefault = NonGenericSingleOrDefault;
    function IEnumerable.ElementAt = NonGenericElementAt;
    function IEnumerable.ElementAtOrDefault = NonGenericElementAtOrDefault;
    function IEnumerable.Contains = NonGenericContains;
    function IEnumerable.Min = NonGenericMin;
    function IEnumerable.Max = NonGenericMax;
    function IEnumerable.Skip = NonGenericSkip;
    function IEnumerable.Take = NonGenericTake;
    function IEnumerable.Concat = NonGenericConcat;
    function IEnumerable.Reversed = NonGenericReversed;
    function IEnumerable.EqualsTo = NonGenericEqualsTo;
    function IEnumerable.ToList = NonGenericToList;
    function IEnumerable.ToSet = NonGenericToSet;

    function _AddRef: Integer; virtual; stdcall;
    function _Release: Integer; virtual; stdcall;

    function GetCount: Integer; virtual;
    function GetElementType: PTypeInfo; virtual; abstract;
    function GetIsEmpty: Boolean; virtual;
  public
    function AsObject: TObject;

    property Count: Integer read GetCount;
    property IsEmpty: Boolean read GetIsEmpty;
  end;

  ///	<summary>
  ///	  Provides a default implementation for <c>IEnumerable(T)</c> (Extension
  ///	  Methods).
  ///	</summary>
  TEnumerableBase<T> = class abstract(TEnumerableBase, IEnumerable<T>, IElementType)
  protected
    function NonGenericGetEnumerator: IEnumerator; override; final;
    function NonGenericTryGetFirst(out value: TValue): Boolean; override; final;
    function NonGenericTryGetLast(out value: TValue): Boolean; override; final;
    function NonGenericFirst: TValue; override; final;
    function NonGenericFirstOrDefault: TValue; override; final;
    function NonGenericLast: TValue; override; final;
    function NonGenericLastOrDefault: TValue; override; final;
    function NonGenericSingle: TValue; override; final;
    function NonGenericSingleOrDefault: TValue; override; final;
    function NonGenericElementAt(index: Integer): TValue; override; final;
    function NonGenericElementAtOrDefault(index: Integer): TValue; override; final;
    function NonGenericContains(const item: TValue): Boolean; override; final;
    function NonGenericMin: TValue; override; final;
    function NonGenericMax: TValue; override; final;
    function NonGenericSkip(count: Integer): IEnumerable; override; final;
    function NonGenericTake(count: Integer): IEnumerable; override; final;
    function NonGenericConcat(const collection: IEnumerable): IEnumerable; override; final;
    function NonGenericReversed: IEnumerable; override; final;
    function NonGenericEqualsTo(const collection: IEnumerable): Boolean; override; final;
    function NonGenericToList: IList; override; final;
    function NonGenericToSet: ISet; override; final;

  {$REGION 'Implements IElementType'}
    function GetElementType: PTypeInfo; override;
  {$ENDREGION}

    function GetComparer: IComparer<T>; virtual;    
  public
    function GetEnumerator: IEnumerator<T>; virtual; abstract;
    function TryGetFirst(out value: T): Boolean; overload;
    function TryGetFirst(out value: T; const predicate: TPredicate<T>): Boolean; overload; virtual;
    function TryGetLast(out value: T): Boolean; overload;
    function TryGetLast(out value: T; const predicate: TPredicate<T>): Boolean; overload; virtual;
    function First: T; overload; virtual;
    function First(const predicate: TPredicate<T>): T; overload; virtual;
    function FirstOrDefault: T; overload; virtual;
    function FirstOrDefault(const defaultValue: T): T; overload;
    function FirstOrDefault(const predicate: TPredicate<T>): T; overload; virtual;
    function Last: T; overload; virtual;
    function Last(const predicate: TPredicate<T>): T; overload; virtual;
    function LastOrDefault: T; overload; virtual;
    function LastOrDefault(const defaultValue: T): T; overload;
    function LastOrDefault(const predicate: TPredicate<T>): T; overload; virtual;
    function Single: T; overload;
    function Single(const predicate: TPredicate<T>): T; overload;
    function SingleOrDefault: T; overload;
    function SingleOrDefault(const predicate: TPredicate<T>): T; overload;
    function ElementAt(index: Integer): T;
    function ElementAtOrDefault(index: Integer): T;
    function Min: T;
    function Max: T;
    function Contains(const item: T): Boolean; overload; virtual;
    function Contains(const item: T; const comparer: IEqualityComparer<T>): Boolean; overload; virtual;
    function All(const predicate: TPredicate<T>): Boolean;
    function Any(const predicate: TPredicate<T>): Boolean;
    function Where(const predicate: TPredicate<T>): IEnumerable<T>; virtual;
    function Skip(count: Integer): IEnumerable<T>;
    function SkipWhile(const predicate: TPredicate<T>): IEnumerable<T>; overload;
    function SkipWhile(const predicate: TFunc<T, Integer, Boolean>): IEnumerable<T>; overload;
    function Take(count: Integer): IEnumerable<T>;
    function TakeWhile(const predicate: TPredicate<T>): IEnumerable<T>; overload;
    function TakeWhile(const predicate: TFunc<T, Integer, Boolean>): IEnumerable<T>; overload;
    function Concat(const collection: IEnumerable<T>): IEnumerable<T>;
    function Reversed: IEnumerable<T>; virtual;
    procedure ForEach(const action: TAction<T>); overload;
    procedure ForEach(const action: TActionProc<T>); overload;
    procedure ForEach(const action: TActionMethod<T>); overload;
    function EqualsTo(const collection: IEnumerable<T>): Boolean; overload;
    function EqualsTo(const collection: IEnumerable<T>; const comparer: IEqualityComparer<T>): Boolean; overload;
    function ToArray: TArray<T>; virtual;
    function ToList: IList<T>; virtual;
    function ToSet: ISet<T>; virtual;
  end;

  ///	<summary>
  ///	  Provides an abstract class base for <c>ICollection{T}</c>.
  ///	</summary>
  ///	<remarks>
  ///	  Notes: The Add/Remove/Clear methods are abstract. IsReadOnly returns
  ///	  False by default.
  ///	</remarks>
  TCollectionBase<T> = class abstract(TEnumerableBase<T>, ICollection<T>, ICollection)
  protected
    function GetIsReadOnly: Boolean; virtual;

    procedure NonGenericAdd(const item: TValue);
    procedure ICollection.Add = NonGenericAdd;
    procedure NonGenericAddRange(const collection: IEnumerable);
    procedure ICollection.AddRange = NonGenericAddRange;

    function NonGenericRemove(const item: TValue): Boolean;
    function ICollection.Remove = NonGenericRemove;
    procedure NonGenericRemoveRange(const collection: IEnumerable);
    procedure ICollection.RemoveRange = NonGenericRemoveRange;
  public
    procedure Add(const item: T); virtual; abstract;
    procedure AddRange(const collection: array of T); overload; virtual;
    procedure AddRange(const collection: IEnumerable<T>); overload; virtual;
    procedure AddRange(const collection: TEnumerable<T>); overload; virtual;

    function Remove(const item: T): Boolean; virtual; abstract;
    procedure RemoveRange(const collection: array of T); overload; virtual;
    procedure RemoveRange(const collection: IEnumerable<T>); overload; virtual;
    procedure RemoveRange(const collection: TEnumerable<T>); overload; virtual;

    procedure Clear; virtual; abstract;

    function AsCollection: ICollection;

    ///	<value>
    ///	  Returns false, by default.
    ///	</value>
    property IsReadOnly: Boolean read GetIsReadOnly;
  end;

  TContainedCollectionBase<T> = class(TCollectionBase<T>)
  private
    fController: Pointer;
    function GetController: IInterface;
  protected

  {$REGION 'Implements IInterface'}
    function _AddRef: Integer; override;
    function _Release: Integer; override;
  {$ENDREGION}
  public
    constructor Create(const controller: IInterface);
    property Controller: IInterface read GetController;
  end;

  TListBase<T> = class abstract(TCollectionBase<T>, IList<T>, IList)
  protected
    type
      TEnumerator = class(TEnumeratorBase<T>)
      private
        fList: TListBase<T>;
        fIndex: Integer;
      protected
        function GetCurrent: T; override;
      public
        constructor Create(const list: TListBase<T>);
        function MoveNext: Boolean; override;
      end;
  private
    fComparer: IComparer<T>;
    fOnChanged: ICollectionChangedEvent<T>;
    function GetOnChanged: ICollectionChangedEvent<T>;
    function NonGenericGetOnChanged: IEvent;
    function IList.GetOnChanged = NonGenericGetOnChanged;
  protected
    function GetComparer: IComparer<T>; override;
    procedure Changed(const item: T; action: TCollectionChangedAction); virtual;
    procedure DoSort(const comparer: IComparer<T>); virtual;
    procedure DoInsert(index: Integer; const item: T); virtual; abstract;
    procedure DoDelete(index: Integer; notification: TCollectionChangedAction); virtual; abstract;
    procedure DoDeleteRange(index, count: Integer; notification: TCollectionChangedAction); virtual; abstract;
    function GetItem(index: Integer): T; virtual; abstract;
    procedure SetItem(index: Integer; const value: T); virtual; abstract;

    function NonGenericGetItem(index: Integer): TValue;
    procedure NonGenericSetItem(index: Integer; const value: TValue);
    procedure NonGenericInsert(index: Integer; const item: TValue);
    procedure NonGenericInsertRange(index: Integer; const collection: IEnumerable);
    function NonGenericIndexOf(const item: TValue): Integer;
    function NonGenericLastIndexOf(const item: TValue): Integer;

    function IList.GetItem = NonGenericGetItem;
    procedure IList.SetItem = NonGenericSetItem;
    procedure IList.Insert = NonGenericInsert;
    procedure IList.InsertRange = NonGenericInsertRange;
    function IList.IndexOf = NonGenericIndexOf;
    function IList.LastIndexOf = NonGenericLastIndexOf;
  public
    constructor Create; overload;
    constructor Create(const comparer: IComparer<T>); overload;
    constructor Create(const collection: array of T); overload;
    constructor Create(const collection: IEnumerable<T>); overload;
    constructor Create(const collection: TEnumerable<T>); overload;
    destructor Destroy; override;

    function TryGetFirst(out value: T; const predicate: TPredicate<T>): Boolean; override;
    function TryGetLast(out value: T; const predicate: TPredicate<T>): Boolean; override;
    function Contains(const item: T): Boolean; override;
    function ToArray: TArray<T>; override;
    function Reversed: IEnumerable<T>; override;

    function GetEnumerator: IEnumerator<T>; override;

    procedure Add(const item: T); override;
    function  Remove(const item: T): Boolean; override;
    procedure Clear; override;

    procedure Insert(index: Integer; const item: T); virtual;
    procedure InsertRange(index: Integer; const collection: array of T); overload; virtual;
    procedure InsertRange(index: Integer; const collection: IEnumerable<T>); overload; virtual;
    procedure InsertRange(index: Integer; const collection: TEnumerable<T>); overload; virtual;
    procedure Delete(index: Integer);
    procedure DeleteRange(startIndex, count: Integer);
    function Extract(const item: T): T;
    function IndexOf(const item: T): Integer;
    function LastIndexOf(const item: T): Integer;
    procedure Exchange(index1, index2: Integer); virtual; abstract;
    procedure Move(currentIndex, newIndex: Integer); virtual; abstract;
    procedure Sort; overload;
    procedure Sort(const comparer: IComparer<T>); overload;
    procedure Sort(const comparison: TComparison<T>); overload;
    procedure Reverse; virtual; abstract;

    function AsList: IList;

    property Items[index: Integer]: T read GetItem write SetItem; default;
    property OnChanged: ICollectionChangedEvent<T> read GetOnChanged;
  end;

implementation

uses
  Spring.Collections.Events,
  Spring.Collections.Extensions,
  Spring.Collections.Lists,
  Spring.Collections.Sets,
  Spring.ResourceStrings;


{$REGION 'TEnumeratorBase'}

function TEnumeratorBase.MoveNext: Boolean;
begin
  Result := False;
end;

procedure TEnumeratorBase.Reset;
begin
  raise ENotSupportedException.CreateRes(@SCannotResetEnumerator);
end;

{$ENDREGION}


{$REGION 'TEnumeratorBase<T>'}

function TEnumeratorBase<T>.NonGenericGetCurrent: TValue;
begin
  Result := TValue.From<T>(GetCurrent);
end;

{$ENDREGION}


{$REGION 'TEnumerableBase'}

function TEnumerableBase.AsObject: TObject;
begin
  Result := Self;
end;

function TEnumerableBase.GetCount: Integer;
var
  enumerator: IEnumerator;
begin
  Result := 0;
  enumerator := NonGenericGetEnumerator;
  while enumerator.MoveNext do
  begin
    Inc(Result);
  end;
end;

function TEnumerableBase.GetIsEmpty: Boolean;
begin
  Result := Count = 0;
end;

function TEnumerableBase._AddRef: Integer;
begin
  Result := inherited _AddRef;
end;

function TEnumerableBase._Release: Integer;
begin
  Result := inherited _Release;
end;

{$ENDREGION}


{$REGION 'TEnumerableBase<T>'}

function TEnumerableBase<T>.Contains(const item: T): Boolean;
var
  comparer: IEqualityComparer<T>;
begin
  Guard.CheckNotNull<T>(item, 'item');

  comparer := TEqualityComparer<T>.Default;
  Result := Contains(item, comparer);
end;

function TEnumerableBase<T>.All(const predicate: TPredicate<T>): Boolean;
var
  item: T;
begin
  Guard.CheckNotNull(Assigned(predicate), 'predicate');

  Result := True;
  for item in Self do
  begin
    if not predicate(item) then
      Exit(False);
  end;
end;

function TEnumerableBase<T>.Any(const predicate: TPredicate<T>): Boolean;
var
  item: T;
begin
  Guard.CheckNotNull(Assigned(predicate), 'predicate');

  Result := False;
  for item in Self do
  begin
    if predicate(item) then
      Exit(True);
  end;
end;

function TEnumerableBase<T>.Concat(
  const collection: IEnumerable<T>): IEnumerable<T>;
begin
  Guard.CheckNotNull(Assigned(collection), 'collection');

  Result := TConcatEnumerable<T>.Create(Self, collection);
end;

function TEnumerableBase<T>.Contains(const item: T;
  const comparer: IEqualityComparer<T>): Boolean;
var
  enumerator: IEnumerator<T>;
begin
  Guard.CheckNotNull<T>(item, 'item');

  enumerator := GetEnumerator;
  Result := False;
  while enumerator.MoveNext do
  begin
    if comparer.Equals(enumerator.Current, item) then
    begin
      Exit(True);
    end;
  end;
end;

function TEnumerableBase<T>.ElementAt(index: Integer): T;
var
  enumerator: IEnumerator<T>;
  localIndex: Integer;
begin
  Guard.CheckRange(index >= 0, 'index');

  enumerator := GetEnumerator;
  localIndex := 0;
  while enumerator.MoveNext do
  begin
    if localIndex = index then
    begin
      Exit(enumerator.Current);
    end;
    Inc(localIndex);
  end;
  Guard.RaiseArgumentOutOfRangeException('index');
end;

function TEnumerableBase<T>.ElementAtOrDefault(index: Integer): T;
var
  enumerator: IEnumerator<T>;
  localIndex: Integer;
begin
  Guard.CheckRange(index >= 0, 'index');

  enumerator := GetEnumerator;
  localIndex := 0;
  while enumerator.MoveNext do
  begin
    if localIndex = index then
    begin
      Exit(enumerator.Current);
    end;
    Inc(localIndex);
  end;
  Result := Default(T);
end;

function TEnumerableBase<T>.EqualsTo(const collection: IEnumerable<T>): Boolean;
begin
  Result := EqualsTo(collection, TEqualityComparer<T>.Default);
end;

function TEnumerableBase<T>.EqualsTo(const collection: IEnumerable<T>;
  const comparer: IEqualityComparer<T>): Boolean;
var
  e1, e2: IEnumerator<T>;
  hasNext: Boolean;
begin
  Guard.CheckNotNull(Assigned(collection), 'collection');
  Guard.CheckNotNull(Assigned(comparer), 'comparer');

  e1 := GetEnumerator;
  e2 := collection.GetEnumerator;

  while True do
  begin
    hasNext := e1.MoveNext;
    if hasNext <> e2.MoveNext then
      Exit(False)
    else if not hasNext then
      Exit(True);
    if hasNext and not comparer.Equals(e1.Current, e2.Current) then
    begin
      Exit(False);
    end;
  end;
end;

function TEnumerableBase<T>.TryGetFirst(out value: T): Boolean;
begin
  Result := TryGetFirst(value, nil);
end;

function TEnumerableBase<T>.TryGetFirst(out value: T; const predicate: TPredicate<T>): Boolean;
var
  item: T;
begin
  for item in Self do
  begin
    if not Assigned(predicate) or predicate(item) then
    begin
      value := item;
      Exit(True);
    end;
  end;
  Result := False;
end;

function TEnumerableBase<T>.TryGetLast(out value: T): Boolean;
begin
  Result := TryGetLast(value, nil);
end;

function TEnumerableBase<T>.TryGetLast(out value: T; const predicate: TPredicate<T>): Boolean;
var
  item: T;
begin
  Result := False;
  for item in Self do
  begin
    if not Assigned(predicate) or predicate(item) then
    begin
      value := item;
      Result := True;
    end;
  end;
end;

function TEnumerableBase<T>.First: T;
begin
  if not TryGetFirst(Result) then
  begin
    raise EInvalidOperationException.Create('First');  // TEMP
  end;
end;

function TEnumerableBase<T>.First(const predicate: TPredicate<T>): T;
begin
  Result := Where(predicate).First; // TEMP
end;

function TEnumerableBase<T>.FirstOrDefault: T;
begin
  if not TryGetFirst(Result) then
  begin
    Result := Default(T);
  end;
end;

function TEnumerableBase<T>.FirstOrDefault(const defaultValue: T): T;
begin
  if not TryGetFirst(Result) then
  begin
    Result := defaultValue;
  end;
end;

function TEnumerableBase<T>.FirstOrDefault(const predicate: TPredicate<T>): T;
begin
  Result := Where(predicate).FirstOrDefault; // TEMP
end;

procedure TEnumerableBase<T>.ForEach(const action: TAction<T>);
var
  item: T;
begin
  Guard.CheckNotNull(Assigned(action), 'action');

  for item in Self do
  begin
    action(item);
  end;
end;

procedure TEnumerableBase<T>.ForEach(const action: TActionProc<T>);
var
  item: T;
begin
  Guard.CheckNotNull(Assigned(action), 'action');

  for item in Self do
  begin
    action(item);
  end;
end;

procedure TEnumerableBase<T>.ForEach(const action: TActionMethod<T>);
var
  item: T;
begin
  Guard.CheckNotNull(Assigned(action), 'action');

  for item in Self do
  begin
    action(item);
  end;
end;

function TEnumerableBase<T>.Last: T;
begin
  if not TryGetLast(Result) then
  begin
    raise EInvalidOperationException.Create('Last');  // TEMP
  end;
end;

function TEnumerableBase<T>.Last(const predicate: TPredicate<T>): T;
begin
  Result := Where(predicate).Last;
end;

function TEnumerableBase<T>.LastOrDefault(const defaultValue: T): T;
begin
  if not TryGetLast(Result) then
  begin
    Result := defaultValue;
  end;
end;

function TEnumerableBase<T>.LastOrDefault: T;
begin
  if not TryGetLast(Result) then
  begin
    Result := Default(T);
  end;
end;

function TEnumerableBase<T>.LastOrDefault(const predicate: TPredicate<T>): T;
begin
  Result := Where(predicate).LastOrDefault;
end;

function TEnumerableBase<T>.Max: T;
var
  comparer: IComparer<T>;
  hasElement: Boolean;
  item: T;
begin
  comparer := GetComparer;
  hasElement := False;
  for item in Self do
  begin
    if hasElement then
    begin
      if comparer.Compare(item, Result) > 0 then
      begin
        Result := item;
      end;
    end
    else
    begin
      hasElement := True;
      Result := item;
    end;
  end;
  if not hasElement then
  begin
    raise EInvalidOperationException.CreateRes(@SSequenceIsEmpty);
  end;
end;

function TEnumerableBase<T>.Min: T;
var
  comparer: IComparer<T>;
  hasElement: Boolean;
  item: T;
begin
  comparer := GetComparer;
  hasElement := False;
  for item in Self do
  begin
    if hasElement then
    begin
      if comparer.Compare(item, Result) < 0 then
      begin
        Result := item;
      end;
    end
    else
    begin
      hasElement := True;
      Result := item;
    end;
  end;
  if not hasElement then
  begin
    raise EInvalidOperationException.CreateRes(@SSequenceIsEmpty);
  end;
end;

function TEnumerableBase<T>.NonGenericConcat(
  const collection: IEnumerable): IEnumerable;
begin
  Result := Concat(collection as TEnumerableBase<T>);
end;

function TEnumerableBase<T>.NonGenericContains(const item: TValue): Boolean;
begin
  Result := Contains(item.AsType<T>);
end;

function TEnumerableBase<T>.NonGenericElementAt(index: Integer): TValue;
begin
  Result := TValue.From<T>(ElementAt(index));
end;

function TEnumerableBase<T>.NonGenericElementAtOrDefault(
  index: Integer): TValue;
begin
  Result := TValue.From<T>(ElementAtOrDefault(index));
end;

function TEnumerableBase<T>.NonGenericEqualsTo(
  const collection: IEnumerable): Boolean;
begin
  Result := EqualsTo(collection as TEnumerableBase<T>);
end;

function TEnumerableBase<T>.NonGenericFirst: TValue;
begin
  Result := TValue.From<T>(First);
end;

function TEnumerableBase<T>.NonGenericFirstOrDefault: TValue;
begin
  Result := TValue.From<T>(FirstOrDefault);
end;

function TEnumerableBase<T>.NonGenericGetEnumerator: IEnumerator;
begin
  Result := GetEnumerator;
end;

function TEnumerableBase<T>.NonGenericLast: TValue;
begin
  Result := TValue.From<T>(Last);
end;

function TEnumerableBase<T>.NonGenericLastOrDefault: TValue;
begin
  Result := TValue.From<T>(LastOrDefault);
end;

function TEnumerableBase<T>.NonGenericMax: TValue;
begin
  Result := TValue.From<T>(Max);
end;

function TEnumerableBase<T>.NonGenericMin: TValue;
begin
  Result := TValue.From<T>(Min);
end;

function TEnumerableBase<T>.NonGenericReversed: IEnumerable;
begin
  Result := Reversed;
end;

function TEnumerableBase<T>.NonGenericSingle: TValue;
begin
  Result := TValue.From<T>(Single);
end;

function TEnumerableBase<T>.NonGenericSingleOrDefault: TValue;
begin
  Result := TValue.From<T>(SingleOrDefault);
end;

function TEnumerableBase<T>.NonGenericSkip(count: Integer): IEnumerable;
begin
  Result := Skip(count);
end;

function TEnumerableBase<T>.NonGenericTake(count: Integer): IEnumerable;
begin
  Result := Take(count);
end;

function TEnumerableBase<T>.NonGenericToList: IList;
begin
  Supports(ToList, IList, Result);

  Guard.CheckNotNull(Result, 'Result');
end;

function TEnumerableBase<T>.NonGenericToSet: ISet;
begin
  Supports(ToSet, ISet, Result);

  Guard.CheckNotNull(Result, 'Result');
end;

function TEnumerableBase<T>.NonGenericTryGetFirst(out value: TValue): Boolean;
var
  item: T;
begin  
  Result := TryGetFirst(item);
  if Result then
    value := TValue.From<T>(item);
end;

function TEnumerableBase<T>.NonGenericTryGetLast(out value: TValue): Boolean;
var
  item: T;
begin  
  Result := TryGetLast(item);
  if Result then
    value := TValue.From<T>(item);
end;

function TEnumerableBase<T>.Reversed: IEnumerable<T>;
var
  list: IList<T>;
begin
  list := ToList;
  Result := TReversedEnumerable<T>.Create(list);
end;

function TEnumerableBase<T>.Single: T;
var
  enumerator: IEnumerator<T>;
  item: T;
begin
  enumerator := GetEnumerator;
  if not enumerator.MoveNext then
  begin
    raise EInvalidOperationException.CreateRes(@SSequenceIsEmpty);
  end;
  Result := enumerator.Current;
  if enumerator.MoveNext then
  begin
    raise EInvalidOperationException.CreateRes(@SSequenceContainsMoreThanOneElement);
  end;
end;

function TEnumerableBase<T>.Single(const predicate: TPredicate<T>): T;
var
  enumerator: IEnumerator<T>;
  item: T;
  isSatisfied: Boolean;
begin
  Guard.CheckNotNull(Assigned(predicate), 'predicate');

  enumerator := GetEnumerator;

  if not enumerator.MoveNext then
  begin
    raise EInvalidOperationException.CreateRes(@SSequenceIsEmpty);
  end;

  Result := enumerator.Current;
  isSatisfied := predicate(Result);

  while enumerator.MoveNext do
  begin
    Result := enumerator.Current;
    if predicate(Result) then
    begin
      if isSatisfied then
      begin
        raise EInvalidOperationException.CreateRes(@SMoreThanOneElementSatisfied);
      end;
      isSatisfied := True;
    end;
  end;
  if not isSatisfied then
  begin
    raise EInvalidOperationException.CreateRes(@SNoElementSatisfiesCondition);
  end;
end;

function TEnumerableBase<T>.SingleOrDefault: T;
var
  enumerator: IEnumerator<T>;
  item: T;
begin
  enumerator := GetEnumerator;
  if not enumerator.MoveNext then
  begin
    Exit(Default(T));
  end;
  Result := enumerator.Current;
  if enumerator.MoveNext then
  begin
    raise EInvalidOperationException.CreateRes(@SSequenceContainsMoreThanOneElement);
  end;
end;

function TEnumerableBase<T>.SingleOrDefault(const predicate: TPredicate<T>): T;
var
  enumerator: IEnumerator<T>;
  item: T;
  isSatisfied: Boolean;
begin
  Guard.CheckNotNull(Assigned(predicate), 'predicate');

  enumerator := GetEnumerator;
  if not enumerator.MoveNext then
  begin
    Exit(Default(T));
  end;

  Result := enumerator.Current;
  isSatisfied := predicate(Result);

  while enumerator.MoveNext do
  begin
    Result := enumerator.Current;
    if predicate(Result) then
    begin
      if isSatisfied then
      begin
        raise EInvalidOperationException.CreateRes(@SMoreThanOneElementSatisfied);
      end;
      isSatisfied := True;
    end;
  end;

  if not isSatisfied then
  begin
    Result := Default(T);
  end;
end;

function TEnumerableBase<T>.Where(
  const predicate: TPredicate<T>): IEnumerable<T>;
begin
  Guard.CheckNotNull(Assigned(predicate), 'predicate');

  Result := TWhereEnumerable<T>.Create(Self, predicate);
end;

function TEnumerableBase<T>.Skip(count: Integer): IEnumerable<T>;
begin
  Result := TSkipEnumerable<T>.Create(Self, count);
end;

function TEnumerableBase<T>.SkipWhile(
  const predicate: TPredicate<T>): IEnumerable<T>;
begin
  Guard.CheckNotNull(Assigned(predicate), 'predicate');

  Result := TSkipWhileEnumerable<T>.Create(Self, predicate);
end;

function TEnumerableBase<T>.SkipWhile(
  const predicate: TFunc<T, Integer, Boolean>): IEnumerable<T>;
begin
  Guard.CheckNotNull(Assigned(predicate), 'predicate');

  Result := TSkipWhileIndexEnumerable<T>.Create(Self, predicate);
end;

function TEnumerableBase<T>.Take(count: Integer): IEnumerable<T>;
begin
  Result := TTakeEnumerable<T>.Create(Self, count);
end;

function TEnumerableBase<T>.TakeWhile(
  const predicate: TPredicate<T>): IEnumerable<T>;
begin
  Guard.CheckNotNull(Assigned(predicate), 'predicate');

  Result := TTakeWhileEnumerable<T>.Create(Self, predicate);
end;

function TEnumerableBase<T>.TakeWhile(
  const predicate: TFunc<T, Integer, Boolean>): IEnumerable<T>;
begin
  Guard.CheckNotNull(Assigned(predicate), 'predicate');

  Result := TTakeWhileIndexEnumerable<T>.Create(Self, predicate);
end;

function TEnumerableBase<T>.ToArray: TArray<T>;
begin
  Result := ToList.ToArray;
end;

function TEnumerableBase<T>.ToList: IList<T>;
begin
  Result := TList<T>.Create;
  Result.AddRange(Self);
end;

function TEnumerableBase<T>.ToSet: ISet<T>;
begin
  Result := THashSet<T>.Create;
  Result.AddRange(Self);
end;

function TEnumerableBase<T>.GetComparer: IComparer<T>;
begin
  Result := TComparer<T>.Default;
end;

function TEnumerableBase<T>.GetElementType: PTypeInfo;
begin
  Result := TypeInfo(T);
end;

{$ENDREGION}


{$REGION 'TCollectionBase<T>'}

procedure TCollectionBase<T>.AddRange(const collection: array of T);
var
  item: T;
begin
  for item in collection do
  begin
    Add(item);
  end;
end;

procedure TCollectionBase<T>.AddRange(const collection: IEnumerable<T>);
var
  item: T;
begin
  for item in collection do
  begin
    Add(item);
  end;
end;

procedure TCollectionBase<T>.AddRange(const collection: TEnumerable<T>);
var
  item: T;
begin
  for item in collection do
  begin
    Add(item);
  end;
end;

function TCollectionBase<T>.AsCollection: ICollection;
begin
  Result := Self;
end;

procedure TCollectionBase<T>.RemoveRange(const collection: array of T);
var
  item: T;
begin
  for item in collection do
  begin
    Remove(item);
  end;
end;

procedure TCollectionBase<T>.RemoveRange(const collection: TEnumerable<T>);
var
  item: T;
begin
  for item in collection do
  begin
    Remove(item);
  end;
end;

procedure TCollectionBase<T>.RemoveRange(const collection: IEnumerable<T>);
var
  item: T;
begin
  for item in collection do
  begin
    Remove(item);
  end;
end;

function TCollectionBase<T>.GetIsReadOnly: Boolean;
begin
  Result := False;
end;

procedure TCollectionBase<T>.NonGenericAdd(const item: TValue);
begin
  Add(item.AsType<T>);
end;

procedure TCollectionBase<T>.NonGenericAddRange(const collection: IEnumerable);
var
  item: TValue;
begin
  for item in collection do
  begin
    Add(item.AsType<T>);
  end;
end;

function TCollectionBase<T>.NonGenericRemove(const item: TValue): Boolean;
begin
  Result := Remove(item.AsType<T>);
end;

procedure TCollectionBase<T>.NonGenericRemoveRange(
  const collection: IEnumerable);
var
  item: TValue;
begin
  for item in collection do
  begin
    Remove(item.AsType<T>);
  end;
end;

{$ENDREGION}


{$REGION 'TContainedCollectionBase<T>'}

constructor TContainedCollectionBase<T>.Create(const controller: IInterface);
begin
  inherited Create;
  fController := Pointer(controller);
end;

function TContainedCollectionBase<T>.GetController: IInterface;
begin
  Result := IInterface(fController);
end;

function TContainedCollectionBase<T>._AddRef: Integer;
begin
  Result := IInterface(FController)._AddRef;
end;

function TContainedCollectionBase<T>._Release: Integer;
begin
  Result := IInterface(FController)._Release;
end;

{$ENDREGION}


{$REGION 'TListBase<T>'}

constructor TListBase<T>.Create;
begin
  Create(TComparer<T>.Default);
end;

constructor TListBase<T>.Create(const comparer: IComparer<T>);
begin
  inherited Create;
  fComparer := comparer;
  fOnChanged := TCollectionChangedEventImpl<T>.Create;
  if fComparer = nil then
    fComparer := TComparer<T>.Default;
end;

constructor TListBase<T>.Create(const collection: array of T);
begin
  Create;
  AddRange(collection);
end;

constructor TListBase<T>.Create(const collection: IEnumerable<T>);
begin
  Create;
  AddRange(collection);
end;

constructor TListBase<T>.Create(const collection: TEnumerable<T>);
begin
  Create;
  AddRange(collection);
end;

destructor TListBase<T>.Destroy;
begin
  Clear;
  inherited Destroy;
end;

function TListBase<T>.Remove(const item: T): Boolean;
var
  index: Integer;
begin
  index := IndexOf(item);
  Result := index > -1;
  if Result then
  begin
    DoDelete(index, caRemoved);
  end;
end;

procedure TListBase<T>.DoSort(const comparer: IComparer<T>);
begin
end;

function TListBase<T>.Reversed: IEnumerable<T>;
begin
  Result := TReversedEnumerable<T>.Create(Self);
end;

function TListBase<T>.Extract(const item: T): T;
var
  index: Integer;
begin
  index := IndexOf(item);
  if index < 0 then
    Result := Default(T)
  else
  begin
    Result := Items[index];
    DoDelete(index, caExtracted);
  end;
end;

procedure TListBase<T>.Delete(index: Integer);
begin
  Guard.CheckRange((index >= 0) and (index < Count), 'index');

  DoDelete(index, caRemoved);
end;

procedure TListBase<T>.DeleteRange(startIndex, count: Integer);
begin
  if (startIndex < 0) or
    (count < 0) or
    (startIndex + count > Self.Count) or
    (startIndex + count < 0) then
    raise EArgumentOutOfRangeException.CreateRes(@SArgumentOutOfRangeException);

  if count = 0 then
    Exit;

  DoDeleteRange(startIndex, count, caRemoved);
end;

procedure TListBase<T>.Add(const item: T);
begin
  Insert(Count, item);
end;

function TListBase<T>.AsList: IList;
begin
  Result := Self;
end;

procedure TListBase<T>.Clear;
begin
  if Count > 0 then
  begin
    DeleteRange(0, Count);
  end;
end;

function TListBase<T>.Contains(const item: T): Boolean;
var
  index: Integer;
begin
  index := IndexOf(item);
  Result := index > -1;
end;

function TListBase<T>.IndexOf(const item: T): Integer;
var
  i: Integer;
begin
  for i := 0 to Count - 1 do
  begin
    if fComparer.Compare(Items[i], item) = 0 then
      Exit(i);
  end;
  Result := -1;
end;

procedure TListBase<T>.InsertRange(index: Integer; const collection: array of T);
var
  item: T;
begin
  Guard.CheckRange((index >= 0) and (index <= Count), 'index');

  for item in collection do
  begin
    Insert(index, item);
    Inc(index);
  end;
end;

procedure TListBase<T>.InsertRange(index: Integer;
  const collection: IEnumerable<T>);
var
  item: T;
begin
  Guard.CheckRange((index >= 0) and (index <= Count), 'index');

  for item in collection do
  begin
    Insert(index, item);
    Inc(index);
  end;
end;

procedure TListBase<T>.InsertRange(index: Integer;
  const collection: TEnumerable<T>);
var
  item: T;
begin
  Guard.CheckRange((index >= 0) and (index <= Count), 'index');

  for item in collection do
  begin
    Insert(index, item);
    Inc(index);
  end;
end;

procedure TListBase<T>.Insert(index: Integer; const item: T);
begin
  Guard.CheckRange((index >= 0) and (index <= Count), 'index');

  DoInsert(index, item);
end;

function TListBase<T>.LastIndexOf(const item: T): Integer;
var
  i: Integer;
begin
  for i := Count - 1 downto 0 do
  begin
    if fComparer.Compare(Items[i], item) = 0 then
      Exit(i);
  end;
  Result := -1;
end;

function TListBase<T>.NonGenericGetItem(index: Integer): TValue;
begin
  Result := TValue.From<T>(GetItem(index));
end;

function TListBase<T>.NonGenericGetOnChanged: IEvent;
begin
  Result := GetOnChanged;
end;

function TListBase<T>.NonGenericIndexOf(const item: TValue): Integer;
begin
  Result := IndexOf(item.AsType<T>);
end;

procedure TListBase<T>.NonGenericInsert(index: Integer; const item: TValue);
begin
  Insert(index, item.AsType<T>);
end;

procedure TListBase<T>.NonGenericInsertRange(index: Integer;
  const collection: IEnumerable);
var
  item: TValue;
begin
  Guard.CheckRange((index >= 0) and (index <= Count), 'index');

  for item in collection do
  begin
    Insert(index, item.AsType<T>);
    Inc(index);
  end;
end;

function TListBase<T>.NonGenericLastIndexOf(const item: TValue): Integer;
begin
  Result := LastIndexOf(item.AsType<T>);
end;

procedure TListBase<T>.NonGenericSetItem(index: Integer; const value: TValue);
begin
  SetItem(index, value.AsType<T>);
end;

procedure TListBase<T>.Changed(const item: T; action: TCollectionChangedAction);
begin
  fOnChanged.Invoke(Self, item, action);
end;

function TListBase<T>.ToArray: TArray<T>;
var
  i: Integer;
begin
  SetLength(Result, Count);
  for i := 0 to Length(Result) - 1 do
  begin
    Result[i] := Items[i];
  end;
end;

function TListBase<T>.GetEnumerator: IEnumerator<T>;
begin
  Result := TEnumerator.Create(Self);
end;

function TListBase<T>.GetComparer: IComparer<T>;
begin
  Result := fComparer;
end;

function TListBase<T>.TryGetFirst(out value: T; const predicate: TPredicate<T>): Boolean;
begin
  if not Assigned(predicate) then
  begin
    Result := Count > 0;
    if Result then
      value := Items[0];
  end
  else
    Result := inherited;
end;

function TListBase<T>.TryGetLast(out value: T; const predicate: TPredicate<T>): Boolean;
begin
  if not Assigned(predicate) then
  begin
    Result := Count > 0;
    if Result then
      value := Items[Count - 1];
  end
  else
    Result := inherited;
end;

function TListBase<T>.GetOnChanged: ICollectionChangedEvent<T>;
begin
  Result := fOnChanged;
end;

procedure TListBase<T>.Sort;
begin
  DoSort(fComparer);
end;

procedure TListBase<T>.Sort(const comparer: IComparer<T>);
begin
  DoSort(comparer);
end;

procedure TListBase<T>.Sort(const comparison: TComparison<T>);
var
  comparer: IComparer<T>;
begin
  comparer := TComparer<T>.Construct(comparison);
  DoSort(comparer);
end;

{$ENDREGION}


{$REGION 'TListBase<T>.TEnumerator'}

constructor TListBase<T>.TEnumerator.Create(const list: TListBase<T>);
begin
  inherited Create;
  fList := list;
  fIndex := -1;
end;

function TListBase<T>.TEnumerator.MoveNext: Boolean;
begin
  Result := fIndex < fList.Count - 1;
  if Result then
    Inc(fIndex);
end;

function TListBase<T>.TEnumerator.GetCurrent: T;
begin
  Result := fList[fIndex];
end;

{$ENDREGION}

end.
