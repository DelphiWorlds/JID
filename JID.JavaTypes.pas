unit JID.JavaTypes;

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
  System.SysUtils;

type
  TJavaMethodParam = record
    DelphiParamType: string;
    Name: string;
    ParamType: string;
    QualifiedParamType: string;
    procedure Resolve;
  end;

  TJavaMethodParams = TArray<TJavaMethodParam>;

  TJavaMethod = record
  public
    class function CompareName(const ALeft, ARight: TJavaMethod): Integer; static;
  public
    DelphiName: string;
    DelphiReturnType: string;
    GenericIdentifier: string;
    IsOverload: Boolean;
    IsProperty: Boolean;
    IsStatic: Boolean;
    Name: string;
    QualifiedReturnType: string;
    ReturnType: string;
    Signature: string;
    Params: TJavaMethodParams;
    function CanAddDependentType(const ATypeName: string; const AExistingTypes, ATypes: TArray<string>): Boolean;
    procedure GetDependentTypes(const AExistingTypes: TArray<string>; var ATypes: TArray<string>);
    procedure Reset;
    procedure Resolve;
  end;

  TJavaMethods = TArray<TJavaMethod>;

  TJavaDefinition = record
  private
    function MethodExists(const AIndex: Integer): Boolean;
  public
    class function CompareDelphiName(const ALeft, ARight: TJavaDefinition): Integer; static;
  public
    DelphiName: string;
    IsIgnored: Boolean;
    Kind: string;
    ParentDelphiName: string;
    ParentQualifier: string;
    Qualifier: string;
    Methods: TJavaMethods;
    procedure AddMethod(const AMethod: TJavaMethod);
    function FixUpDelphiName: Boolean;
    procedure FixUpReturnTypes; overload;
    procedure FixUpReturnTypes(const ADefinition: TJavaDefinition); overload;
    function GetDependentTypes(const AExistingTypes: TArray<string>): TArray<string>;
    function GetParentDelphiName(const AForClass: Boolean): string;
    procedure Resolve;
  end;

  TJavaDefinitions = TArray<TJavaDefinition>;

  TConverter = record
  private
    class function FindDependentType(const ADelphiType: string; out AType: string): Boolean; static;
    class function GetDelphiPrimitive(const AJavaType: string): string; static;
  public
    class function ConvertQualifier(const AQualifier: string): string; static;
    class function ConvertQualifiers(const AQualifiers: TArray<string>): TArray<string>; static;
    class function ConvertType(const AQualifier: string): string; static;
    class function IsDelphiPrimitive(const ADelphiType: string): Boolean; static;
    class function RemoveGeneric(const ASource: string): string; static;
    class function TrimBefore(const ASource: string; const AChars: TCharArray): string; static;
  end;

  TQualifierItem = record
  public
    class function CompareName(const ALeft, ARight: TQualifierItem): Integer; static;
  public
    Usage: Integer;
    Value: string;
    function DecUsage: Boolean;
    procedure IncUsage;
    function IsRTL: Boolean;
  end;

  TQualifierItems = TArray<TQualifierItem>;

  TQualifiers = record
  private
    function IndexOf(const AValue: string): Integer;
    function GetValues: TArray<string>;
  public
    Items: TQualifierItems;
    procedure Add(AValue: string);
    procedure Clear;
    function HasRTL: Boolean;
    procedure Remove(const AValue: string; const AAll: Boolean = False);
    procedure Sort;
    property Values: TArray<string> read GetValues;
  end;

var
  Qualifiers: TQualifiers;

implementation

uses
  System.StrUtils, System.Generics.Collections, System.Generics.Defaults;

type
  TTypeMapping = record
    JavaType: string;
    DelphiType: string;
  end;

const
  cUnknownType = 'Unknown';

  // TODO: Also have config for this?
  cPrimitiveTypesMap: array[0..7] of TTypeMapping = (
    (JavaType: 'byte';    DelphiType: 'Byte'),
    (JavaType: 'short';   DelphiType: 'SmallInt'),
    (JavaType: 'int';     DelphiType: 'Integer'),
    (JavaType: 'long';    DelphiType: 'Int64'),
    (JavaType: 'float';   DelphiType: 'Single'),
    (JavaType: 'double';  DelphiType: 'Double'),
    (JavaType: 'char';    DelphiType: 'Char'),
    (JavaType: 'boolean'; DelphiType: 'Boolean')
  );

