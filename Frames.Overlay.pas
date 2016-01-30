unit Frames.Overlay;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,

  FMX.Types, FMX.Graphics, FMX.Controls, FMX.Forms, FMX.Dialogs, FMX.StdCtrls,
  FMX.Ani, FMX.Layouts, FMX.Controls.Presentation;

type
  TfrmOverlay = class(TFrame)
    aniIndicator: TAniIndicator;
    panelOverlay: TPanel;
    animationfloatOverlay: TFloatAnimation;
  public
    type
      TOverlayType = (otNone, otLoading, otOverlay);
  private
    FOverlay: TOverlayType;
    procedure SetOverlay(const Value: TOverlayType);
  public
    property Overlay: TOverlayType read FOverlay write SetOverlay;
  end;

implementation

{$R *.fmx}

procedure TfrmOverlay.SetOverlay(const Value: TOverlayType);
begin
  if FOverlay <> Value then
  begin
    FOverlay := Value;

    Visible               := FOverlay <> FOverlay;
    panelOverlay.Visible  := FOverlay = otOverlay;
    aniIndicator.Visible  := FOverlay = otLoading;
  end;
end;

end.
