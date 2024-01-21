unit JID.JarProcessor;

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

interface

type
  TJarProcessor = record
  private
    const
      cMaxCommandLength = 8191;
  private
    class function JDKBinPath: string; static;
  public
    class function GetHeaders(const AJarFileName: string; out AOutput: TArray<string>): Cardinal; static;
    class function GetRtlSignatures(const AClasses: TArray<string>; out AOutput: TArray<string>): Cardinal; static;
    class function GetSignatures(const AJarFileName: string; out AOutput: TArray<string>): Cardinal; overload; static;
    class function GetSignatures(const AJarFileName: string; const AClasses: TArray<string>; out AOutput: TArray<string>): Cardinal; overload; static;
  end;

implementation

uses
  System.Generics.Collections,
  System.SysUtils, System.IOUtils,
  DW.OS.Win, DW.RunProcess.Win;

const
  cJarTFCommandTemplate = '"%s\jar" tf "%s"';
  cJavaPJarCommandTemplate = '"%s\javap" -classpath "%s" -bootclasspath "%s" %s';
  // Includes descriptors in the output
  cJavaPJarDescCommandTemplate = '"%s\javap" -classpath "%s" -bootclasspath "%s" -s %s';
  cJavaPRtlCommandTemplate = '"%s\javap" %s';
  // Includes descriptors in the output
  cJavaPRtlDescCommandTemplate = '"%s\javap" -s %s';
  cMetaInfPrefix = 'META-INF';
  cClassExtension = '.class';
  cCompiledFromPrefix = 'Compiled from';
  cErrorPrefix = 'Error:';

type
  TCommand = record
    class function Run(const ACommandLine: string; out AOutput: TArray<string>): Cardinal; static;
  end;

{ TCommand }

class function TCommand.Run(const ACommandLine: string; out AOutput: TArray<string>): Cardinal;
var
  LProcess: TRunProcess;
begin
  LProcess := TRunProcess.Create;
  try
    LProcess.CommandLine := ACommandLine;
    Result := LProcess.RunAndWait;
    AOutput := LProcess.CapturedOutput;
  finally
    LProcess.Free;
  end;
end;

{ TJarProcessor }

class function TJarProcessor.JDKBinPath: string;
begin
  Result := TPath.Combine(TPlatformOS.GetEnvironmentVariable('JAVA_HOME'), 'bin');
end;

class function TJarProcessor.GetHeaders(const AJarFileName: string; out AOutput: TArray<string>): Cardinal;
var
  LCommandLine, LLine, LClassLine, LChildClass: string;
  I, LNumber: Integer;
begin
  LCommandLine := Format(cJarTFCommandTemplate, [JDKBinPath, AJarFileName]);
  Result := TCommand.Run(LCommandLine, AOutput);
  if Result = 0 then
  begin
    for I := Length(AOutput) - 1 downto 0 do
    begin
      LLine := AOutput[I];
      // Exclude lines with META-INF
      if LLine.StartsWith(cMetaInfPrefix, True) or LLine.EndsWith('package-info.class') then
        Delete(AOutput, I, 1)
      else if LLine.EndsWith(cClassExtension, True) then
      begin
        LClassLine := LLine.Replace(cClassExtension, '');
        // Exclude anonymous inner classes (end with $ and a number)
        LChildClass := LClassLine.Substring(LClassLine.LastIndexOf('$'));
        if LChildClass.IsEmpty or not TryStrToInt(LChildClass, LNumber) then
          AOutput[I] := LClassLine
        else
          Delete(AOutput, I, 1);
      end
      else
        Delete(AOutput, I, 1);
    end;
  end;
end;

// TODO: DRY GetRtlSignatures and GetSignatures
class function TJarProcessor.GetRtlSignatures(const AClasses: TArray<string>; out AOutput: TArray<string>): Cardinal;
var
  LTemplate, LCommandLine, LClassesString: string;
  I, LCommandLength: Integer;
  LHeaders, LClasses, LCommandOutput: TArray<string>;
begin
  LTemplate := cJavaPRtlCommandTemplate;
  // LTemplate := cJavaPRtlDescCommandTemplate;
  LHeaders := Copy(AClasses);
  repeat
    LCommandLength := Length(Format(LTemplate, [JDKBinPath, '']));
    LClasses := [];
    for I := 0 to Length(LHeaders) -1 do
    begin
      Inc(LCommandLength, Length(LHeaders[I]) + 1);
      if LCommandLength < cMaxCommandLength then
        LClasses := LClasses + [LHeaders[I]]
      else
        Break;
    end;
    Delete(LHeaders, 0, Length(LClasses));
    LClassesString := string.Join(' ', LClasses);
    LCommandLine := Format(LTemplate, [JDKBinPath, LClassesString]);
    LCommandOutput := [];
    Result := TCommand.Run(LCommandLine, LCommandOutput);
    if Result = 0 then
      AOutput := AOutput + LCommandOutput;
  until (Length(LHeaders) = 0) or (Result <> 0);
  for I := Length(AOutput) - 1 downto 0 do
  begin
    if AOutput[I].StartsWith(cCompiledFromPrefix, True) then
      Delete(AOutput, I, 1)
  end;
end;

class function TJarProcessor.GetSignatures(const AJarFileName: string; const AClasses: TArray<string>; out AOutput: TArray<string>): Cardinal;
var
  LTemplate, LCommandLine, LClassesString: string;
  I, LCommandLength: Integer;
  LHeaders, LClasses, LCommandOutput: TArray<string>;
begin
  LTemplate := cJavaPJarCommandTemplate;
  // LTemplate := cJavaPJarDescCommandTemplate;
  LHeaders := AClasses;
  repeat
    LCommandLength := Length(Format(LTemplate, [JDKBinPath, AJarFileName, AJarFileName, '']));
    LClasses := [];
    for I := 0 to Length(LHeaders) -1 do
    begin
      Inc(LCommandLength, Length(LHeaders[I]) + 1);
      if LCommandLength < cMaxCommandLength then
        LClasses := LClasses + [LHeaders[I]]
      else
        Break;
    end;
    Delete(LHeaders, 0, Length(LClasses));
    LClassesString := string.Join(' ', LClasses);
    LCommandLine := Format(LTemplate, [JDKBinPath, AJarFileName, AJarFileName, LClassesString]);
    LCommandOutput := [];
    Result := TCommand.Run(LCommandLine, LCommandOutput);
    if Result = 0 then
      AOutput := AOutput + LCommandOutput;
  until (Length(LHeaders) = 0) or (Result <> 0);
  for I := Length(AOutput) - 1 downto 0 do
  begin
    if AOutput[I].StartsWith(cCompiledFromPrefix, True) or AOutput[I].StartsWith(cErrorPrefix, True) then
      Delete(AOutput, I, 1);
  end;
end;

class function TJarProcessor.GetSignatures(const AJarFileName: string; out AOutput: TArray<string>): Cardinal;
var
  LHeaders: TArray<string>;
begin
  Result := GetHeaders(AJarFileName, LHeaders);
//  TArray.Sort<string>(LHeaders);
//  TFile.WriteAllLines('Y:\Lib\Android\Android.defs.txt', LHeaders);
  if Result = 0 then
    Result := GetSignatures(AJarFileName, LHeaders, AOutput);
end;

end.
