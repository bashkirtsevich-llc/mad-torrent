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

unit BuildEngine;

interface

uses
  Classes,
  IniFiles,
  Registry,
  ShellAPI,
  SysUtils,
  Windows,
  Spring,
  Spring.Collections,
  Spring.Utils;

type
  {$SCOPEDENUMS ON}

  TConfigurationType = (
    Debug,
    Release
  );

  TCompilerTarget = class
  private
    type
      TKeys = record
        BDS: string;
        LibraryKey: string;
        Globals: string;
        EnvironmentVariables: string;
      end;

      TNames = record
        RootDir: string;
        LibraryPath: string;
        BrowsingPath: string;
      end;
  private
    fRegistry: TRegistry;
    fBrowsingPaths: TStrings;
    fLibraryPaths: TStrings;
    fEnvironmentVariables: TStrings;
    fTypeName: string;
    fDisplayName: string;
    fPlatform: string;
    fRootDir: string;
    fExists: Boolean;
    fKeys: TKeys;
    fNames: TNames;
  protected
    procedure EnsureOpenKey(const key: string; createIfNotExists: Boolean = False);
    procedure LoadEnvironmentVariables(environmentVariables: TStrings);
    procedure SaveEnvironmentVariables(environmentVariables: TStrings);
    property Keys: TKeys read fKeys;
    property Names: TNames read fNames;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Configure(const typeName: string; properties: TStrings);
    procedure LoadOptions;
    procedure SaveOptions;
    property TypeName: string read fTypeName;
    property DisplayName: string read fDisplayName;
    property Platform: string read fPlatform;
    property Exists: Boolean read fExists;
    property RootDir: string read fRootDir;
    property LibraryPaths: TStrings read fLibraryPaths;
    property BrowsingPaths: TStrings read fBrowsingPaths;
    property EnvironmentVariables: TStrings read fEnvironmentVariables;
  end;

  TBuildTask = class
  public
    constructor Create;
    destructor Destroy; override;
  public
    Compiler: TCompilerTarget;
    Projects: TStrings;
    UnitOutputPath: string;
    function Name: string;
    function CanBuild: Boolean;
  end;

  TBuildEngine = class
  private
    fConfigurationType: TConfigurationType;
    fSourceBaseDir: string;
    fSourcePaths: TStrings;

    fTargets: IList<TCompilerTarget>;
    fTasks: IList<TBuildTask>;
    fSelectedTasks: IList<TBuildTask>;
    fRunTests: Boolean;
  protected
    procedure RemoveReleatedEntries(const baseDir: string; entries: TStrings);
    procedure ExecuteCommandLine(const applicationName, commandLine: string;
      var exitCode: Cardinal; const workingDirectory: string = '');
    procedure BuildTarget(task: TBuildTask);

    property Targets: IList<TCompilerTarget> read fTargets;
  public
    constructor Create;
    destructor Destroy; override;

    procedure ConfigureCompilers(const fileName: string);
    procedure LoadSettings(const fileName: string);
    procedure SaveSettings(const fileName: string);

    procedure CleanUp;
    procedure BuildAll;

    property ConfigurationType: TConfigurationType read fConfigurationType write fConfigurationType;
    property SourcePaths: TStrings read fSourcePaths;

    property Tasks: IList<TBuildTask> read fTasks;
    property SelectedTasks: IList<TBuildTask> read fSelectedTasks;
    property RunTests: Boolean read fRunTests write fRunTests;
  end;

  ECommandLineException = class(Exception);
  EBuildException = class(Exception);

resourcestring
  SFailedToOpenRegistryKey = 'Failed to open the registry key: "%s".';
  SFailedToCreateProcess = 'Failed to create the process: "%s".';
  SBuildFailed = 'Failed to build the task: "%s"';

implementation

const
  ConfigurationNames: array[TConfigurationType] of string = (
    'Debug',
    'Release'
  );

type
  TStringsHelper = class helper for TStrings
  public
    function GetValueOrDefault(const name, defaultValue: string): string;
  end;

{$REGION 'TStringsHelper'}

function TStringsHelper.GetValueOrDefault(const name, defaultValue: string): string;
var
  index: Integer;
begin
  index := IndexOfName(name);
  if index > -1 then
  begin
    Result := ValueFromIndex[index];
  end
  else
  begin
    Result := defaultValue;
  end;
end;

{$ENDREGION}


{$REGION 'TCompilerTarget'}

