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

program Spring.Tests;

{.$DEFINE CONSOLE_TESTRUNNER}

{$IFDEF CONSOLE_TESTRUNNER}
  {$APPTYPE CONSOLE}
  {$DEFINE XMLOUTPUT}
{$ENDIF}

uses
  SysUtils,
  Forms,
  TestFramework,
  TestExtensions,
  GUITestRunner,
  TextTestRunner,
  FinalBuilder.XMLTestRunner in 'Source\FinalBuilder.XMLTestRunner.pas',
  Spring.TestUtils in 'Source\Spring.TestUtils.pas',
  Spring.Tests.Base in 'Source\Base\Spring.Tests.Base.pas',
  Spring.Tests.Collections in 'Source\Base\Spring.Tests.Collections.pas',
  Spring.Tests.DesignPatterns in 'Source\Base\Spring.Tests.DesignPatterns.pas',
  Spring.Tests.Helpers in 'Source\Base\Spring.Tests.Helpers.pas',
  Spring.Tests.Reflection.ValueConverters in 'Source\Base\Spring.Tests.Reflection.ValueConverters.pas',
  Spring.Tests.SysUtils in 'Source\Base\Spring.Tests.SysUtils.pas',
  Spring.Tests.Container.Components in 'Source\Core\Spring.Tests.Container.Components.pas',
  Spring.Tests.Container.Interfaces in 'Source\Core\Spring.Tests.Container.Interfaces.pas',
  Spring.Tests.Container.LifetimeManager in 'Source\Core\Spring.Tests.Container.LifetimeManager.pas',
  Spring.Tests.Container in 'Source\Core\Spring.Tests.Container.pas',
  Spring.Tests.Pool in 'Source\Core\Spring.Tests.Pool.pas',
  Spring.Tests.Cryptography in 'Source\Extensions\Spring.Tests.Cryptography.pas',
  Spring.Tests.Utils in 'Source\Extensions\Spring.Tests.Utils.pas';

procedure RegisterTestCases;
begin
  RegisterTests('Spring.Base', [
    TRepeatedTest.Create(TTestNullableInteger.Suite, 3),
    TTestNullableBoolean.Suite,
    TTestGuard.Suite,
    TTestLazy.Suite,
    TTestMulticastEvent.Suite,
    TTestEmptyHashSet.Suite,
    TTestNormalHashSet.Suite,
    TTestIntegerList.Suite,
    TTestStringIntegerDictionary.Suite,
    TTestEmptyStringIntegerDictionary.Suite,
    TTestEmptyStackOfStrings.Suite,
    TTestStackOfInteger.Suite,
    TTestStackOfIntegerChangedEvent.Suite,
    TTestEmptyQueueOfInteger.Suite,
    TTestQueueOfInteger.Suite,
    TTestQueueOfIntegerChangedEvent.Suite,
    TTestListOfIntegerAsIEnumerable.Suite

  ]);

  RegisterTests('Spring.Base.SysUtils', [
    TTestSplitString.Suite,
    TTestTryConvertStrToDateTime.Suite,
    TTestSplitNullTerminatedStrings.Suite,
    TTestEnum.Suite
  ]);

  RegisterTests('Spring.Base.DesignPatterns', [
    TTestSingleton.Suite
  ]);

  RegisterTests('Spring.Base.Helpers', [
    TTestGuidHelper.Suite
  ]);

  RegisterTests('Spring.Base.Reflection.ValueConverters', [
    TTestFromString.Suite,
    TTestFromWideString.Suite,
    TTestFromInteger.Suite,
    TTestFromCardinal.Suite,
    TTestFromSmallInt.Suite,
    TTestFromShortInt.Suite,
    TTestFromBoolean.Suite,
    TTestFromEnum.Suite,
    TTestFromFloat.Suite,
    TTestFromColor.Suite,
    TTestFromCurrency.Suite,
    TTestFromDateTime.Suite,
    TTestFromObject.Suite,
    TTestFromNullable.Suite,
    TTestFromInterface.Suite,
    TTestCustomTypes.Suite
  ]);

