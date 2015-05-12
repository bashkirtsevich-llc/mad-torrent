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

unit Spring.Events;

interface

uses
  Classes,
  Generics.Collections,
  Spring,
  Spring.Events.Base,
  TypInfo;

type
  PMethod = ^TMethod;

  ///	<summary>
  ///	  Internal Use.
  ///	</summary>
  TMethodInvocations = class
  private
    const
      paEAX = Word(0);
      paEDX = Word(1);
      paECX = Word(2);
      paStack = Word(3);

    type
      PParameterInfos = ^TParameterInfos;
      TParameterInfos = array[0..255] of ^PTypeInfo;

      PParameters = ^TParameters;
      TParameters = packed record
      public
{$IFNDEF CPUX64}
        Registers: array[paEDX..paECX] of Cardinal;
        EAXRegister: Cardinal;
        ReturnAddress: Pointer;
{$ENDIF}
        Stack: array[0..1023] of Byte;
      end;

      PMethodInfo = ^TMethodInfo;
      TMethodInfo = record
        TypeData: PTypeData;
        ParamInfos: PParameterInfos;
        StackSize: Integer;
        CallConvention: TCallConv;
{$IFDEF CPUX64}
        RegisterFlag: Word;
{$ENDIF CPUX64}
        constructor Create(typeInfo: PTypeInfo);
      end;

      TMethodInvokeEvent = procedure(Params: Pointer; StackSize: Integer) of object;
  private
    fMethodType: PTypeInfo;
    fMethodInfo: TMethodInfo;
    fMethodInvokeEvent: TMethodInvokeEvent;
  protected
    procedure InternalInvokeHandlers(Params: PParameters);
    procedure InvokeEventHandlerStub;
  public
    constructor Create(methodTypeInfo: PTypeInfo; methodInvokeEvent: TMethodInvokeEvent);
  end;

  TEvent = class(TEventBase)
  private
    fInvocations: TMethodInvocations;
    fTypeInfo: PTypeInfo;
    procedure InternalInvoke(Params: Pointer; StackSize: Integer);
  public
    constructor Create(typeInfo: PTypeInfo);
    destructor Destroy; override;
  end;

  TEvent<T> = class(TEvent, IEvent<T>)
  private
    function GetInvoke: T;
  public
    constructor Create;

    procedure Add(handler: T); overload;
    procedure Remove(handler: T); overload;
    procedure ForEach(const action: TAction<T>);

    property Invoke: T read GetInvoke;
  end;

  IMulticastNotifyEvent = IEvent<TNotifyEvent>;

  TMulticastNotifyEvent = TEvent<TNotifyEvent>;

implementation

uses
  Rtti,
  Spring.ResourceStrings;


{$REGION 'TMethodInfo'}

function AdditionalInfoOf(TypeData: PTypeData): Pointer;
var
  P: PByte;
  I: Integer;
begin
  P := @TypeData^.ParamList;
  // Skip parameter names and types
  for I := 1 to TypeData^.ParamCount do
  begin
    Inc(P, 1 + P[1] + 1);
    Inc(P, P[0] + 1 );
  end;
  if TypeData^.MethodKind = mkFunction then
    // Skip return type name and info
    Inc(P, P[0] + 1 + 4);
  Result := P;
end;

function GetTypeSize(typeInfo: PTypeInfo): Integer;
var
  typeData: PTypeData;
const
  COrdinalSizes: array[TOrdType] of Integer = (1, 1, 2, 2, 4, 4);
  CFloatSizes: array[TFloatType] of Integer = (4, 8, SizeOf(Extended), 8, 8);
  CSetSizes: array[TOrdType] of Integer = (1, 1, 2, 2, 4, 4);
