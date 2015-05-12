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

unit Spring.UnitTests;

interface

uses
  Rtti,
  TestFramework;

{$I Spring.inc}

type
  /// <summary>
  /// Represents a test fixture. By default, All classes inherited from <see cref="TestFramework|TTestCase" />
  /// will be regarded as a test case. Uses <see cref="IgnoreAttribute" /> to ignore the test case.
  /// </summary>
  TestFixtureAttribute = class(TCustomAttribute)
  end;

  IgnoreAttribute = class(TCustomAttribute);

procedure RegisterAllTestCasesByRTTI;

implementation

uses
  Spring.Helpers;

type
  TTestCaseClass = class of TTestCase;

procedure RegisterAllTestCasesByRTTI;
var
  context: TRttiContext;
  t: TRttiType;
begin
  context := TRttiContext.Create;
  for t in context.GetTypes do
  begin
    if not (t is TRttiInstanceType) or
      (TRttiInstanceType(t).MetaclassType = TTestCase) or
      not TRttiInstanceType(t).MetaclassType.InheritsFrom(TTestCase) then
      Continue;

    if t.AsInstance.HasCustomAttribute<IgnoreAttribute> then
      Continue;

    RegisterTest(TRttiInstanceType(t).MetaclassType.UnitName, TTestCaseClass(TRttiInstanceType(t).MetaclassType).Suite);
  end;
  context.Free;
end;

end.
