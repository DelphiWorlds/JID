unit JID.JIDCommand;

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

uses
  JID.JarProcessor, JID.ImportWriter;

type
  TSwitch = record
    Key: string;
    Values: TArray<string>;
  end;

  TSwitches = TArray<TSwitch>;

  TJIDCommand = record
  private
    class function GetIndexFileName: string; static;
    class procedure ImportFromSignatures(const ASignatures: TArray<string>; const AOutputFileName: string; const AOptions: TImportOptions); static;
    class function RunFind(const AFindSwitch: TSwitch; AOutputFileName: string): Integer; static;
    class function RunIndex(const AIndexFolder, AOutputFileName: string; const ASwitches: TSwitches): Integer; static;
    class function RunImport(const AOutputFileName: string; const ASwitches: TSwitches): Integer; static;
    class procedure ShowUsage; static;
  public
    class function IndexJars(const AIndexFolder, AMatch, AOutputFileName: string): Cardinal; static;
    class function ImportJar(const AJarFileName, AOutputFileName: string; const AOptions: TImportOptions): Cardinal; static;
    class function ImportRtl(const AClasses: TArray<string>; const AOutputFileName: string; const AOptions: TImportOptions): Cardinal; static;
    class function Run: Integer; static;
  end;

implementation

uses
  System.SysUtils, System.IOUtils, System.Generics.Collections, System.Generics.Defaults,
  DW.OS.Win,
  JID.JavaTypes, JID.SignatureParser;

type
  TFinderItem = record
  public
    class function CompareFileName(const ALeft, ARight: TFinderItem): Integer; static;
  public
    Qualifier: string;
    FileName: string;
    constructor Create(const AQualifier, AFileName: string);
  end;

  TFinderItems = TArray<TFinderItem>;

  TFinder = record
    Source: TArray<string>;
    Items: TFinderItems;
    constructor Create(const AFindFileName, AIndexFileName: string);
    function FindItem(const AQualifier: string; out AItem: TFinderItem): Boolean;
    function GetMatches: TArray<string>;
    procedure ReadItems(const AIndexFileName: string);
  end;

  TSwitchesHelper = record helper for TSwitches
    function FindSwitch(const AKey: string; out ASwitch: TSwitch): Boolean;
  end;

function IsJavaHomeValid: Boolean;
var
  LJavaHome, LMessage: string;
begin
  Result := False;
  LMessage := '';
  LJavaHome := TPlatformOS.GetEnvironmentVariable('JAVA_HOME');
  if not LJavaHome.IsEmpty then
  begin
    if TDirectory.Exists(LJavaHome) then
    begin
      if TFile.Exists(TPath.Combine(TPath.Combine(LJavaHome, 'bin'), 'jar.exe')) then
        Result := True
      else 
        LMessage := Format('JAVA_HOME environment variable of %s does not appear to be valid', [LJavaHome])
    end
    else 
      LMessage := Format('JAVA_HOME environment variable of %s does not exist', [LJavaHome]);   
  end
  else 
    LMessage := 'JAVA_HOME environment variable is empty';
  if not LMessage.IsEmpty and IsConsole then
    Writeln(LMessage);
end;

function GetCmdLine: string;
var
  LParamsIndex: Integer;
begin
  {$WARN SYMBOL_PLATFORM OFF}
  Result := CmdLine;
  {$WARN SYMBOL_PLATFORM ON}
  if Result.StartsWith('"') then
  begin
    LParamsIndex := Result.Substring(1).IndexOf('"');
    if LParamsIndex > - 1 then
      Inc(LParamsIndex, 2);
  end
  else
    LParamsIndex := Result.IndexOf(' ');
  if LParamsIndex > -1 then
    Result := Result.Substring(LParamsIndex).Trim
  else
    Result := '';
end;

function GetSwitches: TSwitches;
var
  LSwitchIndex, LSpaceIndex, LQuoteIndex: Integer;
  LCmdLine, LValue: string;
  LSwitch: TSwitch;