begin
  case typeInfo^.Kind of
    tkChar:
      Result := 1;
    tkWChar:
      Result := 2;
    tkInteger, tkEnumeration:
      begin
        typeData := GetTypeData(typeInfo);
        Result := COrdinalSizes[typeData.OrdType];
      end;
    tkFloat:
      begin
        typeData := GetTypeData(typeInfo);
        Result := CFloatSizes[typeData^.FloatType];
      end;
    tkString, tkLString, tkUString, tkWString, tkInterface, tkClass, tkClassRef, tkDynArray, tkPointer:
      Result := SizeOf(Pointer);
    tkMethod:
      Result := SizeOf(TMethod);
    tkInt64:
      Result := 8;
    tkVariant:
      Result := 16;
    tkSet:
      begin
        // big sets have no typeInfo for now
        typeData := GetTypeData(typeInfo);
        Result := CSetSizes[typeData^.OrdType];
      end;
    tkRecord:
      begin
        typeData := GetTypeData(typeInfo);
        Result := typeData.RecSize;
      end;
    tkArray:
      begin
        typeData := GetTypeData(typeInfo);
        Result := typeData.ArrayData.Size;
      end;
    else
      begin
        Assert(False, 'Unsupported type');
        Result := -1;
      end;
  end;
end;

procedure InvokeMethod(const Method: TMethod;
  Parameters: Pointer; StackSize: Integer);
const
  PointerSize = SizeOf(Pointer);
  paEDX = Word(1);
  paECX = Word(2);
type
  TParameters = packed record
  public
{$IFNDEF CPUX64}
    Registers: array[paEDX..paECX] of Cardinal;
    EAXRegister: Cardinal;
    ReturnAddress: Pointer;
{$ENDIF}
    Stack: array[0..1023] of Byte;
  end;
{$IFNDEF CPUX64}
asm
  push ebp
  mov ebp,esp
  push eax // ebp-4 = Method
  push ebx
  mov ebx, edx // ebx = Parameters

  // if StackSize > 0
  test ecx,ecx
  jz @@no_stack

  // stack address alignment
  add ecx,PointerSize-1
  and ecx,not(PointerSize-1)
  and ecx,$ffff
  sub esp,ecx

  // put stack address as second parameter
  mov edx,esp

  // put params on stack as first parameter
  lea eax,[ebx].TParameters.Stack

  call Move

@@no_stack:
  mov edx,[ebx].TParameters.Registers.dword[0]
  mov ecx,[ebx].TParameters.Registers.dword[4]
  mov ebx,[ebp-$04]
  mov eax,[ebx].TMethod.Data
  call [ebx].TMethod.Code

  pop ebx
  pop eax
  mov esp,ebp
  pop ebp
end;
{$ELSE}
asm
  .params 60
  mov [rbp+$200],Method
  mov [rbp+$208],Parameters
  test r8,r8
  jz @@no_stack

  // put params on stack as first parameter
  lea rcx,[Parameters].TParameters.Stack

  // put stack address as second parameter
  mov rdx,rsp

  call Move

  mov rdx,[rbp+$208]

@@no_stack:
  mov rcx,[rdx].TParameters.Stack.qword[0]
  mov r8,[rdx].TParameters.Stack.qword[16]
  mov r9,[rdx].TParameters.Stack.qword[24]

  movsd xmm0,[rdx].TParameters.Stack.qword[0]
  movsd xmm1,[rdx].TParameters.Stack.qword[8]
  movsd xmm2,[rdx].TParameters.Stack.qword[16]
  movsd xmm3,[rdx].TParameters.Stack.qword[24]

  mov rdx,[rdx].TParameters.Stack.qword[8]

  mov rax,[rbp+$200]
  lea rax,[rax]
  mov rcx,[rax].TMethod.Data
  call [rax].TMethod.Code
end;
{$ENDIF}

