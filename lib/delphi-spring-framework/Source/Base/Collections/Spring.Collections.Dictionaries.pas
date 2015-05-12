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

unit Spring.Collections.Dictionaries;

interface

uses
  Generics.Collections,
  Spring,
  Spring.Collections,
  Spring.Collections.Base;

type

  TDictionary<TKey, TValue> = class(TCollectionBase<TPair<TKey, TValue>>, IDictionary<TKey, TValue>, IDictionary)
  protected
    type
      TGenericDictionary = Generics.Collections.TDictionary<TKey, TValue>;
      TGenericObjectDictionary = Generics.Collections.TObjectDictionary<TKey, TValue>;
      TGenericPair = Generics.Collections.TPair<TKey,TValue>;

      ///	<summary>
      ///	  Provides a read-only ICollection{TKey}	implementation
      ///	</summary>
      TKeyCollection = class(TContainedCollectionBase<TKey>, ICollection<TKey>)
      private
        fDictionary: TGenericDictionary;
      protected
        function GetCount: Integer; override;
        function GetIsReadOnly: Boolean; override;
      public
        constructor Create(const controller: IInterface; dictionary: TGenericDictionary);
      {$REGION 'IEnumerable<TKey>'}
        function GetEnumerator: IEnumerator<TKey>; override;
        function Contains(const item: TKey): Boolean; override;
        function ToArray: TArray<TKey>; override;
      {$ENDREGION}

      {$REGION 'ICollection<TKey>'}
        procedure Add(const item: TKey); overload; override;
        procedure Clear; override;
        function Remove(const item: TKey): Boolean; overload; override;
        function Extract(const item: TKey): TKey;
      {$ENDREGION}
      end;

      ///	<summary>
      ///	  Provides a read-only ICollection{TValue} implementation
      ///	</summary>
      TValueCollection = class(TContainedCollectionBase<TValue>, ICollection<TValue>)
      private
        fDictionary: TGenericDictionary;
      protected
        function GetCount: Integer; override;
        function GetIsReadOnly: Boolean; override;
      public
        constructor Create(const controller: IInterface; dictionary: TGenericDictionary);
      {$REGION 'IEnumerable<TValue>'}
        function GetEnumerator: IEnumerator<TValue>; override;
        function Contains(const item: TValue): Boolean; override;
        function ToArray: TArray<TValue>; override;
      {$ENDREGION}

      {$REGION 'ICollection<TValue>'}
        procedure Add(const item: TValue); overload; override;
        procedure Clear; override;
        function Remove(const item: TValue): Boolean; overload; override;
        function Extract(const item: TValue): TValue;
        property IsReadOnly: Boolean read GetIsReadOnly;
      {$ENDREGION}
      end;
  private
    fDictionary: TGenericDictionary;
    fOwnership: TOwnershipType;
    fKeys: TKeyCollection;
    fValues: TValueCollection;
    fOnKeyChanged: ICollectionChangedEvent<TKey>;
    fOnValueChanged: ICollectionChangedEvent<TValue>;
    procedure DoKeyNotify(Sender: TObject; const Item: TKey; Action: TCollectionNotification);
    procedure DoValueNotify(Sender: TObject; const Item: TValue; Action: TCollectionNotification);
    function GetOnKeyChanged: ICollectionChangedEvent<TKey>;
    function GetOnValueChanged: ICollectionChangedEvent<TValue>;
  protected
    procedure NonGenericAdd(const key, value: Spring.TValue);
    procedure IDictionary.Add = NonGenericAdd;
    procedure NonGenericAddOrSetValue(const key, value: Spring.TValue);
    procedure IDictionary.AddOrSetValue = NonGenericAddOrSetValue;
    procedure NonGenericRemove(const key: Spring.TValue); overload;
    procedure IDictionary.Remove = NonGenericRemove;
    function NonGenericContainsKey(const key: Spring.TValue): Boolean;
    function IDictionary.ContainsKey = NonGenericContainsKey;
    function NonGenericContainsValue(const value: Spring.TValue): Boolean;
    function IDictionary.ContainsValue = NonGenericContainsValue;
    function NonGenericTryGetValue(const key: Spring.TValue; out value: Spring.TValue): Boolean;
    function IDictionary.TryGetValue = NonGenericTryGetValue;

    function GetKeyType: PTypeInfo;
    function GetValueType: PTypeInfo;
  public
    constructor Create(dictionary: TGenericDictionary;
      ownership: TOwnershipType = otReference); overload;
    constructor Create; overload;
    destructor Destroy; override;

  {$REGION 'Implements IEnumerable<TPair<TKey, TValue>>'}
    function GetEnumerator: IEnumerator<TPair<TKey,TValue>>; override;
    function GetCount: Integer; override;
    function Contains(const item: TPair<TKey,TValue>): Boolean; override;
    function ToArray: TArray<TPair<TKey,TValue>>; override;
  {$ENDREGION}

  {$REGION 'Implements ICollection<TPair<TKey, TValue>>'}
    procedure Add(const item: TPair<TKey,TValue>); overload; override;
    procedure Clear; override;
    function Remove(const item: TPair<TKey,TValue>): Boolean; overload; override;
    function Extract(const item: TPair<TKey,TValue>): TPair<TKey,TValue>;
  {$ENDREGION}

  {$REGION 'Implements IDictionary<TKey,TValue>'}
    function GetItem(const key: TKey): TValue; virtual;
    function GetKeys: ICollection<TKey>;
    function GetValues: ICollection<TValue>;
    procedure SetItem(const key: TKey; const value: TValue); virtual;
    procedure Add(const key: TKey; const value: TValue); reintroduce; overload; virtual;
    procedure AddOrSetValue(const key: TKey; const value: TValue); virtual;
    procedure Remove(const key: TKey); reintroduce; overload;
    function ContainsKey(const key: TKey): Boolean;
    function ContainsValue(const value: TValue): Boolean;
    function ExtractPair(const key: TKey): TPair<TKey, TValue>;
    function TryGetValue(const key: TKey; out value: TValue): Boolean; virtual;
    function AsDictionary: IDictionary;
    property Items[const key: TKey]: TValue read GetItem write SetItem; default;
    property Keys: ICollection<TKey> read GetKeys;
    property Values: ICollection<TValue> read GetValues;
    property OnKeyChanged: ICollectionChangedEvent<TKey> read GetOnKeyChanged;
    property OnValueChanged: ICollectionChangedEvent<TValue> read GetOnValueChanged;
  {$ENDREGION}
  end;

