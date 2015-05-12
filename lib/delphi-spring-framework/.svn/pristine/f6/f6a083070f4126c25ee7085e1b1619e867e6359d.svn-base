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

///	<summary>
///	  The Spring.Collections namespaces introduce the Collections Framework in
///	  spring4d.
///	</summary>
///	<preliminary />
unit Spring.Collections;

{$I Spring.inc}

interface

uses
  Classes,
  SysUtils,
  TypInfo,
  Rtti,
  Generics.Defaults,
  Generics.Collections,
  Spring;

type
  { Forward Declarations }
  IEnumerator = interface;
  IEnumerable = interface;
  ICollection = interface;
  IList = interface;
  IDictionary = interface;
  IStack = interface;
  IQueue = interface;
  ISet = interface;

  IEnumerator<T> = interface;
  IEnumerable<T> = interface;
  ICollection<T> = interface;
  IList<T> = interface;
  IDictionary<TKey, TValue> = interface;
  IStack<T> = interface;
  IQueue<T> = interface;
  ISet<T> = interface;

  TCollectionChangedAction = (
    caAdded,
    caRemoved,
    caExtracted,
    caReplaced,
    caMoved,
    caReseted
  );

  TCollectionChangedEvent<T> = procedure(Sender: TObject; const Item: T;
    Action: TCollectionChangedAction) of object;

  ICollectionChangedEvent<T> = interface(IEvent<TCollectionChangedEvent<T>>)
  end;

  IEnumerator = interface(IInvokable)
    ['{A2AD52DC-FA9F-4121-9B54-5C427DA5E62C}']
    function GetCurrent: TValue;
    function MoveNext: Boolean;
    procedure Reset;
    property Current: TValue read GetCurrent;
  end;

  ///	<summary>
  ///	  Represents an iterator over a generic enumerable collection.
  ///	</summary>
  IEnumerator<T> = interface(IEnumerator)

    ///	<summary>
    ///	  The getter of the <see cref="Current" /> property.
    ///	</summary>
    ///	<exception cref="Spring|EInvalidOperationException">
    ///	  The enumerator has not been started or ended.
    ///	</exception>
    function GetCurrent: T;

    ///	<summary>
    ///	  Advances the enumerator to the next element of the collection.
    ///	</summary>
    ///	<exception cref="Spring|EInvalidOperationException">
    ///	  The collection was modified after the enumerator was created.
    ///	</exception>
    function MoveNext: Boolean;

    ///	<exception cref="Spring|EInvalidOperationException">
    ///	  The collection was modified after the enumerator was created.
    ///	</exception>
    ///	<exception cref="Spring|ENotSupportedException">
    ///	  The Reset method is not supported.
    ///	</exception>
    procedure Reset;

    ///	<summary>
    ///	  Gets the current element in the collection.
    ///	</summary>
    property Current: T read GetCurrent;
  end;

  IEnumerable = interface(IInvokable)
    ['{6BC97F33-C0A8-4770-8E1C-C2017527B7E7}']
    function GetEnumerator: IEnumerator;
    function AsObject: TObject;
    function TryGetFirst(out value: TValue): Boolean;
    function TryGetLast(out value: TValue): Boolean;
    function First: TValue;
    function FirstOrDefault: TValue;
    function Last: TValue;
    function LastOrDefault: TValue;
    function Single: TValue;
    function SingleOrDefault: TValue;
    function ElementAt(index: Integer): TValue;
    function ElementAtOrDefault(index: Integer): TValue;
    function Contains(const item: TValue): Boolean; overload;
    function Min: TValue;
    function Max: TValue;
    function Skip(count: Integer): IEnumerable;
    function Take(count: Integer): IEnumerable;
    function Concat(const collection: IEnumerable): IEnumerable;
    function Reversed: IEnumerable;
    function EqualsTo(const collection: IEnumerable): Boolean; overload;
    function ToList: IList;
    function ToSet: ISet;
    function GetCount: Integer;
    function GetIsEmpty: Boolean;
    property Count: Integer read GetCount;
    property IsEmpty: Boolean read GetIsEmpty;

    function GetElementType: PTypeInfo;
    property ElementType: PTypeInfo read GetElementType;
  end;

  ///	<summary>
  ///	  Provides limited LINQ-like enumerable extension methods for
  ///	  <c>IEnumerable{T}</c>.
  ///	</summary>
  ///	<seealso href="http://msdn.microsoft.com/en-us/magazine/cc700332.aspx">
  ///	  The LINQ Enumerable Class
  ///	</seealso>
  IEnumerable<T> = interface(IEnumerable)

    ///	<summary>
    ///	  Returns an enumerator that iterates through a collection.
    ///	</summary>
    function GetEnumerator: IEnumerator<T>;

    ///	<summary>
    ///	  Returns the reference to the instance.
    ///	</summary>
    function AsObject: TObject;

    ///	<summary>
    ///	  Try getting the first element of a sequence.
    ///	</summary>
    function TryGetFirst(out value: T): Boolean; overload;

    ///	<summary>
    ///	  Returns the first element in a sequence that satisfies a specified
    ///	  condition.
    ///	</summary>
    function TryGetFirst(out value: T; const predicate: TPredicate<T>): Boolean; overload;

    ///	<summary>
    ///	  Try getting the last element of a sequence.
    ///	</summary>
    function TryGetLast(out value: T): Boolean; overload;

    ///	<summary>
    ///	  Try getting the last element in a sequence that satisfies a specified
    ///	  condition.
    ///	</summary>
    function TryGetLast(out value: T; const predicate: TPredicate<T>): Boolean; overload;

    ///	<summary>
    ///	  Returns the first element of a sequence.
    ///	</summary>
    function First: T; overload;

    ///	<summary>
    ///	  Returns the first element in a sequence that satisfies a specified
    ///	  condition.
    ///	</summary>
    function First(const predicate: TPredicate<T>): T; overload;

    ///	<summary>
    ///	  Returns the first element of a sequence, or a default value if the
    ///	  sequence contains no elements.
    ///	</summary>
    function FirstOrDefault: T; overload;

    ///	<summary>
    ///	  Returns the first element of a sequence, or the specified
    ///	  defaultValue if the sequence contains no elements.
    ///	</summary>
    function FirstOrDefault(const defaultValue: T): T; overload;

    ///	<summary>
    ///	  Returns the first element of the sequence that satisfies a condition
    ///	  or a default value if no such element is found.
    ///	</summary>
    function FirstOrDefault(const predicate: TPredicate<T>): T; overload;

    ///	<summary>
    ///	  Returns the last element of a sequence.
    ///	</summary>
    function Last: T; overload;

    ///	<summary>
    ///	  Returns the last element of a sequence that satisfies a specified
    ///	  condition.
    ///	</summary>
    function Last(const predicate: TPredicate<T>): T; overload;

    ///	<summary>
    ///	  Returns the last element of a sequence, or a default value if the
    ///	  sequence contains no elements.
    ///	</summary>
    function LastOrDefault: T; overload;

    ///	<summary>
    ///	  Returns the last element of a sequence, or the specified default
    ///	  value if the sequence contains no elements.
    ///	</summary>
    function LastOrDefault(const defaultValue: T): T; overload;

    ///	<summary>
    ///	  Returns the last element of a sequence that satisfies a condition or
    ///	  a default value if no such element is found.
    ///	</summary>
    function LastOrDefault(const predicate: TPredicate<T>): T; overload;

    ///	<summary>
    ///	  Returns the only element of a sequence, and throws an exception if
    ///	  there is not exactly one element in the sequence.
    ///	</summary>
    function Single: T; overload;

    ///	<summary>
    ///	  Returns the only element of a sequence, and throws an exception if
    ///	  there is not exactly one element in the sequence.
    ///	</summary>
    function Single(const predicate: TPredicate<T>): T; overload;

    ///	<summary>
    ///	  Returns the only element of a sequence, or a default value if the
    ///	  sequence is empty; this method throws an exception if there is more
    ///	  than one element in the sequence.
    ///	</summary>
    function SingleOrDefault: T; overload;

    ///	<summary>
    ///	  Returns the only element of a sequence that satisfies a specified
    ///	  condition or a default value if no such element exists; this method
    ///	  throws an exception if more than one element satisfies the condition.
    ///	</summary>
    function SingleOrDefault(const predicate: TPredicate<T>): T; overload;

    ///	<summary>
    ///	  Returns the element at a specified index in a sequence.
    ///	</summary>
    function ElementAt(index: Integer): T;

    ///	<summary>
    ///	  Returns the element at a specified index in a sequence or a default
    ///	  value if the index is out of range.
    ///	</summary>
    function ElementAtOrDefault(index: Integer): T;

    ///	<summary>
    ///	  Determines whether all elements of a sequence satisfy a condition.
    ///	</summary>
    function All(const predicate: TPredicate<T>): Boolean;

    ///	<summary>
    ///	  Determines whether any element of a sequence satisfies a condition.
    ///	</summary>
    function Any(const predicate: TPredicate<T>): Boolean;

    ///	<summary>
    ///	  Determines whether a sequence contains a specified element by using
    ///	  the default equality comparer.
    ///	</summary>
    function Contains(const item: T): Boolean; overload;

    ///	<summary>
    ///	  Determines whether a sequence contains a specified element by using a
    ///	  specified <c>IEqualityComparer{T}.</c>
    ///	</summary>
    function Contains(const item: T; const comparer: IEqualityComparer<T>): Boolean; overload;

    ///	<summary>
    ///	  Returns the minimum value in a sequence.
    ///	</summary>
    function Min: T;

    ///	<summary>
    ///	  Returns the maximum value in a sequence.
    ///	</summary>
    function Max: T;

    ///	<summary>
    ///	  Filters a sequence of values based on a predicate.
    ///	</summary>
    function Where(const predicate: TPredicate<T>): IEnumerable<T>;

    ///	<summary>
    ///	  Bypasses a specified number of elements in a sequence and then
    ///	  returns the remaining elements.
    ///	</summary>
    function Skip(count: Integer): IEnumerable<T>;

    ///	<summary>
    ///	  Bypasses elements in a sequence as long as a specified condition is
    ///	  true and then returns the remaining elements.
    ///	</summary>
    function SkipWhile(const predicate: TPredicate<T>): IEnumerable<T>; overload;

    ///	<summary>
    ///	  Bypasses elements in a sequence as long as a specified condition is
    ///	  true and then returns the remaining elements. The element's index is
    ///	  used in the logic of the predicate function.
    ///	</summary>
    function SkipWhile(const predicate: TFunc<T, Integer, Boolean>): IEnumerable<T>; overload;

    ///	<summary>
    ///	  Returns a specified number of contiguous elements from the start of a
    ///	  sequence.
    ///	</summary>
    function Take(count: Integer): IEnumerable<T>;

    ///	<summary>
    ///	  Returns elements from a sequence as long as a specified condition is
    ///	  true.
    ///	</summary>
    function TakeWhile(const predicate: TPredicate<T>): IEnumerable<T>; overload;

    ///	<summary>
    ///	  Returns elements from a sequence as long as a specified condition is
    ///	  true. The element's index is used in the logic of the predicate
    ///	  function.
    ///	</summary>
    function TakeWhile(const predicate: TFunc<T, Integer, Boolean>): IEnumerable<T>; overload;

    ///	<summary>
    ///	  Concatenates two sequences.
    ///	</summary>
    function Concat(const collection: IEnumerable<T>): IEnumerable<T>;
    

    ///	<summary>
    ///	  Inverts the order of the elements in a sequence.
    ///	</summary>
    function Reversed: IEnumerable<T>;

    ///	<summary>
    ///	  Performs the specified action on each element of a sequence.
    ///	</summary>
    procedure ForEach(const action: TAction<T>); overload;

    ///	<summary>
    ///	  Performs the specified action on each element of a sequence.
    ///	</summary>
    procedure ForEach(const action: TActionProc<T>); overload;

  {$IFDEF DELPHIXE_UP}
    /// <summary>
    /// Performs the specified action on each element of a sequence.
    /// </summary>
    procedure ForEach(const action: TActionMethod<T>); overload;
  {$ENDIF}

    ///	<summary>
    ///	  Determines whether two sequences are equal by comparing the elements
    ///	  by using the default equality comparer for their type.
    ///	</summary>
    function EqualsTo(const collection: IEnumerable<T>): Boolean; overload;

    ///	<summary>
    ///	  Determines whether two sequences are equal by comparing their
    ///	  elements by using a specified IEqualityComparer{T}.
    ///	</summary>
    function EqualsTo(const collection: IEnumerable<T>; const comparer: IEqualityComparer<T>): Boolean; overload;

    ///	<summary>
    ///	  Creates a new array which is filled with the elements in the
    ///	  collection.
    ///	</summary>
    function ToArray: TArray<T>;

    ///	<summary>
    ///	  Creates a new list which is filled with the elements in the
    ///	  collection.
    ///	</summary>
    function ToList: IList<T>;

    ///	<summary>
    ///	  Creates a new list which is filled with the elements in the
    ///	  collection.
    ///	</summary>
    function ToSet: ISet<T>;

    ///	<summary>
    ///	  The getter of the <see cref="Count" /> property.
    ///	</summary>
    function GetCount: Integer;

    ///	<summary>
    ///	  The getter of the <see cref="IsEmpty" /> property.
    ///	</summary>
    function GetIsEmpty: Boolean;

    ///	<summary>
    ///	  Gets the number of elements in the collection.
    ///	</summary>
    property Count: Integer read GetCount;

    ///	<summary>
    ///	  Gets a value which indicates whether this collection is empty or not.
    ///	</summary>
    property IsEmpty: Boolean read GetIsEmpty;
  end;

  ICollection = interface(IEnumerable)
    ['{AC8A0302-C530-46A0-83FC-D88302ECCE3D}']
  {$REGION 'Property Accessors'}
    function GetIsReadOnly: Boolean;
  {$ENDREGION}

    procedure Add(const item: TValue);
    procedure AddRange(const collection: IEnumerable);

    function Remove(const item: TValue): Boolean;
    procedure RemoveRange(const collection: IEnumerable); overload;

    procedure Clear;

    property IsReadOnly: Boolean read GetIsReadOnly;
  end;

  ///	<summary>
  ///	  Defines methods to manipulate generic collections.
  ///	</summary>
  ICollection<T> = interface(IEnumerable<T>)
  {$REGION 'Property Accessors'}
    function GetIsReadOnly: Boolean;
  {$ENDREGION}

    procedure Add(const item: T);
    procedure AddRange(const collection: array of T); overload;
    procedure AddRange(const collection: IEnumerable<T>); overload;
    procedure AddRange(const collection: TEnumerable<T>); overload;

    function Remove(const item: T): Boolean;
    procedure RemoveRange(const collection: array of T); overload;
    procedure RemoveRange(const collection: IEnumerable<T>); overload;
    procedure RemoveRange(const collection: TEnumerable<T>); overload;

    procedure Clear;

    function AsCollection: ICollection;

    property IsReadOnly: Boolean read GetIsReadOnly;
  end;

  IList = interface(ICollection)
    ['{43FF6143-3B87-4298-B48C-2ABB9353BF68}']
  {$REGION 'Property Accessors'}
    function GetItem(index: Integer): TValue;
    function GetOnChanged: IEvent;
    procedure SetItem(index: Integer; const item: TValue);
  {$ENDREGION}
    procedure Insert(index: Integer; const item: TValue);
    procedure InsertRange(index: Integer; const collection: IEnumerable);

    procedure Delete(index: Integer);
    procedure DeleteRange(index, count: Integer);

    procedure Exchange(index1, index2: Integer);
    procedure Move(currentIndex, newIndex: Integer);

    procedure Reverse;

    procedure Sort;

    function IndexOf(const item: TValue): Integer;
    function LastIndexOf(const item: TValue): Integer;

    property Items[index: Integer]: TValue read GetItem write SetItem; default;
    property OnChanged: IEvent read GetOnChanged;
  end;

  ///	<summary>
  ///	  Represents a collection of objects that can be individually accessed by
  ///	  index.
  ///	</summary>
  IList<T> = interface(ICollection<T>)
  {$REGION 'Property Accessors'}
    function GetItem(index: Integer): T;
    function GetOnChanged: ICollectionChangedEvent<T>;
    procedure SetItem(index: Integer; const item: T);
  {$ENDREGION}
    procedure Insert(index: Integer; const item: T);
    procedure InsertRange(index: Integer; const collection: array of T); overload;
    procedure InsertRange(index: Integer; const collection: IEnumerable<T>); overload;
    procedure InsertRange(index: Integer; const collection: TEnumerable<T>); overload;

    procedure Delete(index: Integer);
    procedure DeleteRange(index, count: Integer);

    procedure Exchange(index1, index2: Integer);
    procedure Move(currentIndex, newIndex: Integer);

    procedure Reverse;

    procedure Sort; overload;
    procedure Sort(const comparer: IComparer<T>); overload;
    procedure Sort(const comparer: TComparison<T>); overload;

    function IndexOf(const item: T): Integer;
    function LastIndexOf(const item: T): Integer;

    function AsList: IList;

    property Items[index: Integer]: T read GetItem write SetItem; default;
    property OnChanged: ICollectionChangedEvent<T> read GetOnChanged;
  end;

  IDictionary = interface(ICollection)
    ['{9AC642EE-F236-421D-8546-DCA0D8D53791}']
    procedure Add(const key, value: TValue);
    procedure AddOrSetValue(const key, value: TValue);
    procedure Remove(const key: TValue); overload;
    function ContainsKey(const key: TValue): Boolean;
    function ContainsValue(const value: TValue): Boolean;
    function TryGetValue(const key: TValue; out value: TValue): Boolean;

    function GetKeyType: PTypeInfo;
    function GetValueType: PTypeInfo;
    property KeyType: PTypeInfo read GetKeyType;
    property ValueType: PTypeInfo read GetValueType;
  end;

  ///	<summary>
  ///	  Represents a generic collection of key/value pairs.
  ///	</summary>
  IDictionary<TKey, TValue> = interface(ICollection<TPair<TKey, TValue>>)
  {$REGION 'Property Accessors'}
    function GetItem(const key: TKey): TValue;
    function GetKeys: ICollection<TKey>;
    function GetValues: ICollection<TValue>;
    function GetOnKeyChanged: ICollectionChangedEvent<TKey>;
    function GetOnValueChanged: ICollectionChangedEvent<TValue>;
    procedure SetItem(const key: TKey; const value: TValue);
  {$ENDREGION}
    procedure Add(const key: TKey; const value: TValue); overload;
    procedure AddOrSetValue(const key: TKey; const value: TValue);
    procedure Remove(const key: TKey); overload;
    function ContainsKey(const key: TKey): Boolean;
    function ContainsValue(const value: TValue): Boolean;
    function ExtractPair(const key: TKey): TPair<TKey, TValue>;
    function TryGetValue(const key: TKey; out value: TValue): Boolean;

    function AsDictionary: IDictionary;

    property Items[const key: TKey]: TValue read GetItem write SetItem; default;

    ///	<summary>
    ///	  Gets a read-only collection which contains all keys in the
    ///	  dictionary.
    ///	</summary>
    property Keys: ICollection<TKey> read GetKeys;

    ///	<summary>
    ///	  Gets a read-only collection which contains all values in the
    ///	  dictionary.
    ///	</summary>
    property Values: ICollection<TValue> read GetValues;

    property OnKeyChanged: ICollectionChangedEvent<TKey> read GetOnKeyChanged;
    property OnValueChanged: ICollectionChangedEvent<TValue> read GetOnValueChanged;
  end;

  IStack = interface(IEnumerable)
    ['{82F7B40F-3B32-417F-8001-51458BCE553A}']
  {$REGION 'Property Getters'}
    function GetOnChanged: IEvent;
  {$ENDREGION}
    procedure Clear;
    procedure Push(const item: TValue);
    function Pop: TValue;
    function Peek: TValue;
    function PeekOrDefault: TValue;
    function TryPeek(out item: TValue): Boolean;
    property OnChanged: IEvent read GetOnChanged;
  end;

  IStack<T> = interface(IEnumerable<T>)
  {$REGION 'Property Getters'}
    function GetOnChanged: ICollectionChangedEvent<T>;
  {$ENDREGION}
    procedure Clear;
    procedure Push(const item: T);
    function Pop: T;
    function Peek: T;
    function PeekOrDefault: T;
    function TryPeek(out item: T): Boolean;
    function AsStack: IStack;
    property OnChanged: ICollectionChangedEvent<T> read GetOnChanged;
  end;

  IQueue = interface(IEnumerable)
    ['{B3377E32-ADA1-414F-8762-1EA0E4FEF794}']
  {$REGION 'Property Getters'}
    function GetOnChanged: IEvent;
  {$ENDREGION}
    procedure Clear;
    procedure Enqueue(const item: TValue);
    function Dequeue: TValue;
    function Peek: TValue;
    function PeekOrDefault: TValue;
    function TryPeek(out item: TValue): Boolean;
    property OnChanged: IEvent read GetOnChanged;
  end;

  IQueue<T> = interface(IEnumerable<T>)
    ['{D305A076-3F19-497C-94E3-6BD1C7A30F3F}']
  {$REGION 'Property Getters'}
    function GetOnChanged: ICollectionChangedEvent<T>;
  {$ENDREGION}
    procedure Clear;
    procedure Enqueue(const item: T);
    function Dequeue: T;
    function Peek: T;
    function PeekOrDefault: T;
    function TryPeek(out item: T): Boolean;
    function AsQueue: IQueue;
    property OnChanged: ICollectionChangedEvent<T> read GetOnChanged;
  end;

  ISet = interface(ICollection)
    ['{D83ED568-A7C8-4142-BA0F-5A273AF1AA07}']
    procedure ExceptWith(const collection: IEnumerable);
    procedure IntersectWith(const collection: IEnumerable);
    procedure UnionWith(const collection: IEnumerable);
    function SetEquals(const collection: IEnumerable): Boolean;
    function Overlaps(const collection: IEnumerable): Boolean;
  end;

  ISet<T> = interface(ICollection<T>)
    procedure ExceptWith(const collection: IEnumerable<T>);
    procedure IntersectWith(const collection: IEnumerable<T>);
    procedure UnionWith(const collection: IEnumerable<T>);
    function SetEquals(const collection: IEnumerable<T>): Boolean;
    function Overlaps(const collection: IEnumerable<T>): Boolean;
    function AsSet: ISet;
  end;

  ///	<summary>
  ///	  Internal interface. Reserved for future use.
  ///	</summary>
  ICountable = interface
    ['{CA225A9C-B6FD-4D6E-B3BD-22119CCE6C87}']
    function GetCount: Integer;
    function GetIsEmpty: Boolean;

    property Count: Integer read GetCount;
    property IsEmpty: Boolean read GetIsEmpty;
  end;

  ///	<summary>
  ///	  Internal interface. Reserved for future use.
  ///	</summary>
  IElementType = interface
    ['{FE986DD7-41D5-4312-A2F9-94F7D9E642EE}']
    function GetElementType: PTypeInfo;

    property ElementType: PTypeInfo read GetElementType;
  end;

  ICollectionOwnership = interface
    ['{6D028EAF-3D14-4362-898C-BFAD1110547F}']

    {$REGION 'Property Accessors'}
      function GetOwnsObjects: Boolean;
      procedure SetOwnsObjects(const value: Boolean);
    {$ENDREGION}
    property OwnsObjects: Boolean read GetOwnsObjects write SetOwnsObjects;
  end;

  ///	<summary>
  ///	  Defines the ownership style of an instance.
  ///	</summary>
  TOwnershipType = (
    otReference,
    otOwned
  );

  TDictionaryOwnerships = Generics.Collections.TDictionaryOwnerships;

  ///	<summary>
  ///	  Provides static methods to create an instance of various interfaced
  ///	  generic collections such as <c>IList{T}</c>,
  ///	  <c>IDictionary{TKey, TValue}</c>.
  ///	</summary>
  TCollections = class
  public
    class function CreateList<T>: IList<T>; overload; static;
    class function CreateList<T>(const comparer: IComparer<T>): IList<T>; overload; static;
    class function CreateList<T: class>(ownsObjects: Boolean): IList<T>; overload; static;
    class function CreateList<T: class>(ownsObjects: Boolean; const comparer: IComparer<T>): IList<T>; overload; static;
    class function CreateObjectList<T: class>(ownsObjects: Boolean = True): IList<T>; overload; static;
    class function CreateObjectList<T: class>(ownsObjects: Boolean; const comparer: IComparer<T>): IList<T>; overload; static;

    class function CreateDictionary<TKey, TValue>: IDictionary<TKey, TValue>; overload; static;
    class function CreateDictionary<TKey, TValue>(capacity: Integer): IDictionary<TKey, TValue>; overload; static;
    class function CreateDictionary<TKey, TValue>(const comparer: IEqualityComparer<TKey>): IDictionary<TKey, TValue>; overload; static;
    class function CreateDictionary<TKey, TValue>(capacity: Integer; const comparer: IEqualityComparer<TKey>): IDictionary<TKey, TValue>; overload; static;
    class function CreateDictionary<TKey, TValue>(ownerships: TDictionaryOwnerships): IDictionary<TKey, TValue>; overload; static;
    class function CreateDictionary<TKey, TValue>(ownerships: TDictionaryOwnerships; capacity: Integer): IDictionary<TKey, TValue>; overload; static;
    class function CreateDictionary<TKey, TValue>(ownerships: TDictionaryOwnerships; capacity: Integer; const comparer: IEqualityComparer<TKey>): IDictionary<TKey, TValue>; overload; static;
    class function CreateDictionary<TKey, TValue>(dictionary: Generics.Collections.TDictionary<TKey, TValue>; ownership: TOwnershipType): IDictionary<TKey, TValue>; overload; static;

    class function CreateStack<T>: IStack<T>; overload; static;
    class function CreateStack<T: class>(ownsObjects: Boolean): IStack<T>; overload; static;

    class function CreateQueue<T>: IQueue<T>; overload; static;
    class function CreateQueue<T: class>(ownsObjects: Boolean): IQueue<T>; overload; static;

    class function CreateSet<T>: ISet<T>; overload;

    ///	<summary>
    ///	  Creates a readonly empty collection.
    ///	</summary>
    class function Empty<T>: IEnumerable<T>;
  end;

  TStringComparer = class(TCustomComparer<string>)
  private
    fLocaleOptions: TLocaleOptions;
    fIgnoreCase: Boolean;
    class var
      fOrdinal: TStringComparer;
      fOrdinalIgnoreCase: TStringComparer;
  protected
    function Compare(const Left, Right: string): Integer; override;
    function Equals(const Left, Right: string): Boolean;
      reintroduce; overload; override;
    function GetHashCode(const Value: string): Integer;
      reintroduce; overload; override;
  public
    constructor Create(localeOptions: TLocaleOptions; ignoreCase: Boolean);
    class destructor Destroy;

    class function Ordinal: TStringComparer;
    class function OrdinalIgnoreCase: TStringComparer;
  end;

