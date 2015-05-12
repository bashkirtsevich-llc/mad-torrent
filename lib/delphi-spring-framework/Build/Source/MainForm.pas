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

unit MainForm;

interface

uses
  Windows,
  Messages,
  SysUtils,
  Variants,
  Classes,
  Graphics,
  Controls,
  Forms,
  Dialogs,
  StdCtrls,
  ExtCtrls,
  CheckLst,
  BuildEngine;

type
  TfrmMain = class(TForm)
    btnBuild: TButton;
    mmoDetails: TMemo;
    lblDetails: TLabel;
    grpTargets: TGroupBox;
    lbTargets: TCheckListBox;
    lblHomepage: TLinkLabel;
    BalloonHint1: TBalloonHint;
    grpConfiguration: TRadioGroup;
    btnClean: TButton;
    chkTests: TCheckBox;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnBuildClick(Sender: TObject);
    procedure btnCloseClick(Sender: TObject);
    procedure btnCleanClick(Sender: TObject);
    procedure grpConfigurationClick(Sender: TObject);
    procedure lbTargetsClickCheck(Sender: TObject);
    procedure lblHomepageLinkClick(Sender: TObject; const Link: string;
      LinkType: TSysLinkType);
    procedure chkTestsClick(Sender: TObject);
  private
    fBuildEngine: TBuildEngine;
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.dfm}

uses
  ShellAPI,
  Spring.Utils;

const
  CCompilerSettingsFileName = 'Build.Settings.Compilers.ini';
  CBuildSettingsFileName = 'Build.Settings.ini';

procedure TfrmMain.FormCreate(Sender: TObject);
var
  task: TBuildTask;
  index: Integer;
begin
  fBuildEngine := TBuildEngine.Create;
  fBuildEngine.ConfigureCompilers(ApplicationPath + CCompilerSettingsFileName);
  fBuildEngine.LoadSettings(ApplicationPath + CBuildSettingsFileName);
  grpConfiguration.ItemIndex := Ord(fBuildEngine.ConfigurationType);
  chkTests.Checked := fBuildEngine.RunTests;

  lbTargets.Clear;
  for task in fBuildEngine.Tasks do
  begin
    index := lbTargets.Items.AddObject(task.Name, task);
    lbTargets.ItemEnabled[index] := task.CanBuild;
    lbTargets.Checked[index] := fBuildEngine.SelectedTasks.Contains(task);
  end;
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  fBuildEngine.SaveSettings(ApplicationPath + CBuildSettingsFileName);
  fBuildEngine.Free;
end;

procedure TfrmMain.grpConfigurationClick(Sender: TObject);
begin
  fBuildEngine.ConfigurationType := TConfigurationType(grpConfiguration.ItemIndex);
end;

procedure TfrmMain.lblHomepageLinkClick(Sender: TObject; const Link: string;
  LinkType: TSysLinkType);
begin
  ShellExecute(Handle, 'open', PChar(Link), nil, nil, SW_NORMAL);
end;

procedure TfrmMain.lbTargetsClickCheck(Sender: TObject);
var
  task: TBuildTask;
  i: Integer;
begin
  fBuildEngine.SelectedTasks.Clear;
  for i := 0 to lbTargets.Count - 1 do
  begin
    if lbTargets.Checked[i] then
    begin
      task := TBuildTask(lbTargets.Items.Objects[i]);
      fBuildEngine.SelectedTasks.Add(task);
    end;
  end;
  btnBuild.Enabled := not fBuildEngine.SelectedTasks.IsEmpty;
end;

procedure TfrmMain.btnBuildClick(Sender: TObject);
begin
  fBuildEngine.BuildAll;
end;

procedure TfrmMain.btnCleanClick(Sender: TObject);
begin
  fBuildEngine.CleanUp;
end;

procedure TfrmMain.btnCloseClick(Sender: TObject);
begin
  Close;
end;

procedure TfrmMain.chkTestsClick(Sender: TObject);
begin
  fBuildEngine.RunTests := chkTests.Checked;
end;

end.