begin
  Result := [];
  LCmdLine := GetCmdLine;
  while not LCmdLine.IsEmpty do
  begin
    LSwitchIndex := LCmdLine.IndexOf('-');
    if LSwitchIndex > -1 then
    begin
      LSpaceIndex := LCmdLine.IndexOf(' ', LSwitchIndex);
      LSwitch := Default(TSwitch);
      LSwitch.Key := LCmdLine.Substring(LSwitchIndex + 1, LSpaceIndex - LSwitchIndex - 1);
      LCmdLine := LCmdLine.Substring(LSpaceIndex + 1);
      if not LCmdLine.IsEmpty then
      repeat
        if LCmdLine.StartsWith('"') then
        begin
          LQuoteIndex := LCmdLine.IndexOf('"', 1);
          if LQuoteIndex > -1 then
          begin
            LValue := LCmdLine.Substring(1, LQuoteIndex - 1);
            LSwitch.Values := LSwitch.Values + [LValue];
            LCmdLine := LCmdLine.Substring(LQuoteIndex + 1).TrimLeft;
          end
          else
            LCmdLine := '';
        end
        else
        begin
          LSpaceIndex := LCmdLine.IndexOf(' ');
          if LSpaceIndex = -1 then
            LSpaceIndex := Length(LCmdLine);
          LValue := LCmdLine.Substring(0, LSpaceIndex);
          LSwitch.Values := LSwitch.Values + [LValue];
          LCmdLine := LCmdLine.Substring(LSpaceIndex + 1);
        end;
      until LCmdLine.IsEmpty or (LCmdLine.Chars[0] = '-');
      Result := Result + [LSwitch];
    end;
  end;
end;

{ TFinderItem }

constructor TFinderItem.Create(const AQualifier, AFileName: string);
begin
  Qualifier := AQualifier;
  FileName := AFileName;
end;

class function TFinderItem.CompareFileName(const ALeft, ARight: TFinderItem): Integer;
begin
  Result := CompareStr(ALeft.FileName, ARight.FileName);
end;

{ TFinder }

constructor TFinder.Create(const AFindFileName, AIndexFileName: string);
begin
  Source := TFile.ReadAllLines(AFindFileName);
  ReadItems(AIndexFileName);
end;

function TFinder.FindItem(const AQualifier: string; out AItem: TFinderItem): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to Length(Items) - 1 do
  begin
    if Items[I].Qualifier.Equals(AQualifier) then
    begin
      AItem := Items[I];
      Result := True;
      Break;
    end;
  end;
end;

function TFinder.GetMatches: TArray<string>;
var
  LItem: TFinderItem;
  LItems: TFinderItems;
  LQualifier, LFileName: string;
begin
  for LQualifier in Source do
  begin
    if FindItem(LQualifier, LItem) then
      LItems := LItems + [LItem];
  end;
  TArray.Sort<TFinderItem>(LItems, TComparer<TFinderItem>.Construct(TFinderItem.CompareFileName));
  LFileName := '';
  for LItem in LItems do
  begin
    if not LFileName.Equals(LItem.FileName) then
    begin
      LFileName := LItem.FileName;
      Result := Result + ['File: ' + LFileName];
    end;
    Result := Result + [LItem.Qualifier];
  end;
end;

procedure TFinder.ReadItems(const AIndexFileName: string);
var
  LValue: string;
  LParts: TArray<string>;
begin
  for LValue in TFile.ReadAllLines(AIndexFileName) do
  begin
    LParts := LValue.Split(['|']);
    if Length(LParts) = 2 then
      Items := Items + [TFinderItem.Create(LParts[0], LParts[1])];
  end;
end;

{ TSwitchesHelper }

function TSwitchesHelper.FindSwitch(const AKey: string; out ASwitch: TSwitch): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to Length(Self) - 1 do
  begin
    if SameText(Self[I].Key, AKey) then
    begin
      ASwitch := Self[I];
      Result := True;
      Break;
    end;
  end;
end;

{ TJIDCommand }

class function TJIDCommand.GetIndexFileName: string;
var
  LIndexFileFolder, LFileName: string;
  LIndexVersion, LVersion: Integer;
  LParts: TArray<string>;
begin
  Result := '';
  LIndexVersion := -1;
  LIndexFileFolder := TPath.GetDirectoryName(ParamStr(0));
  for LFileName in TDirectory.GetFiles(LIndexFileFolder, 'androidrtl*.json', TSearchOption.soTopDirectoryOnly) do
  begin
    LParts := LFileName.Split(['.']);
    if (Length(LParts) > 1) and TryStrToInt(LParts[1], LVersion) and (LVersion > LIndexVersion) then
    begin
      LIndexVersion := LVersion;
      Result := LFileName;
    end
    else
      Result := LFileName;
  end;
end;

class procedure TJIDCommand.ImportFromSignatures(const ASignatures: TArray<string>; const AOutputFileName: string; const AOptions: TImportOptions);
var
  LDefinitions: TJavaDefinitions;
begin
  // Used for debugging:
  // TFile.WriteAllLines(AOutputFileName.Replace('.pas', '.sigs.txt'), ASignatures);
  LDefinitions := TSignatureParser.Parse(ASignatures);
  TImportWriter.Generate(AOutputFileName, LDefinitions, AOptions);
