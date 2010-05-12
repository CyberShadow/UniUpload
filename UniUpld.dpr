program UniUpld;

uses
{$IFDEF madexcept}
  madExcept, madDisAsm,
{$ENDIF}
  Forms,
  Main in 'Main.pas' {MainForm},
  BaseUploader in 'BaseUploader.pas',
  ImageShack in 'ImageShack.pas',
  MediaFire in 'MediaFire.pas',
  //RapidShare in 'RapidShare.pas',
  //CyberShadow in 'CyberShadow.pas';
  Custom in 'Custom.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
