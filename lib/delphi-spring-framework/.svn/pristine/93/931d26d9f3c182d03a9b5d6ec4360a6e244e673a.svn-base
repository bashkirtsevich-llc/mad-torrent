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

unit Spring.Collections.Queues;

interface

uses
  Generics.Collections,
  Spring,
  Spring.Collections,
  Spring.Collections.Base;

type
  TQueue<T> = class(TEnumerableBase<T>, IQueue<T>, IQueue)
  private
    type
      TGenericQueue = Generics.Collections.TQueue<T>;
  private
    fQueue: TGenericQueue;
    fOwnership: TOwnershipType;
    fOnChanged: ICollectionChangedEvent<T>;
    function GetOnChanged: ICollectionChangedEvent<T>;
    function NonGenericGetOnChanged: IEvent;
    function IQueue.GetOnChanged = NonGenericGetOnChanged;
  protected
    function GetCount: Integer; override;

    procedure NonGenericEnqueue(const item: TValue);
    function NonGenericDequeue: TValue;
    function NonGenericPeek: TValue;
    function NonGenericPeekOrDefault: TValue;
    function NonGenericTryPeek(out item: TValue): Boolean;

    procedure Changed(const item: T; action: TCollectionChangedAction); virtual;

    procedure IQueue.Enqueue = NonGenericEnqueue;
    function IQueue.Dequeue = NonGenericDequeue;
    function IQueue.Peek = NonGenericPeek;
    function IQueue.PeekOrDefault = NonGenericPeekOrDefault;
    function IQueue.TryPeek = NonGenericTryPeek;
  public
    constructor Create; overload;
    constructor Create(const collection: IEnumerable<T>); overload;
    constructor Create(const collection: TEnumerable<T>); overload;
    constructor Create(queue: TGenericQueue; ownership: TOwnershipType); overload;
    destructor Destroy; override;
    function GetEnumerator: IEnumerator<T>; override;
    procedure Enqueue(const item: T);
    function Dequeue: T;
    function Peek: T;
    function PeekOrDefault: T;
    function TryPeek(out item: T): Boolean;
    procedure Clear;
    procedure TrimExcess;
    function AsQueue: IQueue;
    property OnChanged: ICollectionChangedEvent<T> read GetOnChanged;
  end;

implementation

uses
  Spring.Collections.Events,
  Spring.Collections.Extensions;


{$REGION 'TQueue<T>'}

constructor TQueue<T>.Create(queue: TGenericQueue; ownership: TOwnershipType);
begin
  fQueue := queue;
  fOwnership := ownership;
  fOnChanged := TCollectionChangedEventImpl<T>.Create;
end;

constructor TQueue<T>.Create(const collection: IEnumerable<T>);
var
  item: T;
begin
  Create;
  for item in collection do
  begin
    Enqueue(item);
  end;
end;

constructor TQueue<T>.Create(const collection: TEnumerable<T>);
var
  item: T;
begin
  Create;
  for item in collection do
  begin
    Enqueue(item);
  end;
end;

constructor TQueue<T>.Create;
var
  queue: TGenericQueue;
begin
  queue := TGenericQueue.Create;
  Create(queue, otOwned);
end;

destructor TQueue<T>.Destroy;
begin
  if fOwnership = otOwned then
  begin
    Clear;
    fQueue.Free;
  end;
  inherited Destroy;
end;

function TQueue<T>.GetEnumerator: IEnumerator<T>;
begin
  Result := TEnumeratorAdapter<T>.Create(fQueue);
end;

procedure TQueue<T>.Enqueue(const item: T);
begin
  fQueue.Enqueue(item);

  Changed(item, caAdded);
end;

function TQueue<T>.Dequeue: T;
begin
  Result := fQueue.Dequeue;

  Changed(Result, caRemoved);
end;

function TQueue<T>.AsQueue: IQueue;
begin
  Result := Self;
end;

procedure TQueue<T>.Clear;
begin
  while Count > 0 do
    Dequeue;
  TrimExcess;
end;

function TQueue<T>.Peek: T;
begin
  Result := fQueue.Peek;
end;

function TQueue<T>.PeekOrDefault: T;
begin
  if fQueue.Count > 0 then
    Result := fQueue.Peek
  else
    Result := Default(T);
end;

procedure TQueue<T>.TrimExcess;
begin
  fQueue.TrimExcess;
end;

function TQueue<T>.TryPeek(out item: T): Boolean;
begin
  Result := fQueue.Count > 0;
  if Result then
    item := fQueue.Peek
  else
    item := Default(T);
end;

function TQueue<T>.GetCount: Integer;
begin
  Result := fQueue.Count;
end;

function TQueue<T>.GetOnChanged: ICollectionChangedEvent<T>;
begin
  Result := fOnChanged;
end;

function TQueue<T>.NonGenericDequeue: TValue;
begin
  Result := TValue.From<T>(Dequeue);
end;

procedure TQueue<T>.NonGenericEnqueue(const item: TValue);
begin
  Enqueue(item.AsType<T>);
end;

function TQueue<T>.NonGenericGetOnChanged: IEvent;
begin
  Result := GetOnChanged;
end;

function TQueue<T>.NonGenericPeek: TValue;
begin
  Result := TValue.From<T>(Peek);
end;

function TQueue<T>.NonGenericPeekOrDefault: TValue;
begin
  Result := TValue.From<T>(PeekOrDefault);
end;

function TQueue<T>.NonGenericTryPeek(out item: TValue): Boolean;
var
  value: T;
begin
  Result := TryPeek(value);
  if Result then
    item := TValue.From<T>(value);
end;

procedure TQueue<T>.Changed(const item: T; action: TCollectionChangedAction);
begin
  fOnChanged.Invoke(Self, item, action);
end;

{$ENDREGION}

end.
