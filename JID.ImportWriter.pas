unit JID.ImportWriter;

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
  System.Classes,
  JID.JavaTypes;

type
  TImportOptions = record
    IncludedClasses: TArray<string>;
    OnlyIncluded: Boolean;
    SymbolIndexFileName: string;
    procedure IncludeClasses(const AQualifiers: TArray<string>);
  end;

  TImportWriter = record
  private
    class procedure WriteMethod(const AWriter: TTextWriter; const AMethod: TJavaMethod); static;
    class procedure WriteMethodPrefix(const AWriter: TTextWriter; const AIsStatic: Boolean); static;
    class procedure WriteMethods(const AWriter: TTextWriter; const AMethods: TJavaMethods; const AIsStatic: Boolean); static;
    class procedure WriteProperties(const AWriter: TTextWriter; const AMethods: TJavaMethods; const AIsStatic: Boolean); static;
    class procedure WritePropertyGetters(const AWriter: TTextWriter; const AMethods: TJavaMethods; const AIsStatic: Boolean); static;
  public
    class procedure Generate(const AFileName: string; const ADefinitions: TJavaDefinitions; const AOptions: TImportOptions); static;
  end;

implementation

uses
  System.SysUtils, System.IOUtils, System.Generics.Collections, System.Generics.Defaults, System.StrUtils,
  DW.UnitScan, DW.UnitScan.Persistence.NEON;

type
  TJavaMethodParamHelper = record helper for TJavaMethodParam
    procedure Reconcile(const AMaps: TSymbolUnitMaps; const AIsRequiredType: Boolean; var AUnits: TArray<string>);
  end;

  TJavaMethodHelper = record helper for TJavaMethod
    procedure Reconcile(const AMaps: TSymbolUnitMaps; const AIsRequiredType: Boolean; var AUnits: TArray<string>);
  end;

  TJavaMethodsHelper = record helper for TJavaMethods
    procedure SortByName;
  end;

  TJavaDefinitionHelper = record helper for TJavaDefinition
  public
    procedure Reconcile(const AMaps: TSymbolUnitMaps; const AIsRequiredType: Boolean; var AUnits: TArray<string>);
  end;

  TJavaDefinitionsHelper = record helper for TJavaDefinitions
    function Count: Integer;
    function GetDelphiTypes: TArray<string>;
    function GetRequiredTypes(const AIncludeClasses: TArray<string>): TArray<string>;
    procedure GetRequiredParentTypes(const ADefinition: TJavaDefinition; var ATypes: TArray<string>);
    function IndexOfName(const AName: string): Integer;
    function IndexOfParent(const AItem: TJavaDefinition): Integer;
    procedure Reconcile(const AMaps: TSymbolUnitMaps; const ARequiredTypes: TArray<string>; var AUnits: TArray<string>);
    procedure SortByDependency;
    procedure SortByDelphiName;
  end;

  TQualifiersHelper = record helper for TQualifiers
    procedure SaveToFile(const AFileName: string);
  end;

function IsQualified(const AQualifier: string): Boolean;
begin
  Result := not AQualifier.IsEmpty and (AQualifier.IndexOf('.') > -1);
end;

procedure ReconcileSymbol(const ASymbolUnit: string; var ASymbol: string; var AUnits: TArray<string>);
var
  LParts: TArray<string>;
begin
  LParts := ASymbolUnit.Split(['|']);
  if Length(LParts) > 1 then
  begin
    if ASymbol.StartsWith('TJavaObjectArray') then
      ASymbol := Format('TJavaObjectArray<%s>', [LParts[0]])
    else
      ASymbol := LParts[0];
    if not MatchStr(LParts[1], AUnits) then
      AUnits := AUnits + [LParts[1]];
  end;
end;

{ TImportOptions }

procedure TImportOptions.IncludeClasses(const AQualifiers: TArray<string>);
var
  LQualifier: string;
begin
  for LQualifier in AQualifiers do
  begin
    if not MatchStr(LQualifier, IncludedClasses) then
      IncludedClasses := IncludedClasses + [LQualifier];
  end;
end;

{ TJavaMethodParamHelper }

procedure TJavaMethodParamHelper.Reconcile(const AMaps: TSymbolUnitMaps; const AIsRequiredType: Boolean; var AUnits: TArray<string>);
var
  LSymbolUnit, LQualifier: string;
begin
  LQualifier := QualifiedParamType.Trim(['[', ']']);
  if not AIsRequiredType and IsQualified(LQualifier) then
    Qualifiers.Remove(LQualifier)
  else if IsQualified(QualifiedParamType) and AMaps.FindSymbol(QualifiedParamType.Replace('.', '/', [rfReplaceAll]), LSymbolUnit) then
  begin
    Qualifiers.Remove(LQualifier);
    ReconcileSymbol(LSymbolUnit, DelphiParamType, AUnits);
  end;