implementation

uses
  Generics.Defaults,
  Spring.Collections.Events,
  Spring.Collections.Extensions;


{$REGION 'TDictionary<TKey, TValue>'}

constructor TDictionary<TKey, TValue>.Create(
  dictionary: TGenericDictionary; ownership: TOwnershipType);
begin
  inherited Create;
  fDictionary := dictionary;
  fOwnership := ownership;
  fDictionary.OnKeyNotify := DoKeyNotify;
  fDictionary.OnValueNotify := DoValueNotify;
  fOnKeyChanged := TCollectionChangedEventImpl<TKey>.Create;
  fOnValueChanged := TCollectionChangedEventImpl<TValue>.Create;
end;

constructor TDictionary<TKey, TValue>.Create;
var
  dictionary: TGenericDictionary;
begin
  dictionary := TGenericDictionary.Create;
  Create(dictionary, otOwned);
end;

destructor TDictionary<TKey, TValue>.Destroy;
begin
  fKeys.Free;
  fValues.Free;
  if fOwnership = otOwned then
  begin
    fDictionary.Free;
  end;
  inherited Destroy;
end;

procedure TDictionary<TKey, TValue>.DoKeyNotify(Sender: TObject;
  const Item: TKey; Action: TCollectionNotification);
begin
  fOnKeyChanged.Invoke(Sender, item, TCollectionChangedAction(action));
end;

procedure TDictionary<TKey, TValue>.DoValueNotify(Sender: TObject;
  const Item: TValue; Action: TCollectionNotification);
begin
  fOnValueChanged.Invoke(Sender, item, TCollectionChangedAction(action));
end;

function TDictionary<TKey, TValue>.GetEnumerator: IEnumerator<TPair<TKey, TValue>>;
begin
  Result := TEnumeratorAdapter<TPair<TKey, TValue>>.Create(fDictionary);
end;

procedure TDictionary<TKey, TValue>.Add(const item: TPair<TKey, TValue>);
begin
  fDictionary.Add(item.Key, item.Value);
end;

procedure TDictionary<TKey, TValue>.Clear;
begin
  fDictionary.Clear;
end;

function TDictionary<TKey, TValue>.Contains(
  const item: TPair<TKey, TValue>): Boolean;
var
  value: TValue;
  comparer: IEqualityComparer<TValue>;
begin
  Result := fDictionary.TryGetValue(item.Key, value);
  if Result then
  begin
    comparer := TEqualityComparer<TValue>.Default;
    Result := comparer.Equals(value, item.Value);
  end;
end;

function TDictionary<TKey, TValue>.Remove(
  const item: TPair<TKey, TValue>): Boolean;
var
  value: TValue;
  comparer: IEqualityComparer<TValue>;