end;

class function TJIDCommand.ImportJar(const AJarFileName, AOutputFileName: string; const AOptions: TImportOptions): Cardinal;
var
  LSignatures: TArray<string>;
begin
  if AOptions.OnlyIncluded then
    Result := TJarProcessor.GetSignatures(AJarFileName, AOptions.IncludedClasses, LSignatures)
  else
    Result := TJarProcessor.GetSignatures(AJarFileName, LSignatures);
  // Used for debugging:
  // TFile.WriteAllLines(AOutputFileName.Replace('.pas', 'sigs.txt'), LSignatures);
  if Result = 0 then
    ImportFromSignatures(LSignatures, AOutputFileName, AOptions);
end;

class function TJIDCommand.ImportRtl(const AClasses: TArray<string>; const AOutputFileName: string; const AOptions: TImportOptions): Cardinal;
var
  LSignatures: TArray<string>;
begin
  Result := TJarProcessor.GetRtlSignatures(AClasses, LSignatures);
  if Result = 0 then
    ImportFromSignatures(LSignatures, AOutputFileName, AOptions);
end;

class function TJIDCommand.IndexJars(const AIndexFolder, AMatch, AOutputFileName: string): Cardinal;
var
  LFileNames, LHeaders, LOutput: TArray<string>;
  LFileName: string;
  LHeadersResult: Cardinal;
  I: Integer;
begin
  Result := 0;
  LFileNames := TDirectory.GetFiles(AIndexFolder, AMatch, TSearchOption.soTopDirectoryOnly);
  for LFileName in LFileNames do
  begin
    if LFileName.EndsWith('.jar') then
    begin
      LHeadersResult := TJarProcessor.GetHeaders(LFileName, LHeaders);
      if LHeadersResult = 0 then
      begin
        for I := 0 to Length(LHeaders) - 1 do
          LHeaders[I] := LHeaders[I] + '|' + TPath.GetFileName(LFileName);
        LOutput := LOutput + LHeaders;
      end
      else if Result = 0 then
        Result := LHeadersResult;
    end;
  end;
  TArray.Sort<string>(LOutput);
  TFile.WriteAllLines(AOutputFileName, LOutput);
end;

class function TJIDCommand.Run: Integer;
var
  LSwitches: TSwitches;
  LSwitch: TSwitch;
  LOutputFileName, LOutputDir: string;
begin
  Result := 1;
  if IsJavaHomeValid then
  begin
    LOutputFileName := '';
    LSwitches := GetSwitches;
    if LSwitches.FindSwitch('out', LSwitch) then
    begin
      if Length(LSwitch.Values) > 0 then
      begin
        LOutputFileName := LSwitch.Values[0];
        LOutputDir := TPath.GetDirectoryName(LOutputFileName);
        if not LOutputDir.IsEmpty and not ForceDirectories(LOutputDir) then
        begin
          if not IsConsole then
            Writeln('Unable to create output folder');
        end
        else if LSwitches.FindSwitch('index', LSwitch) then
          Result := RunIndex(LSwitch.Values[0], LOutputFileName, LSwitches)
        else if LSwitches.FindSwitch('find', LSwitch) then
          Result := RunFind(LSwitch, LOutputFileName)
        else
          Result := RunImport(LOutputFileName, LSwitches);
      end;
      if LOutputFileName.IsEmpty and IsConsole then
        Writeln('No output file specified');
    end;
  end;
  if Result = 1 then
    ShowUsage;
end;

class function TJIDCommand.RunFind(const AFindSwitch: TSwitch; AOutputFileName: string): Integer;
var
  LFindFileName, LIndexFileName: string;
  LFinder: TFinder;
begin
  Result := 1;
  if Length(AFindSwitch.Values) > 1 then
  begin
    LFindFileName := AFindSwitch.Values[0];
    LIndexFileName := AFindSwitch.Values[1];
    if TFile.Exists(LFindFileName) and TFile.Exists(LIndexFileName) then
    begin
      LFinder := TFinder.Create(LFindFileName, LIndexFileName);
      TFile.WriteAllLines(AOutputFileName, LFinder.GetMatches);
    end;
  end;
  if (Result = 1) and IsConsole then
    Writeln('Requires valid source and index file names');
end;

class function TJIDCommand.RunImport(const AOutputFileName: string; const ASwitches: TSwitches): Integer;
var
  LSwitch: TSwitch;
  LJarFileName, LClsFileName: string;
  LClasses: TArray<string>;
  LImportOptions: TImportOptions;
  I: Integer;