const
  cnAdded = Generics.Collections.cnAdded;
  cnRemoved = Generics.Collections.cnRemoved;
  cnExtracted = Generics.Collections.cnExtracted;

  doOwnsKeys = Generics.Collections.doOwnsKeys;
  doOwnsValues = Generics.Collections.doOwnsValues;

implementation

uses
  Character,
  Spring.ResourceStrings,
  Spring.Collections.Sets,
  Spring.Collections.Stacks,
  Spring.Collections.Queues,
  Spring.Collections.Lists,
  Spring.Collections.Dictionaries,
  Spring.Collections.Extensions;


{$REGION 'TCollections'}

class function TCollections.CreateList<T>: IList<T>;
begin
  Result := TList<T>.Create;
end;

class function TCollections.CreateList<T>(const comparer: IComparer<T>): IList<T>;
begin
  Result := TList<T>.Create(comparer);
end;

class function TCollections.CreateList<T>(ownsObjects: Boolean): IList<T>;
begin
  Result := TCollections.CreateList<T>(ownsObjects, TComparer<T>.Default);
end;

class function TCollections.CreateList<T>(ownsObjects: Boolean;
  const comparer: IComparer<T>): IList<T>;
begin
  Result := TObjectList<T>.Create(comparer, ownsObjects);