constructor TCompilerTarget.Create;
begin
  inherited Create;
  fRegistry := TRegistry.Create;
  fRegistry.RootKey := HKEY_CURRENT_USER;
  fLibraryPaths := TStringList.Create;
  fLibraryPaths.Delimiter := ';';
  fLibraryPaths.StrictDelimiter := True;
  fBrowsingPaths := TStringList.Create;
  fBrowsingPaths.Delimiter := ';';
  fBrowsingPaths.StrictDelimiter := True;
  fEnvironmentVariables := TStringList.Create;
end;

destructor TCompilerTarget.Destroy;
begin
  fEnvironmentVariables.Free;
  fBrowsingPaths.Free;
  fLibraryPaths.Free;
  fRegistry.Free;
  inherited Destroy;
end;

procedure TCompilerTarget.EnsureOpenKey(const key: string; createIfNotExists: Boolean);
begin
  if not fRegistry.OpenKey(key, createIfNotExists) then
  begin
    raise ERegistryException.CreateResFmt(@SFailedToOpenRegistryKey, [key]);
  end;
end;

procedure TCompilerTarget.LoadEnvironmentVariables(environmentVariables: TStrings);
var
  i: Integer;
begin
  if fRegistry.KeyExists(Keys.EnvironmentVariables) then
  begin
    EnsureOpenKey(Keys.EnvironmentVariables);
    fRegistry.GetValueNames(environmentVariables);
    with environmentVariables do
    for i := 0 to Count - 1 do
    begin
      Strings[i] := Strings[i] + NameValueSeparator + fRegistry.ReadString(Strings[i]);
    end;
    fRegistry.CloseKey;
  end;
end;

procedure TCompilerTarget.SaveEnvironmentVariables(environmentVariables: TStrings);
var
  i: Integer;
begin
  EnsureOpenKey(Keys.EnvironmentVariables, True);
  with environmentVariables do
  for i := 0 to Count - 1 do
  begin
    fRegistry.WriteString(Names[i], ValueFromIndex[i]);
  end;
  fRegistry.CloseKey;
end;

procedure TCompilerTarget.LoadOptions;
var
  path: string;
begin
  with fRegistry do
  begin
    EnsureOpenKey(Keys.BDS);
    fRootDir := ReadString(Names.RootDir);
    CloseKey;

    EnsureOpenKey(Keys.LibraryKey);
    path := ReadString(Names.LibraryPath);
    fLibraryPaths.DelimitedText := path;
    path := ReadString(Names.BrowsingPath);
    fBrowsingPaths.DelimitedText := path;
    CloseKey;

    LoadEnvironmentVariables(fEnvironmentVariables);
  end;
end;

procedure TCompilerTarget.SaveOptions;
begin
  EnsureOpenKey(Keys.LibraryKey);
  fRegistry.WriteString(Names.LibraryPath, fLibraryPaths.DelimitedText);
  fRegistry.WriteString(Names.BrowsingPath, fBrowsingPaths.DelimitedText);
  fRegistry.CloseKey;

  SaveEnvironmentVariables(fEnvironmentVariables);

  EnsureOpenKey(Keys.Globals);
  fRegistry.WriteString('ForceEnvOptionsUpdate', '1');
  fRegistry.CloseKey;
end;

procedure TCompilerTarget.Configure(const typeName: string; properties: TStrings);
var
  fileName: string;
begin
  Guard.CheckNotNull(properties, 'properties');

  fTypeName := typeName;
  fDisplayName := properties.GetValueOrDefault('DisplayName', '');
  fPlatform := properties.GetValueOrDefault('Platform', 'Win32');
  fKeys.BDS := properties.GetValueOrDefault('Keys.BDS', '');
  fKeys.LibraryKey := IncludeTrailingPathDelimiter(fKeys.BDS) + properties.GetValueOrDefault('Keys.Library', 'Library');
  fKeys.Globals := IncludeTrailingPathDelimiter(fKeys.BDS) + properties.GetValueOrDefault('Keys.Globals', 'Globals');
  fKeys.EnvironmentVariables := IncludeTrailingPathDelimiter(fKeys.BDS) + properties.GetValueOrDefault('Keys.EnvironmentVariables', 'Environment Variables');
  fNames.LibraryPath := properties.GetValueOrDefault('Names.LibraryPath', 'Search Path');
  fNames.BrowsingPath := properties.GetValueOrDefault('Names.BrowsingPath', 'Browsing Path');
  fNames.RootDir := properties.GetValueOrDefault('Names.RootDir', 'RootDir');
  fExists := fRegistry.KeyExists(fKeys.BDS);
  if fExists then
  begin
    EnsureOpenKey(fKeys.BDS);
    fileName := fRegistry.ReadString('App');
    fExists := FileExists(fileName);
    fRegistry.CloseKey;
  end;
end;

{$ENDREGION}


{$REGION 'TBuildTask'}

