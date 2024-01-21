program jid;

{*******************************************************}
{                                                       }
{                        JID                            }
{                                                       }
{                Jar Import for Delphi                  }
{                                                       }
{  Copyright 2020-2024 Dave Nottage under MIT license   }
{  which is located in the root folder of this library  }
{                                                       }
{*******************************************************}

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  JID.JIDCommand;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    ExitCode := TJIDCommand.Run;
  except
    on E: Exception do
    begin
      Writeln(E.ClassName, ': ', E.Message);
      ExitCode := -MaxInt;
    end;
  end;
end.