class function TConverter.GetDelphiPrimitive(const AJavaType: string): string;
var
  LMapping: TTypeMapping;
begin
  Result := cUnknownType;
  for LMapping in cPrimitiveTypesMap do
  begin
    if SameText(LMapping.JavaType, AJavaType) then
    begin
      Result := LMapping.DelphiType;
      Break;
    end;
  end;
end;

class function TConverter.IsDelphiPrimitive(const ADelphiType: string): Boolean;
var
  LMapping: TTypeMapping;
begin
  Result := False;
  for LMapping in cPrimitiveTypesMap do
  begin
    if SameText(LMapping.DelphiType, ADelphiType) then
    begin
      Result := True;
      Break;
    end;
  end;
end;

class function TConverter.RemoveGeneric(const ASource: string): string;
var
  LAngleBracketIndex: Integer;
begin
  Result := ASource;
  LAngleBracketIndex := Result.IndexOf('<');
  if LAngleBracketIndex > 0 then
    Result := Result.Substring(0, LAngleBracketIndex)
end;

class function TConverter.TrimBefore(const ASource: string; const AChars: TCharArray): string;
var
  LChar: Char;
  LIndex: Integer;
begin
  Result := ASource;
  for LChar in AChars do
  begin
    LIndex := Result.IndexOf(LChar);
    if LIndex > -1 then
    begin
      Result := Result.Substring(LIndex + 1);
      Break;
    end;
  end;
end;

class function TConverter.FindDependentType(const ADelphiType: string; out AType: string): Boolean;
var
  LAngleBracketIndex: Integer;
begin
  Result := False;
  if not ADelphiType.StartsWith('TJavaArray') and not TConverter.IsDelphiPrimitive(ADelphiType) then
  begin
    LAngleBracketIndex := ADelphiType.IndexOf('<');
    if LAngleBracketIndex > - 1 then
      AType := ADelphiType.Substring(LAngleBracketIndex + 1, Length(ADelphiType) - LAngleBracketIndex - 2)
    else
      AType := ADelphiType;
    Result := True;
  end;
end;

class function TConverter.ConvertQualifier(const AQualifier: string): string;
var
  LParts: TArray<string>;
begin
  LParts := AQualifier.Split(['.']);
  if Length(LParts) > 0 then
    Result := LParts[Length(LParts) - 1]
  else
    Result := AQualifier;
  Result := 'J' + Result.Replace('$', '_');
end;

class function TConverter.ConvertQualifiers(const AQualifiers: TArray<string>): TArray<string>;
var
  I: Integer;
begin
  for I := 0 to Length(AQualifiers) - 1 do
    Result := Result + [ConvertQualifier(AQualifiers[I].Replace('/', '.', [rfReplaceAll]))];
end;

class function TConverter.ConvertType(const AQualifier: string): string;
var
  LType, LArrayType: string;
begin
  if AQualifier.IndexOf('.') = -1 then
  begin
    if AQualifier.EndsWith('[]') then
    begin
      LType := AQualifier.Trim(['[', ']']);
      LArrayType := GetDelphiPrimitive(LType);
      // The following condition may apply to generic types
      // So it may be necessary to know what the GenericIdentifier is from the method
      // For now, it is just assumed that it *IS* generic
      if LArrayType.Equals(cUnknownType) then
        Result := 'TJavaObjectArray<JObject>'
      else
        Result := Format('TJavaArray<%s>', [LArrayType]);
    end
    else
    begin
      Result := GetDelphiPrimitive(AQualifier);
      if Result.Equals(cUnknownType) then
        Result := 'JObject';
    end;
  end
  else
  begin
    LType := AQualifier.Substring(AQualifier.LastIndexOf('.') + 1).Replace('$', '_', [rfReplaceAll]);
    if LType.EndsWith('[]') then
    begin
      LType := 'J' + LType.Substring(0, Length(LType) - 2);
      Result := Format('TJavaObjectArray<%s>', [LType]);
    end
    else
      Result := 'J' + LType;
  end;