constructor TMethodInvocations.TMethodInfo.Create(typeInfo: PTypeInfo);

  function PassByRef(P: PByte; ParamInfos: PParameterInfos; I: Integer): Boolean;
  begin
    Result := (TParamFlags(P[0]) * [pfVar, pfConst, pfAddress, pfReference, pfOut] <> [])
      and not (ParamInfos^[I]^.Kind in [tkFloat, tkMethod, tkInt64]);
  end;

  function Align4(Value: Integer): Integer;
  begin
    Result := (Value + 3) and not 3;
  end;

var
  typeData: PTypeData;
  P: PByte;
  I: Integer;
{$IFNDEF CPUX64}
  curReg: Integer;
  Size: Integer;
{$ENDIF}
begin
  typeData := GetTypeData(typeInfo);
  Self.TypeData := typeData;
  P := AdditionalInfoOf(typeData);
  CallConvention := TCallConv(PByte(p)^);
  ParamInfos := PParameterInfos(Cardinal(P) + 1);

  StackSize := SizeOf(Pointer); // Self in stack
{$IFNDEF CPUX64}
  curReg := paStack;
  if CallConvention = ccReg then
  begin
    curReg := paEDX;
    StackSize := 0;
  end;
{$ENDIF}

  P := @typeData^.ParamList;

  for I := 0 to typeData^.ParamCount - 1 do
  begin
{$IFNDEF CPUX64}
    if PassByRef(P, ParamInfos, I) then
      Size := 4
    else
      Size := GetTypeSize(ParamInfos^[I]^);
    if (Size <= 4) and (curReg <= paECX) and (ParamInfos^[I]^.Kind <> tkFloat) then
      Inc(curReg)
    else
    begin
      if Size < 4 then
        Size := 4;
      Inc(StackSize, Align4(Size));
    end;
{$ELSE}
    if I < 3 then
    begin
      if ParamInfos^[I]^.Kind = tkFloat then
        RegisterFlag := RegisterFlag or (1 shl (I + 1));
    end;
    Inc(StackSize, 8);
{$ENDIF}
    Inc(P, 1 + P[1] + 1);
    Inc(P, P[0] + 1);
  end;

{$IFDEF CPUX64}
  if StackSize < 32 then
    StackSize := 32;
{$ENDIF}
end;

{$ENDREGION}


{$REGION 'TMethodInvocations'}

constructor TMethodInvocations.Create(methodTypeInfo: PTypeInfo;
  methodInvokeEvent: TMethodInvokeEvent);
begin
  inherited Create;
  fMethodType := methodTypeInfo;
  fMethodInfo := TMethodInfo.Create(fMethodType);
  fMethodInvokeEvent := methodInvokeEvent;
end;

procedure TMethodInvocations.InternalInvokeHandlers(Params: PParameters);
begin
  if Assigned(fMethodInvokeEvent) then
    fMethodInvokeEvent(Params, fMethodInfo.StackSize);
end;

procedure TMethodInvocations.InvokeEventHandlerStub;
{$IFNDEF CPUX64}
const
  PtrSize = SizeOf(Pointer);
asm
        // is register conversion call ?
        CMP     BYTE PTR Self.fMethodInfo.CallConvention, ccReg
        JZ      @Begin
        Mov     EAX, [esp + 4]
@Begin:
        PUSH    EAX
        PUSH    ECX
        PUSH    EDX
        MOV     EDX,ESP
        CALL    InternalInvokeHandlers
        // Pop EDX and ECX off the stack while preserving all registers.
        MOV     [ESP+4],EAX
        POP     EAX
        POP     EAX
        POP     ECX		// Self
        Mov     EAX, ECX
        MOV     ECX,[ECX].fMethodInfo.StackSize
        TEST    ECX,ECX
        JZ      @@SimpleRet
        // Jump to the actual return instruction since it is most likely not just a RET
        //JMP     ECX    // Data Exec. Prevention: Jumping into a GetMem allocated memory block

        // stack address alignment
        // In cdecl call conversion, the caller will clear the stack
        CMP     DWORD PTR [EAX].fMethodInfo.CallConvention, ccCdecl
        JZ      @@SimpleRet
        ADD     ECX, PtrSize - 1
        AND     ECX, NOT (PtrSize - 1)
        AND     ECX, $FFFF

        // clean up the stack
        PUSH    EAX                         // we need this register, so save it
        MOV     EAX,[ESP + 4]               // Load the return address
        MOV     [ESP + ECX + 4], EAX        // Just blast it over the first param on the stack
        POP     EAX
        ADD     ESP,ECX                     // This will move the stack back to where the moved
                                            // return address is now located. The next RET
                                            // instruction will do the final stack cleanup