constructor TBuildTask.Create;
begin
  inherited Create;
  Projects := TStringList.Create;
  Projects.Delimiter := ';';
  Projects.StrictDelimiter := True;
end;

destructor TBuildTask.Destroy;
begin
  Projects.Free;
  inherited Destroy;
end;

function TBuildTask.Name: string;
begin
  Result := Compiler.DisplayName;
end;

function TBuildTask.CanBuild: Boolean;
begin
  Result := Compiler.Exists;
end;

{$ENDREGION}


{$REGION 'TBuildEngine'}

constructor TBuildEngine.Create;
begin
  inherited Create;
  fConfigurationType := TConfigurationType.Release;
  fTargets := TCollections.CreateObjectList<TCompilerTarget>;
  fTasks := TCollections.CreateObjectList<TBuildTask>;
  fSelectedTasks := TCollections.CreateList<TBuildTask>;
  fSourcePaths := TStringList.Create;
  fSourcePaths.Delimiter := ';';
  fSourcePaths.StrictDelimiter := True;
end;

destructor TBuildEngine.Destroy;
begin
  fSourcePaths.Free;
  inherited Destroy;
end;

procedure TBuildEngine.ExecuteCommandLine(const applicationName, commandLine: string;
  var exitCode: Cardinal; const workingDirectory: string);
const
  nSize: Cardinal = 1024;
var
  localCommandLine: string;
  startupInfo: TStartupInfo;
  processInfo: TProcessInformation;
  currentDirectory: PChar;
begin
  ZeroMemory(@startupInfo, SizeOf(startupInfo));
  ZeroMemory(@processInfo, SizeOf(processInfo));
  startupInfo.cb := SizeOf(startupInfo);
  localCommandLine := commandLine;
  UniqueString(localCommandLine);
  if workingDirectory <> '' then
    currentDirectory := PChar(workingDirectory)
  else
    currentDirectory := nil;
  if not CreateProcess(PChar(applicationName), PChar(localCommandLine), nil, nil, True,
    0, nil, currentDirectory, startupInfo, processInfo) then
  begin
    raise ECommandLineException.CreateResFmt(@SFailedToCreateProcess, [applicationName]);
  end;
  WaitForSingleObject(processInfo.hProcess, INFINITE);
  GetExitCodeProcess(processInfo.hProcess, exitCode);
  CloseHandle(processInfo.hProcess);
  CloseHandle(processInfo.hThread);
end;

procedure TBuildEngine.BuildAll;
var
  task: TBuildTask;
begin
  for task in SelectedTasks do
  begin
    BuildTarget(task);
  end;
end;

procedure TBuildEngine.BuildTarget(task: TBuildTask);
var
  projectPath: string;
  unitOutputPath: string;
  configurationName: string;
  projectName: string;
  commandFileName: string;
  commandLine: string;
  exitCode: Cardinal;
  rsvars: string;
  target: TCompilerTarget;