end;

class function TCollections.CreateObjectList<T>(ownsObjects: Boolean): IList<T>;
begin
  Result := TObjectList<T>.Create(TComparer<T>.Default, ownsObjects);
end;

class function TCollections.CreateObjectList<T>(ownsObjects: Boolean; const comparer: IComparer<T>): IList<T>;
begin
  Result := TObjectList<T>.Create(comparer, ownsObjects);
end;

class function TCollections.CreateDictionary<TKey, TValue>(
  dictionary: Generics.Collections.TDictionary<TKey, TValue>;
  ownership: TOwnershipType): IDictionary<TKey, TValue>;
begin
  Guard.CheckNotNull(dictionary, 'dictionary');
  Result := TDictionary<TKey, TValue>.Create(dictionary, ownership);
end;

class function TCollections.CreateDictionary<TKey, TValue>: IDictionary<TKey, TValue>;
begin
  Result := TCollections.CreateDictionary<TKey,TValue>(0, TEqualityComparer<TKey>.Default);
end;

class function TCollections.CreateDictionary<TKey, TValue>(
  capacity: Integer): IDictionary<TKey, TValue>;
begin
  Result := TCollections.CreateDictionary<TKey, TValue>(capacity, TEqualityComparer<TKey>.Default);
end;

class function TCollections.CreateDictionary<TKey, TValue>(const comparer: IEqualityComparer<TKey>): IDictionary<TKey, TValue>;
begin
  Result := TCollections.CreateDictionary<TKey, TValue>(0, comparer);