end;

{ TJavaMethodHelper }

procedure TJavaMethodHelper.Reconcile(const AMaps: TSymbolUnitMaps; const AIsRequiredType: Boolean; var AUnits: TArray<string>);
var
  LSymbolUnit, LQualifier: string;
  I: Integer;
begin
  LQualifier := QualifiedReturnType.Trim(['[', ']']);
  if not AIsRequiredType and IsQualified(LQualifier) then
    Qualifiers.Remove(LQualifier)
  else if IsQualified(LQualifier) and AMaps.FindSymbol(LQualifier.Replace('.', '/', [rfReplaceAll]), LSymbolUnit) then
  begin
    Qualifiers.Remove(LQualifier);
    ReconcileSymbol(LSymbolUnit, DelphiReturnType, AUnits);
  end;
  for I := 0 to Length(Params) - 1 do
    Params[I].Reconcile(AMaps, AIsRequiredType, AUnits);
end;

{ TJavaMethodsHelper }

procedure TJavaMethodsHelper.SortByName;
begin
  TArray.Sort<TJavaMethod>(Self, TComparer<TJavaMethod>.Construct(TJavaMethod.CompareName));
end;

{ TJavaDefinitionHelper }

procedure TJavaDefinitionHelper.Reconcile(const AMaps: TSymbolUnitMaps; const AIsRequiredType: Boolean; var AUnits: TArray<string>);
var
  LSymbolUnit: string;
  I: Integer;
begin
  if IsQualified(Qualifier) then
    Qualifiers.Remove(Qualifier, True);
  if not AIsRequiredType and IsQualified(ParentQualifier) then
    Qualifiers.Remove(ParentQualifier)
  else if IsQualified(ParentQualifier) and AMaps.FindSymbol(ParentQualifier.Replace('.', '/', [rfReplaceAll]), LSymbolUnit) then
  begin
    Qualifiers.Remove(ParentQualifier);
    ReconcileSymbol(LSymbolUnit, ParentDelphiName, AUnits);
  end;
  for I := 0 to Length(Methods) - 1 do
    Methods[I].Reconcile(AMaps, AIsRequiredType, AUnits);
end;

{ TJavaDefinitionsHelper }

function TJavaDefinitionsHelper.Count: Integer;
begin
  Result := Length(Self);
end;