end;

{ TJavaMethodParam }

procedure TJavaMethodParam.Resolve;
begin
  DelphiParamType := TConverter.ConvertType(QualifiedParamType);
end;

{ TJavaMethod }

class function TJavaMethod.CompareName(const ALeft, ARight: TJavaMethod): Integer;
begin
  Result := CompareStr(ALeft.DelphiName.TrimLeft(['&']), ARight.DelphiName.TrimLeft(['&']));
end;

function TJavaMethod.CanAddDependentType(const ATypeName: string; const AExistingTypes, ATypes: TArray<string>): Boolean;
begin
  Result := not ATypeName.Equals('JObject') and not MatchStr(ATypeName, AExistingTypes) and not MatchStr(ATypeName, ATypes);
end;

procedure TJavaMethod.GetDependentTypes(const AExistingTypes: TArray<string>; var ATypes: TArray<string>);
var
  LParam: TJavaMethodParam;
  LType: string;
begin
  for LParam in Params do
  begin
    if TConverter.FindDependentType(LParam.DelphiParamType, LType) and CanAddDependentType(LType, AExistingTypes, ATypes) then
      ATypes := ATypes + [LType];
  end;
  if not DelphiReturnType.IsEmpty and TConverter.FindDependentType(DelphiReturnType, LType) and CanAddDependentType(LType, AExistingTypes, ATypes) then
    ATypes := ATypes + [LType];
end;

procedure TJavaMethod.Reset;
begin
  IsStatic := False;
  Name := '';
  ReturnType := '';
  Signature := '';
  Params := [];
end;

procedure TJavaMethod.Resolve;
var
  I: Integer;
begin
  for I := 0 to Length(Params) - 1 do
    Params[I].Resolve;
  if not QualifiedReturnType.IsEmpty and not QualifiedReturnType.Equals('void') then
    DelphiReturnType := TConverter.ConvertType(QualifiedReturnType)
  else
    DelphiReturnType := string.Empty;
  if DelphiName.IsEmpty and not DelphiReturnType.IsEmpty then
  begin
    IsProperty := True;
    Name := Signature.Trim([';']);
    DelphiName := Name;
  end;
end;

{ TJavaDefinition }

function TJavaDefinition.GetDependentTypes(const AExistingTypes: TArray<string>): TArray<string>;
var
  LMethod: TJavaMethod;
begin
  for LMethod in Methods do
    LMethod.GetDependentTypes(AExistingTypes, Result);
end;

function TJavaDefinition.GetParentDelphiName(const AForClass: Boolean): string;
begin
  if not ParentDelphiName.IsEmpty then
  begin
    Result := ParentDelphiName;
    if AForClass then
      Result := Result + 'Class';
  end
  else if Kind.Equals('interface') and ParentQualifier.IsEmpty then
  begin
    if AForClass then
      Result := 'IJavaClass'
    else
      Result := 'IJavaInstance';
  end
  else if not ParentQualifier.IsEmpty then
  begin
    Result := TConverter.ConvertQualifier(ParentQualifier);
    if AForClass then
      Result := Result + 'Class';
  end
  else if AForClass then
    Result := 'JObjectClass'
  else
    Result := 'JObject';
end;

procedure TJavaDefinition.AddMethod(const AMethod: TJavaMethod);
begin
  Methods := Methods + [AMethod];
end;

class function TJavaDefinition.CompareDelphiName(const ALeft, ARight: TJavaDefinition): Integer;
begin
  Result := CompareStr(ALeft.DelphiName, ARight.DelphiName);
end;

function TJavaDefinition.FixUpDelphiName: Boolean;
var
  LParts: TArray<string>;
  I: Integer;
  LName: string;
