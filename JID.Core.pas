unit JID.Core;

interface

type
  IMessages = interface
    ['{CF4939E4-107E-4FF3-9608-6448E52EB489}']
    procedure Debug(const AText: string);
    procedure Write(const AText: string; const ADebug: Boolean = False);
    procedure Writeln(const AText: string; const ADebug: Boolean = False);
  end;

var
  Messages: IMessages;

implementation

{$DEFINE DebugMessages}

uses
  Winapi.Windows;

type
  TMessages = class(TInterfacedObject, IMessages)
  public
    { IMessages }
    procedure Debug(const AText: string);
    procedure Write(const AText: string; const ADebug: Boolean = False);
    procedure Writeln(const AText: string; const ADebug: Boolean = False);
  end;

{ TMessages }

procedure TMessages.Debug(const AText: string);
begin
  OutputDebugString(PChar(AText));
end;

procedure TMessages.Write(const AText: string; const ADebug: Boolean);
begin
  if IsConsole then
    Write(AText);
  {$IF Defined(DebugMessages)}
  Debug(AText);
  {$ELSE}
  if ADebug then
    Debug(AText);
  {$ENDIF}
end;

procedure TMessages.Writeln(const AText: string; const ADebug: Boolean = False);
begin
  if IsConsole then
    Writeln(AText);
  {$IF Defined(DebugMessages)}
  Debug(AText);
  {$ELSE}
  if ADebug then
    Debug(AText);
  {$ENDIF}
end;

initialization
  Messages := TMessages.Create;

end.