end;

class function TCollections.CreateDictionary<TKey, TValue>(capacity: Integer;
  const comparer: IEqualityComparer<TKey>): IDictionary<TKey, TValue>;
var
  dictionary: Generics.Collections.TDictionary<TKey,TValue>;
begin
  Guard.CheckRange(capacity >= 0, 'capacity');
  dictionary := Generics.Collections.TDictionary<TKey,TValue>.Create(capacity, comparer);
  Result := TDictionary<TKey, TValue>.Create(dictionary, otOwned);
end;

class function TCollections.CreateDictionary<TKey, TValue>(
  ownerships: TDictionaryOwnerships): IDictionary<TKey, TValue>;
begin
  Result := TCollections.CreateDictionary<TKey, TValue>(ownerships, 0, TEqualityComparer<TKey>.Default);
end;

class function TCollections.CreateDictionary<TKey, TValue>(
  ownerships: TDictionaryOwnerships;
  capacity: Integer): IDictionary<TKey, TValue>;
begin
  Result := TCollections.CreateDictionary<TKey, TValue>(ownerships, capacity, TEqualityComparer<TKey>.Default);
end;

class function TCollections.CreateDictionary<TKey, TValue>(
  ownerships: TDictionaryOwnerships; capacity: Integer;
  const comparer: IEqualityComparer<TKey>): IDictionary<TKey, TValue>;