function TJavaDefinitionsHelper.IndexOfName(const AName: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to Count - 1 do
  begin
    if SameText(Self[I].DelphiName, AName) then
    begin
      Result := I;
      Break;
    end;
  end;
end;

function TJavaDefinitionsHelper.IndexOfParent(const AItem: TJavaDefinition): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to Count - 1 do
  begin
    if AItem.ParentQualifier = Self[I].Qualifier then
    begin
      Result := I;
      Break;
    end;
  end;
end;

procedure TJavaDefinitionsHelper.Reconcile(const AMaps: TSymbolUnitMaps; const ARequiredTypes: TArray<string>; var AUnits: TArray<string>);
var
  I: Integer;
begin
  for I := 0 to Length(Self) - 1 do
    Self[I].Reconcile(AMaps, MatchStr(Self[I].DelphiName, ARequiredTypes), AUnits);
end;

procedure TJavaDefinitionsHelper.SortByDependency;
var
  LItems: TJavaDefinitions;
  I: Integer;
begin
  while Count > 0 do
  begin
    for I := Count - 1 downto 0 do
    begin
      if IndexOfParent(Self[I]) = -1 then
      begin
        LItems := LItems + [Self[I]];
        Delete(Self, I, 1);
      end;
    end;
  end;
  Self := LItems;
end;

procedure TJavaDefinitionsHelper.SortByDelphiName;
begin
  TArray.Sort<TJavaDefinition>(Self, TComparer<TJavaDefinition>.Construct(TJavaDefinition.CompareDelphiName));
end;

function TJavaDefinitionsHelper.GetDelphiTypes: TArray<string>;
var
  LDef: TJavaDefinition;
begin
  for LDef in Self do
    Result := Result + [LDef.DelphiName];
end;

procedure TJavaDefinitionsHelper.GetRequiredParentTypes(const ADefinition: TJavaDefinition; var ATypes: TArray<string>);
var
  LIndex: Integer;
  LParentDelphiName, LTypeName: string;
  LDependentTypes: TArray<string>;
begin
  LDependentTypes := ADefinition.GetDependentTypes(ATypes);
  ATypes := ATypes + LDependentTypes;
  for LTypeName in LDependentTypes do
  begin
    LIndex := IndexOfName(LTypeName);
    if LIndex > -1 then
      GetRequiredParentTypes(Self[LIndex], ATypes);
  end;
  LParentDelphiName := ADefinition.GetParentDelphiName(False);
  if not LParentDelphiName.Equals('JObject') and not LParentDelphiName.Equals('IJavaInstance') and not MatchStr(LParentDelphiName, ATypes) then
  begin
    ATypes := ATypes + [LParentDelphiName];
    LIndex := IndexOfName(LParentDelphiName);
    if LIndex > -1 then
      GetRequiredParentTypes(Self[LIndex], ATypes);
  end;
end;

function TJavaDefinitionsHelper.GetRequiredTypes(const AIncludeClasses: TArray<string>): TArray<string>;
var
  LDef: TJavaDefinition;
begin
  Result := [];
  for LDef in Self do
  begin
    if MatchStr(LDef.Qualifier, AIncludeClasses) then
    begin
      Result := Result + [LDef.DelphiName];
      GetRequiredParentTypes(LDef, Result);
    end;
  end;
  TArray.Sort<string>(Result);
end;

{ TQualifiersHelper }

procedure TQualifiersHelper.SaveToFile(const AFileName: string);
var
  LValues: TArray<string>;
  I: Integer;
begin
  Sort;
  SetLength(LValues, Length(Items));
  for I := 0 to Length(Items) - 1 do
    LValues[I] := Items[I].Value.Replace('.', '/', [rfReplaceAll]);
  TFile.WriteAllLines(AFileName, LValues);
end;

{ TImportWriter }

class procedure TImportWriter.Generate(const AFileName: string; const ADefinitions: TJavaDefinitions; const AOptions: TImportOptions);
var
  LWriter: TStreamWriter;
  LDef: TJavaDefinition;
  LSortedDefs: TJavaDefinitions;
  LDelphiName, LIndexFileName: string;
  LMaps: TSymbolUnitMaps;
  LUses, LRequiredTypes, LParts: TArray<string>;
  LSortedMethods: TJavaMethods;
  LIncludeAll: Boolean;
begin
  LIncludeAll := (Length(AOptions.IncludedClasses) = 0) or AOptions.OnlyIncluded;
  if not LIncludeAll then
    LRequiredTypes := ADefinitions.GetRequiredTypes(AOptions.IncludedClasses)
  else if Length(AOptions.IncludedClasses) > 0 then
    LRequiredTypes := TConverter.ConvertQualifiers(AOptions.IncludedClasses)
  else
    LRequiredTypes := ADefinitions.GetDelphiTypes;
  LUses := ['Androidapi.JNIBridge', 'Androidapi.JNI.JavaTypes'];
  LIndexFileName := AOptions.SymbolIndexFileName;
  if not LIndexFileName.IsEmpty and TFile.Exists(LIndexFileName) then
    LMaps.LoadFromFile(LIndexFileName);
  ADefinitions.Reconcile(LMaps, LRequiredTypes, LUses);
  // TODO: Decide whether to create this:
  Qualifiers.SaveToFile(TPath.ChangeExtension(AFileName, '.missing.txt'));
  LWriter := TStreamWriter.Create(AFileName);
  try
    LWriter.WriteLine('unit %s;', [TPath.GetFileNameWithoutExtension(TPath.GetFileName(AFileName))]);
    LWriter.WriteLine;
    LWriter.WriteLine('interface');
    LWriter.WriteLine;
    LWriter.WriteLine('uses');
    LWriter.WriteLine('  ' + string.Join(', ', LUses) + ';');
    LWriter.WriteLine;
    LWriter.WriteLine('type');
    LSortedDefs := Copy(ADefinitions);
    LSortedDefs.SortByDelphiName;
    for LDef in LSortedDefs do
    begin
      if LIncludeAll or MatchStr(LDef.DelphiName, LRequiredTypes) then
      begin
        if not LDef.IsIgnored then
          LWriter.WriteLine('  %s = interface;', [LDef.DelphiName])
        else
          LWriter.WriteLine('  // Ignored: %s', [LDef.Qualifier]);
      end;
    end;
    LSortedDefs := Copy(ADefinitions);
    LSortedDefs.SortByDependency;
    for LDef in LSortedDefs do
    begin
      if not LDef.IsIgnored and (LIncludeAll or MatchStr(LDef.DelphiName, LRequiredTypes)) then
      begin
        LSortedMethods := Copy(LDef.Methods);
        LSortedMethods.SortByName;
        LWriter.WriteLine;
        LDelphiName := LDef.DelphiName;
        LWriter.WriteLine('  %sClass = interface(%s)', [LDelphiName, LDef.GetParentDelphiName(True)]);
        LWriter.WriteLine('    [''%s'']', [TGUID.NewGuid.ToString]);
        WritePropertyGetters(LWriter, LSortedMethods, True);
        WriteMethods(LWriter, LSortedMethods, True);
        WriteProperties(LWriter, LSortedMethods, True);
        LWriter.WriteLine('  end;');
        LWriter.WriteLine;
        LWriter.WriteLine('  [JavaSignature(''%s'')]', [LDef.Qualifier.Replace('.', '/', [rfReplaceAll])]);
        LWriter.WriteLine('  %s = interface(%s)', [LDelphiName, LDef.GetParentDelphiName(False)]);
        LWriter.WriteLine('    [''%s'']', [TGUID.NewGuid.ToString]);
        WritePropertyGetters(LWriter, LSortedMethods, False);
        WriteMethods(LWriter, LSortedMethods, False);
        WriteProperties(LWriter, LSortedMethods, False);
        LWriter.WriteLine('  end;');
        LWriter.WriteLine('  T%s = class(TJavaGenericImport<%sClass, %s>) end;', [LDelphiName, LDelphiName, LDelphiName]);
      end;
    end;
    LWriter.WriteLine;
    LWriter.WriteLine('implementation');
    LWriter.WriteLine;
    LWriter.WriteLine('end.');
  finally
    LWriter.Free;
  end;
end;

class procedure TImportWriter.WriteMethodPrefix(const AWriter: TTextWriter; const AIsStatic: Boolean);
begin
  if AIsStatic then
    AWriter.Write('    {class} ')
  else
    AWriter.Write('    ');
end;

class procedure TImportWriter.WriteMethods(const AWriter: TTextWriter; const AMethods: TJavaMethods; const AIsStatic: Boolean);
var
  LMethod: TJavaMethod;
begin
  for LMethod in AMethods do
  begin
    if not LMethod.IsProperty and (LMethod.IsStatic = AIsStatic) then
    begin
      WriteMethodPrefix(AWriter, LMethod.IsStatic);
      WriteMethod(AWriter, LMethod);
    end;
  end;
end;

class procedure TImportWriter.WriteProperties(const AWriter: TTextWriter; const AMethods: TJavaMethods; const AIsStatic: Boolean);
var
  LMethod: TJavaMethod;
begin
  for LMethod in AMethods do
  begin
    if (LMethod.IsStatic = AIsStatic) and LMethod.IsProperty then
    begin
      WriteMethodPrefix(AWriter, LMethod.IsStatic);
      AWriter.WriteLine('property %s: %s read _Get%s;', [LMethod.DelphiName, LMethod.DelphiReturnType, LMethod.DelphiName.Trim(['&'])]);
    end;
  end;
end;

class procedure TImportWriter.WritePropertyGetters(const AWriter: TTextWriter; const AMethods: TJavaMethods; const AIsStatic: Boolean);
var
  LMethod: TJavaMethod;
begin
  for LMethod in AMethods do
  begin
    if (LMethod.IsStatic = AIsStatic) and LMethod.IsProperty then
    begin
      WriteMethodPrefix(AWriter, LMethod.IsStatic);
      AWriter.WriteLine('function _Get%s: %s; cdecl;', [LMethod.DelphiName.Replace('&', ''), LMethod.DelphiReturnType]);
    end;
  end;
end;

class procedure TImportWriter.WriteMethod(const AWriter: TTextWriter; const AMethod: TJavaMethod);
var
  I: Integer;
  LMethodName: string;
begin
  LMethodName := AMethod.DelphiName;
  if AMethod.DelphiReturnType.IsEmpty then
    AWriter.Write('procedure ' + LMethodName)
  else
    AWriter.Write('function ' + LMethodName);
  if Length(AMethod.Params) > 0 then
  begin
    AWriter.Write('(');
    for I := 0 to Length(AMethod.Params) - 1 do
    begin
      if I > 0 then
        AWriter.Write('; ');
      AWriter.Write('%s: %s', [AMethod.Params[I].Name, AMethod.Params[I].DelphiParamType]);
    end;
    AWriter.Write(')');
  end;
  if not AMethod.DelphiReturnType.IsEmpty then
    AWriter.Write(': ' + AMethod.DelphiReturnType);
  AWriter.Write('; cdecl');
  if AMethod.IsOverload then
    AWriter.Write('; overload');
  AWriter.WriteLine(';');
end;

end.
