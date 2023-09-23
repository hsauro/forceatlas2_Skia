program Project_BallStick_skia;

uses
  System.StartUpCopy,
  FMX.Forms,
  ufMain in 'ufMain.pas' {frmMain},
  uGraph in 'uGraph.pas',
  uPyLayout in 'uPyLayout.pas',
  uPyUtils in 'uPyUtils.pas',
  Skia.FMX;

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