var
  dictionary: Generics.Collections.TObjectDictionary<TKey,TValue>;
begin
  dictionary := TObjectDictionary<TKey, TValue>.Create(ownerships, capacity, comparer);
  Result := TDictionary<TKey, TValue>.Create(dictionary, otOwned);
end;

class function TCollections.CreateStack<T>: IStack<T>;
var
  stack: Generics.Collections.TStack<T>;
begin
  stack := Generics.Collections.TStack<T>.Create;
  Result := TStack<T>.Create(stack, otOwned);
end;

class function TCollections.CreateStack<T>(ownsObjects: Boolean): IStack<T>;
var
  stack: Generics.Collections.TObjectStack<T>;
begin
  stack := TObjectStack<T>.Create(ownsObjects);
  Result := TStack<T>.Create(stack, otOwned);
end;

class function TCollections.CreateQueue<T>: IQueue<T>;
var
  queue: Generics.Collections.TQueue<T>;
begin
  queue := Generics.Collections.TQueue<T>.Create;
  Result := TQueue<T>.Create(queue, otOwned);
end;

class function TCollections.CreateQueue<T>(ownsObjects: Boolean): IQueue<T>;
var
  queue: Generics.Collections.TObjectQueue<T>;
begin
  queue := Generics.Collections.TObjectQueue<T>.Create(ownsObjects);
  Result := TQueue<T>.Create(queue, otOwned);
