program JIDUtils;

uses
  Vcl.Forms,
  JID.View.Main in 'JID.View.Main.pas' {MainView};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TMainView, MainView);
  Application.Run;
end.