//  RegisterTests('Spring.Base.Reflection.ValueExpression', [
//    TTestValueExpression.Suite
//  ]);

  RegisterTests('Spring.Core.Container', [
    TTestEmptyContainer.Suite,
    TTestSimpleContainer.Suite,
    TTestDifferentServiceImplementations.Suite,
    TTestImplementsDifferentServices.Suite,
    TTestActivatorDelegate.Suite,
    TTestTypedInjectionByCoding.Suite,
    TTestTypedInjectionsByAttribute.Suite,
    TTestNamedInjectionsByCoding.Suite,
    TTestNamedInjectionsByAttribute.Suite,
    TTestDirectCircularDependency.Suite,
    TTestCrossedCircularDependency.Suite,
    TTestImplementsAttribute.Suite,
    TTestRegisterInterfaces.Suite,
    TTestSingletonLifetimeManager.Suite,
    TTestTransientLifetimeManager.Suite,
    TTestRefCounting.Suite,
    TTestDefaultResolve.Suite,
    TTestInjectionByValue.Suite,
    TTestObjectPool.Suite,
    TTestResolverOverride.Suite,
    TTestRegisterInterfaceTypes.Suite,
    TTestLazyDependencies.Suite,
    TTestLazyDependenciesDetectRecursion.Suite,
    TTestDecoratorExtension.Suite
  ]);

  RegisterTests('Spring.Extensions.Utils', [
    TTestVersion.Suite
  ]);

  RegisterTests('Spring.Extensions.Cryptography', [
//    TTestBuffer.Suite,
//    TTestEmptyBuffer.Suite,
//    TTestFiveByteBuffer.Suite,
    TTestCRC16.Suite,
    TTestCRC32.Suite,
    TTestMD5.Suite,
    TTestSHA1.Suite,
    TTestSHA256.Suite,
    TTestSHA384.Suite,
    TTestSHA512.Suite,
    TTestPaddingModeIsNone.Suite,
    TTestPaddingModeIsPKCS7.Suite,
    TTestPaddingModeIsZeros.Suite,
    TTestPaddingModeIsANSIX923.Suite,
    TTestPaddingModeIsISO10126.Suite,
    TTestDES.Suite,
    TTestTripleDES.Suite
  ]);

// Stefan Glienke - 2011/11/20:
// removed configuration and logging tests because they break other tests in Delphi 2010
// due to some bug in Rtti.TRttiPackage.MakeTypeLookupTable
// see https://forums.embarcadero.com/thread.jspa?threadID=54471
//
//  RegisterTests('Spring.Core.Configuration', [
//    TTestConfiguration.Suite
//  ]);
//
//  RegisterTests('Spring.Core.Logging', [
//     TTestLoggingConfig.Suite
//  ]);
end;

{$IFDEF CONSOLE_TESTRUNNER}
var
{$IFDEF XMLOUTPUT}
  OutputFile: string = 'Spring.Tests.Reports.xml';
  ConfigFile: string;
{$ELSE}
  ExitBehavior: TRunnerExitBehavior = rxbContinue;
{$ENDIF}
{$ENDIF}
begin
  RegisterTestCases;
  ReportMemoryLeaksOnShutdown := True;
  {$IFDEF CONSOLE_TESTRUNNER}
    {$IFDEF XMLOUTPUT}
      if ConfigFile <> '' then
      begin
        RegisteredTests.LoadConfiguration(ConfigFile, False, True);
        WriteLn('Loaded config file ' + ConfigFile);
      end;
      if ParamCount > 0 then
        OutputFile := ParamStr(1);
      WriteLn('Writing output to ' + OutputFile);
      WriteLn('Running ' + IntToStr(RegisteredTests.CountEnabledTestCases) + ' of ' + IntToStr(RegisteredTests.CountTestCases) + ' test cases');
      FinalBuilder.XMLTestRunner.RunRegisteredTests(OutputFile).Free;
    {$ELSE}
      WriteLn('To run with rxbPause, use -p switch');
      WriteLn('To run with rxbHaltOnFailures, use -h switch');
      WriteLn('No switch runs as rxbContinue');

      if FindCmdLineSwitch('p', ['-', '/'], true) then
        ExitBehavior := rxbPause
      else if FindCmdLineSwitch('h', ['-', '/'], true) then
        ExitBehavior := rxbHaltOnFailures;
      TextTestRunner.RunRegisteredTests(ExitBehavior).Free;
    {$ENDIF}
  {$ELSE}
    Application.Initialize;
    TGUITestRunner.RunRegisteredTests;
  {$ENDIF}
end.