@@SimpleRet:
end;
{$ELSE}
asm
        MOV     AX, WORD PTR [RCX].TMethodInvocations.fMethodInfo.RegisterFlag
@@FIRST:
        TEST    AX, $01
        JZ      @@SAVE_RCX
@@SAVE_XMM0:
        MOVSD   QWORD PTR [RSP+$08], XMM0
        JMP     @@SECOND
@@SAVE_RCX:
        MOV     QWORD PTR [RSP+$08], RCX

@@SECOND:
        TEST    AX, $02
        JZ      @@SAVE_RDX
@@SAVE_XMM1:
        MOVSD   QWORD PTR [RSP+$10], XMM1
        JMP     @@THIRD
@@SAVE_RDX:
        MOV     QWORD PTR [RSP+$10], RDX

@@THIRD:
        TEST    AX, $04
        JZ      @@SAVE_R8
@@SAVE_XMM2:
        MOVSD   QWORD PTR [RSP+$18], XMM2
        JMP     @@FORTH
@@SAVE_R8:
        MOV     QWORD PTR [RSP+$18], R8

@@FORTH:
        TEST    AX, $08
        JZ      @@SAVE_R9
@@SAVE_XMM3:
        MOVSD   QWORD PTR [RSP+$20], XMM3
        JMP     @@1
@@SAVE_R9:
        MOV     QWORD PTR [RSP+$20], R9

@@1:    LEA     RDX, QWORD PTR [RSP+$08]
        MOV     RAX, RCX
        SUB     RSP, $28
        CALL    InternalInvokeHandlers
        ADD     RSP, $28
end;
{$ENDIF}

{$ENDREGION}


{$REGION 'TEvent'}

constructor TEvent.Create(typeInfo: PTypeInfo);
begin
  if not Assigned(typeInfo) then
    raise EInvalidOperationException.CreateRes(@SNoTypeInfo);
  if typeInfo.Kind <> tkMethod then
    raise EInvalidOperationException.CreateRes(@STypeParameterShouldBeMethod);

  inherited Create;

  fTypeInfo := typeInfo;
  fInvocations := TMethodInvocations.Create(fTypeInfo, InternalInvoke);
  fInvoke.Data := fInvocations;
  fInvoke.Code := @TMethodInvocations.InvokeEventHandlerStub;
end;

destructor TEvent.Destroy;
begin
  fInvocations.Free;
  inherited Destroy;
end;

procedure TEvent.InternalInvoke(Params: Pointer; StackSize: Integer);
var
  i: Integer;
begin
  if Enabled then
    for i := 0 to Handlers.Count - 1 do
      InvokeMethod(Handlers[i], Params, StackSize);
end;

{$ENDREGION}


{$REGION 'TEvent<T>'}

constructor TEvent<T>.Create;
begin
  inherited Create(TypeInfo(T));
end;

procedure TEvent<T>.ForEach(const action: TAction<T>);
begin
  inherited ForEach(TAction<TMethod>(action));
end;

procedure TEvent<T>.Add(handler: T);
begin
  inherited Add(PMethod(@handler)^);
end;

procedure TEvent<T>.Remove(handler: T);
begin
  inherited Remove(PMethod(@handler)^);
end;

function TEvent<T>.GetInvoke: T;
begin
  PMethod(@Result)^ := inherited Invoke;
end;

{$ENDREGION}


end.
