program TestSTJson01;

uses
  Forms,
  uTestSTJson01 in 'uTestSTJson01.pas' {Form1},
  uSTJson in '..\uSTJson.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