begin
  Result := fDictionary.TryGetValue(item.Key, value);
  if Result then
  begin
    comparer := TEqualityComparer<TValue>.Default;
    Result := comparer.Equals(value, item.Value);
    if Result then
    begin
      fDictionary.Remove(item.Key);
    end;
  end;
end;

function TDictionary<TKey, TValue>.Extract(
  const item: TPair<TKey, TValue>): TPair<TKey, TValue>;
var
  value: TValue;
  found: Boolean;
  comparer: IEqualityComparer<TValue>;
begin
  found := fDictionary.TryGetValue(item.Key, value);
  if found then
  begin
    comparer := TEqualityComparer<TValue>.Default;
    found := comparer.Equals(value, item.Value);
    if found then
    begin
      Result := fDictionary.ExtractPair(item.Key);
    end;
  end;
  if not found then
  begin
    Result.Key := Default(TKey);
    Result.Value := Default(TValue);
  end;
end;

function TDictionary<TKey, TValue>.ToArray: TArray<TPair<TKey, TValue>>;
var
  pair: TPair<TKey, TValue>;
  index: Integer;
begin
  SetLength(Result, fDictionary.Count);
  index := 0;
  for pair in fDictionary do
  begin
    Result[index].Key := pair.Key;
    Result[index].Value := pair.Value;
    Inc(index);
  end;
end;

function TDictionary<TKey, TValue>.GetCount: Integer;
begin
  Result := fDictionary.Count;
end;

procedure TDictionary<TKey, TValue>.Add(const key: TKey;
  const value: TValue);
begin
  fDictionary.Add(key, value);
end;

procedure TDictionary<TKey, TValue>.AddOrSetValue(const key: TKey;
  const value: TValue);
begin
  fDictionary.AddOrSetValue(key, value);
end;

function TDictionary<TKey, TValue>.AsDictionary: IDictionary;
begin
  Result := Self;
end;

function TDictionary<TKey, TValue>.ContainsKey(const key: TKey): Boolean;
begin
  Result := fDictionary.ContainsKey(key);
end;

function TDictionary<TKey, TValue>.ContainsValue(
  const value: TValue): Boolean;
begin
  Result := fDictionary.ContainsValue(value);
end;

function TDictionary<TKey, TValue>.ExtractPair(
  const key: TKey): TPair<TKey, TValue>;
begin
  Result := fDictionary.ExtractPair(key);
end;

function TDictionary<TKey, TValue>.TryGetValue(const key: TKey;
  out value: TValue): Boolean;
begin
  Result := fDictionary.TryGetValue(key, value);
end;

procedure TDictionary<TKey, TValue>.Remove(const key: TKey);
begin
  fDictionary.Remove(key);
end;

function TDictionary<TKey, TValue>.GetKeys: ICollection<TKey>;
begin
  if fKeys = nil then
  begin
    fKeys := TKeyCollection.Create(Self, fDictionary);
  end;
  Result := fKeys;
end;

function TDictionary<TKey, TValue>.GetKeyType: PTypeInfo;
begin
  Result := TypeInfo(TKey);
end;

function TDictionary<TKey, TValue>.GetOnKeyChanged: ICollectionChangedEvent<TKey>;
begin
  Result := fOnKeyChanged;
end;

function TDictionary<TKey, TValue>.GetOnValueChanged: ICollectionChangedEvent<TValue>;
begin
  Result := fOnValueChanged;
end;

function TDictionary<TKey, TValue>.GetValues: ICollection<TValue>;
begin
  if fValues = nil then
  begin
    fValues := TValueCollection.Create(Self, fDictionary);
  end;
  Result := fValues;
end;

function TDictionary<TKey, TValue>.GetValueType: PTypeInfo;
begin
  Result := TypeInfo(TValue);
end;

procedure TDictionary<TKey, TValue>.NonGenericAdd(const key,
  value: Spring.TValue);
begin
  Add(key.AsType<TKey>, value.AsType<TValue>);
end;

procedure TDictionary<TKey, TValue>.NonGenericAddOrSetValue(const key,
  value: Spring.TValue);
begin
  AddOrSetValue(key.AsType<TKey>, value.AsType<TValue>);
end;

function TDictionary<TKey, TValue>.NonGenericContainsKey(
  const key: Spring.TValue): Boolean;
begin
  Result := ContainsKey(key.AsType<TKey>);
end;

function TDictionary<TKey, TValue>.NonGenericContainsValue(
  const value: Spring.TValue): Boolean;
begin
  Result := ContainsValue(value.AsType<TValue>);
end;