begin
  Guard.CheckNotNull(task, 'task');
  target := task.Compiler;

  projectPath := ExtractFilePath(ParamStr(0));
  configurationName := ConfigurationNames[fConfigurationType];

  RemoveReleatedEntries(projectPath, target.LibraryPaths);
  RemoveReleatedEntries(projectPath, target.BrowsingPaths);

  unitOutputPath := projectPath + task.UnitOutputPath;
  unitOutputPath := StringReplace(unitOutputPath, '$(Config)', configurationName, [rfIgnoreCase, rfReplaceAll]);
  unitOutputPath := StringReplace(unitOutputPath, '$(Platform)', target.Platform, [rfIgnoreCase, rfReplaceAll]);

  target.LibraryPaths.Add(unitOutputPath);
  target.BrowsingPaths.AddStrings(fSourcePaths);
  target.SaveOptions;

  commandFileName := IncludeTrailingPathDelimiter(TEnvironment.GetFolderPath(sfSystem)) + 'cmd.exe';
  rsvars := IncludeTrailingPathDelimiter(target.RootDir) + 'bin\rsvars.bat';
  for projectName in task.Projects do
  begin
    commandLine := Format('/C BuildHelper "%0:s" "%1:s" "Config=%2:s" "Platform=%3:s"', [
      rsvars, projectName, configurationName, target.Platform
    ]);
    ExecuteCommandLine(commandFileName, commandLine, exitCode);
    if exitCode <> 0 then
    begin
      raise EBuildException.CreateResFmt(@SBuildFailed, [projectName]);
    end;
  end;

  if fRunTests then
  begin
    commandLine := Format('%0:s\Tests\Bin\%1:s\Spring.Tests.exe', [
      ExcludeTrailingPathDelimiter(projectPath),
      StringReplace(task.Compiler.TypeName, '.', '\', [])]);
    ExecuteCommandLine(commandLine, '', exitCode, ExtractFileDir(commandLine));
  end;
end;

procedure TBuildEngine.CleanUp;
var
  commandFileName: string;
  exitCode: Cardinal;
begin
  commandFileName := IncludeTrailingPathDelimiter(TEnvironment.GetFolderPath(sfSystem)) + 'cmd.exe';
  ExecuteCommandLine(commandFileName, '/C Clean', exitCode);
end;

procedure TBuildEngine.ConfigureCompilers(const fileName: string);
var
  ini: TIniFile;
  sections: TStrings;
  properties: TStrings;
  sectionName: string;
  target: TCompilerTarget;
begin
  CheckFileExists(fileName);

  fTargets.Clear;

  ini := TIniFile.Create(fileName);
  sections := nil;
  properties := nil;
  try
    sections := TStringList.Create;
    properties := TStringList.Create;

    ini.ReadSections(sections);

    for sectionName in sections do
    begin
      ini.ReadSectionValues(sectionName, properties);
      target := TCompilerTarget.Create;
      fTargets.Add(target);
      target.Configure(sectionName, properties);
      if target.Exists then
        target.LoadOptions;
    end;
  finally
    properties.Free;
    sections.Free;
    ini.Free;
  end;
end;

procedure TBuildEngine.LoadSettings(const fileName: string);
var
  ini: TCustomIniFile;
  sections: TStrings;
  sectionName: string;
  config: string;
  target: TCompilerTarget;
  task: TBuildTask;
  i: Integer;
  selectedTasks: TStrings;
begin
  ini := TIniFile.Create(fileName);
  sections := TStringList.Create;
  selectedTasks := TStringList.Create;
  selectedTasks.Delimiter := ';';
  try
    config := ini.ReadString('Globals', 'Config', 'Debug');
    if SameText(config, 'Debug') then
      fConfigurationType := TConfigurationType.Debug
    else
      fConfigurationType := TConfigurationType.Release;
    fSourceBaseDir := ini.ReadString('Globals', 'SourceBaseDir', '');
    fSourceBaseDir := ApplicationPath + fSourceBaseDir;
    fSourcePaths.DelimitedText := ini.ReadString('Globals', 'SourcePaths', '');
    for i := 0 to fSourcePaths.Count - 1 do
    begin
      fSourcePaths[i] := IncludeTrailingPathDelimiter(fSourceBaseDir) + fSourcePaths[i];
    end;
    selectedTasks.DelimitedText := ini.ReadString('Globals', 'SelectedTasks', '');
    fRunTests := ini.ReadBool('Globals', 'RunTests', False);

    for target in fTargets do
    begin
      sectionName := target.TypeName;
      if ini.SectionExists(sectionName) then
      begin
        task := TBuildTask.Create;
        fTasks.Add(task);
        task.Compiler := target;
        task.Projects.DelimitedText := ini.ReadString(sectionName, 'Projects', '');
        task.UnitOutputPath := ini.ReadString(sectionName, 'UnitOutputPaths', '');
        if task.CanBuild and ((selectedTasks.Count = 0) or (selectedTasks.IndexOf(sectionName) > -1)) then
          fSelectedTasks.Add(task);
      end;
    end;
  finally
    selectedTasks.Free;
    sections.Free;
    ini.Free;
  end;
end;

procedure TBuildEngine.RemoveReleatedEntries(const baseDir: string; entries: TStrings);
var
  entry: string;
  i: Integer;
begin
  Assert(entries <> nil, 'entries should not be nil.');
  for i := entries.Count - 1 downto 0 do
  begin
    entry := entries[i];
    if (Pos(baseDir, entry) > 0) {or (Pos('$(SPRING)', entry) > 0)} then
    begin
      entries.Delete(i);
    end;
  end;
end;

procedure TBuildEngine.SaveSettings(const fileName: string);
var
  ini: TCustomIniFile;
  selectedTasks: TStrings;
  task: TBuildTask;
begin
  ini := TIniFile.Create(fileName);
  selectedTasks := TStringList.Create;
  selectedTasks.Delimiter := ';';
  try
    for task in fSelectedTasks do
    begin
      selectedTasks.Add(task.Compiler.TypeName);
    end;
    ini.WriteString('Globals', 'Config', ConfigurationNames[fConfigurationType]);
    ini.WriteString('Globals', 'SelectedTasks', selectedTasks.DelimitedText);
    ini.WriteBool('Globals', 'RunTests', fRunTests);
  finally
    ini.Free;
    selectedTasks.Free;
  end;
end;

{$ENDREGION}


end.