end;

class function TCollections.CreateSet<T>: ISet<T>;
begin
  Result := THashSet<T>.Create;
end;

class function TCollections.Empty<T>: IEnumerable<T>;
begin
  Result := TEmptyEnumerable<T>.Create;
end;

{$ENDREGION}


{$REGION 'TStringComparer'}

constructor TStringComparer.Create(localeOptions: TLocaleOptions;
  ignoreCase: Boolean);
begin
  inherited Create;
  fLocaleOptions := localeOptions;
  fIgnoreCase := ignoreCase;
end;

class destructor TStringComparer.Destroy;
begin
  FreeAndNil(fOrdinal);
  FreeAndNil(fOrdinalIgnoreCase);
end;

function TStringComparer.Compare(const Left, Right: string): Integer;
var
  L, R: string;
begin
  if fIgnoreCase then
  begin
{$IFNDEF DELPHIXE4_UP}
    L := TCharacter.ToUpper(Left);
    R := TCharacter.ToUpper(Right);
{$ELSE}
    L := Left.ToUpper;
    R := Right.ToUpper;
{$ENDIF}
  end else
  begin
    L := Left;
    R := Right;
  end;

  Result := CompareStr(L, R, fLocaleOptions);
end;

function TStringComparer.Equals(const Left, Right: string): Boolean;
var
  L, R: string;