begin
  Result := 0;
  LClasses := [];
  LImportOptions := Default(TImportOptions);
  if ASwitches.FindSwitch('jar', LSwitch) then
  begin
    if Length(LSwitch.Values) = 0 then
    begin
      if IsConsole then
        Writeln('No jar file specified');
      Result := 1;
    end
    else
      LJarFileName := LSwitch.Values[0];
  end;
  if ASwitches.FindSwitch('file', LSwitch) then
  begin
    Result := 1;
    if Length(LSwitch.Values) = 1 then
    begin
      LClsFileName := LSwitch.Values[0];
      if TFile.Exists(LClsFileName) then
      begin
        LClasses := TFile.ReadAllLines(LClsFileName);
        if Length(LClasses) > 0 then
          Result := 0
        else
          Writeln('Classes file is empty');
      end
      else if IsConsole then
        Writeln('Classes file does not exist');
    end;
  end
  else if ASwitches.FindSwitch('cls', LSwitch) then
    LClasses := LSwitch.Values;
  for I := 0 to Length(LClasses) - 1 do
    LClasses[I] := LClasses[I].Replace('/', '.', [rfReplaceAll]);
  if (Result = 0) and LJarFileName.IsEmpty and (Length(LClasses) = 0) then
  begin
    if IsConsole then
      Writeln('No classes specified');
    Result := 1;
  end;
  if Result = 0 then
  begin
    Result := 1;
    LImportOptions.SymbolIndexFileName := GetIndexFileName;
    if not LImportOptions.SymbolIndexFileName.IsEmpty then
    begin
      if not LJarFileName.IsEmpty then
      begin
        LImportOptions.IncludedClasses := LClasses;
        Result := ImportJar(LJarFileName, AOutputFileName, LImportOptions);
      end
      else
        Result := ImportRtl(LClasses, AOutputFileName, LImportOptions);
      if Result <> 0 then
        Result := 2;
    end;
  end;
end;

class function TJIDCommand.RunIndex(const AIndexFolder, AOutputFileName: string; const ASwitches: TSwitches): Integer;
var
  LSwitch: TSwitch;
  LMatch: string;
begin
  Result := 1;
  LMatch := '';
  if ASwitches.FindSwitch('match', LSwitch) then
  begin
    if Length(LSwitch.Values) > 0 then
    begin
      LMatch := LSwitch.Values[0];
      if IndexJars(AIndexFolder, LMatch, AOutputFileName) = 0 then
        Result := 0
      else
        Result := 2;
    end
  end;
  if LMatch.IsEmpty and IsConsole then
    Writeln('No match specified');
end;

class procedure TJIDCommand.ShowUsage;
var
  LAppName: string;
begin
  if IsConsole then
  begin
    LAppName := TPath.GetFileNameWithoutExtension(ParamStr(0));
    Writeln('Usage:');
    Writeln(Format('  %s [-jar <jarfile>] -out <outfilename> [-cls <classes> | -file <clsfilename>]', [LAppName]));
    Writeln;
    Writeln('Where:');
    Writeln('  <jarfile> is the target jar');
    Writeln('  <classes> are the classes to include, space delimited');
    Writeln('  <outfilename> is the file to output to');
    Writeln('  <clsfilename> file containing the classes to include');
    Writeln;
    Writeln('NOTE:');
    Writeln('  In order to resolve identifiers/units from the Delphi RTL, a valid index file must be in the same folder as this executable');
    Writeln('    See: https://github.com/DelphiWorlds/JID/blob/master/Readme.md#index-files');
    Writeln('  You must have the JAVA_HOME environment variable set to the root of a valid JDK');
    Writeln('  Class names must be fully qualified in dotted notation');
    Writeln('  Filenames with spaces MUST be in quotes');
    Writeln;
    Writeln('Examples:');
    Writeln;
    Writeln(Format('  %s -jar exoplayer-core-2.19.1.jar -out Androidapi.JNI.Exployer.pas -cls com.google.android.exoplayer2.ExoPlayer', [LAppName]));
    Writeln;
    Writeln('Will import com.google.android.exoplayer2.ExoPlayer and dependent classes to Androidapi.JNI.Exployer.pas');
    Writeln;
    Writeln(Format('  %s -out Androidapi.JNI.Rtl.pas -cls java.util.Formatter java.util.zip.Inflater', [LAppName]));
    Writeln;
    Writeln('Will import java.util.Formatter and java.util.zip.Inflater to Androidapi.JNI.Rtl.pas');
    Writeln('When omitting -jar (i.e. import from Java runtime), -cls or -file is required.');
    ExitCode := 1;
  end;
end;

end.