begin
  Result := False;
  LParts := Qualifier.Split(['.']);
  for I := Length(LParts) - 1 downto 0 do
  begin
    if not LName.IsEmpty then
      LName := '_' + LName;
    if LName.IsEmpty then
      LName := LParts[I]
    else
      LName := LParts[I].ToLower + LName;
    if (Length(LName) + 1) > Length(DelphiName) then
    begin
      Result := True;
      DelphiName := 'J' + LName;
      Break;
    end;
  end;
end;

procedure TJavaDefinition.FixUpReturnTypes(const ADefinition: TJavaDefinition);
var
  I: Integer;
begin
  for I := 0 to Length(Methods) - 1 do
  begin
    if Methods[I].QualifiedReturnType = ADefinition.Qualifier then
      Methods[I].DelphiReturnType := ADefinition.DelphiName;
  end;
end;

procedure TJavaDefinition.FixUpReturnTypes;
var
  I: Integer;
begin
  for I := 0 to Length(Methods) - 1 do
  begin
    if Methods[I].QualifiedReturnType = Qualifier then
      Methods[I].DelphiReturnType := DelphiName;
  end;
end;

function TJavaDefinition.MethodExists(const AIndex: Integer): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to Length(Methods) - 1 do
  begin
    if (I <> AIndex) and SameText(Methods[I].Name, Methods[AIndex].Name) then
    begin
      Result := True;
      Break;
    end;
  end;
end;

procedure TJavaDefinition.Resolve;
var
  I: Integer;
begin
  DelphiName := TConverter.ConvertQualifier(Qualifier);
  for I := 0 to Length(Methods) - 1 do
  begin
    Methods[I].IsOverload := not Methods[I].Name.IsEmpty and MethodExists(I);
    Methods[I].Resolve;
  end;
end;

{ TQualifierItem }

class function TQualifierItem.CompareName(const ALeft, ARight: TQualifierItem): Integer;
begin
  Result := CompareStr(ALeft.Value, ARight.Value);
end;

procedure TQualifierItem.IncUsage;
begin
  Inc(Usage);
end;

function TQualifierItem.IsRTL: Boolean;
begin
  Result := Value.StartsWith('java.') or Value.StartsWith('javax.') or Value.StartsWith('org.w3c.');
end;

function TQualifierItem.DecUsage: Boolean;
begin
  Dec(Usage);
  Result := Usage = 0;
end;

{ TQualifiers }

procedure TQualifiers.Add(AValue: string);
var
  LIndex: Integer;
  LItem: TQualifierItem;
begin
  if (AValue.IndexOf('.') > -1) then
  begin
    AValue := AValue.Replace('[]', '');
    LIndex := IndexOf(AValue);
    if LIndex = -1 then
    begin
      LItem.Value := AValue;
      LItem.Usage := 1;
      Items := Items + [LItem];
    end
    else
      Items[LIndex].IncUsage;
  end;
end;

procedure TQualifiers.Remove(const AValue: string; const AAll: Boolean = False);
var
  LIndex: Integer;
begin
  LIndex := IndexOf(AValue);
  if LIndex > -1 then
  begin
    if AAll or Items[LIndex].DecUsage then
      Delete(Items, LIndex, 1);
  end;
end;

procedure TQualifiers.Clear;
begin
  Items := [];
end;

function TQualifiers.GetValues: TArray<string>;
var
  I: Integer;
begin
  SetLength(Result, Length(Items));
  for I := 0 to Length(Items) - 1 do
    Result[I] := Items[I].Value;
end;

function TQualifiers.HasRTL: Boolean;
var
  LItem: TQualifierItem;
begin
  Result := False;
  for LItem in Items do
  begin
    if LItem.IsRTL then
    begin
      Result := True;
      Break;
    end;
  end;
end;

function TQualifiers.IndexOf(const AValue: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to Length(Items) - 1 do
  begin  
    if Items[I].Value.Equals(AValue) then
    begin
      Result := I;
      Break;
    end;
  end;
end;

procedure TQualifiers.Sort;
begin
  TArray.Sort<TQualifierItem>(Items, TComparer<TQualifierItem>.Construct(TQualifierItem.CompareName));
end;

end.