procedure TDictionary<TKey, TValue>.NonGenericRemove(const key: Spring.TValue);
begin
  Remove(key.AsType<TKey>);
end;

function TDictionary<TKey, TValue>.NonGenericTryGetValue(
  const key: Spring.TValue; out value: Spring.TValue): Boolean;
var
  item: TValue;
begin
  Result := TryGetValue(key.AsType<TKey>, item);
  if Result then
    value := Spring.TValue.From<TValue>(item);
end;

function TDictionary<TKey, TValue>.GetItem(const key: TKey): TValue;
begin
  Result := fDictionary[key];
end;

procedure TDictionary<TKey, TValue>.SetItem(const key: TKey;
  const value: TValue);
begin
  fDictionary.AddOrSetValue(key, value);
end;

{$ENDREGION}


{$REGION 'TDictionary<TKey, TValue>.TKeyCollection'}

constructor TDictionary<TKey, TValue>.TKeyCollection.Create(
  const controller: IInterface; dictionary: TGenericDictionary);
begin
  inherited Create(controller);
  fDictionary := dictionary;
end;

function TDictionary<TKey, TValue>.TKeyCollection.Contains(
  const item: TKey): Boolean;
begin
  Result := fDictionary.ContainsKey(item);
end;

function TDictionary<TKey, TValue>.TKeyCollection.ToArray: TArray<TKey>;
var
  key: TKey;
  index: Integer;
begin
  index := 0;
  SetLength(Result, fDictionary.Count);
  for key in fDictionary.Keys do
  begin
    Result[index] := key;
    Inc(index);
  end;
end;

function TDictionary<TKey, TValue>.TKeyCollection.GetEnumerator: IEnumerator<TKey>;
begin
  Result := TEnumeratorAdapter<TKey>.Create(fDictionary.Keys);
end;

function TDictionary<TKey, TValue>.TKeyCollection.GetCount: Integer;
begin
  Result := fDictionary.Count;
end;

function TDictionary<TKey, TValue>.TKeyCollection.GetIsReadOnly: Boolean;
begin
  Result := True;
end;

procedure TDictionary<TKey, TValue>.TKeyCollection.Add(const item: TKey);
begin
  raise ENotSupportedException.Create('Add');
end;

procedure TDictionary<TKey, TValue>.TKeyCollection.Clear;
begin
  raise ENotSupportedException.Create('Clear');
end;

function TDictionary<TKey, TValue>.TKeyCollection.Extract(
  const item: TKey): TKey;
begin
  raise ENotSupportedException.Create('Extract');
end;

function TDictionary<TKey, TValue>.TKeyCollection.Remove(
  const item: TKey): Boolean;
begin
  raise ENotSupportedException.Create('Remove');
end;

{$ENDREGION}


{$REGION 'TDictionary<TKey, TValue>.TValueCollection'}

constructor TDictionary<TKey, TValue>.TValueCollection.Create(
  const controller: IInterface; dictionary: TGenericDictionary);
begin
  inherited Create(controller);
  fDictionary := dictionary;
end;

function TDictionary<TKey, TValue>.TValueCollection.Contains(
  const item: TValue): Boolean;
begin
  Result := fDictionary.ContainsValue(item);
end;

function TDictionary<TKey, TValue>.TValueCollection.ToArray: TArray<TValue>;
var
  value: TValue;
  index: Integer;
begin
  index := 0;
  SetLength(Result, fDictionary.Count);
  for value in fDictionary.Values do
  begin
    Result[index] := value;
    Inc(index);
  end;
end;

function TDictionary<TKey, TValue>.TValueCollection.GetEnumerator: IEnumerator<TValue>;
begin
  Result := TEnumeratorAdapter<TValue>.Create(fDictionary.Values);
end;

function TDictionary<TKey, TValue>.TValueCollection.GetCount: Integer;
begin
  Result := fDictionary.Values.Count;
end;

function TDictionary<TKey, TValue>.TValueCollection.GetIsReadOnly: Boolean;
begin
  Result := True;
end;

procedure TDictionary<TKey, TValue>.TValueCollection.Add(const item: TValue);
begin
  raise ENotSupportedException.Create('Add');
end;

procedure TDictionary<TKey, TValue>.TValueCollection.Clear;
begin
  raise ENotSupportedException.Create('Clear');
end;

function TDictionary<TKey, TValue>.TValueCollection.Extract(
  const item: TValue): TValue;
begin
  raise ENotSupportedException.Create('Extract');
end;

function TDictionary<TKey, TValue>.TValueCollection.Remove(
  const item: TValue): Boolean;
begin
  raise ENotSupportedException.Create('Remove');
end;

{$ENDREGION}

end.