begin
  if fIgnoreCase then
  begin
{$IFNDEF DELPHIXE4_UP}
    L := TCharacter.ToUpper(Left);
    R := TCharacter.ToUpper(Right);
{$ELSE}
    L := Left.ToUpper;
    R := Right.ToUpper;
{$ENDIF}
  end else
  begin
    L := Left;
    R := Right;
  end;

  Result := SameStr(L, R, fLocaleOptions);
end;

function TStringComparer.GetHashCode(const Value: string): Integer;
var
  s: string;
begin
  if fIgnoreCase then
{$IFNDEF DELPHIXE4_UP}
    S := TCharacter.ToUpper(Value)
{$ELSE}
    S := Value.ToUpper
{$ENDIF}
  else
    S := Value;

  Result := BobJenkinsHash(PChar(S)^, SizeOf(Char) * Length(S), 0);
end;

class function TStringComparer.Ordinal: TStringComparer;
begin
  if not Assigned(fOrdinal) then
    fOrdinal := TStringComparer.Create(loInvariantLocale, False);
  Result := fOrdinal;
end;

class function TStringComparer.OrdinalIgnoreCase: TStringComparer;
begin
  if not Assigned(fOrdinalIgnoreCase) then
    fOrdinalIgnoreCase := TStringComparer.Create(loInvariantLocale, True);
  Result := fOrdinalIgnoreCase;
end;

{$ENDREGION}


end.