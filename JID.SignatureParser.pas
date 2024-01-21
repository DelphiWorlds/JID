unit JID.SignatureParser;

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
  JID.JavaTypes;

type
  TParseOption = (HasDescriptor);

  TParseOptions = set of TParseOption;

  TSignatureParser = record
  public
    class function IsAccessModifier(const AToken: string): Boolean; static;
    class function IsAccessModifierPublic(const AToken: string): Boolean; static;
    class function IsClassModifierOK(const AToken: string): Boolean; static;
    class function IsGeneralModifier(const AToken: string): Boolean; static;
    class function IsJavaKind(const AToken: string): Boolean; static;
    class function IsModifier(const AToken: string): Boolean; static;
    class function IsModifierAbstract(const AToken: string): Boolean; static;
    class function IsModifierStatic(const AToken: string): Boolean; static;
    class function IsTypeExtension(const AToken: string): Boolean; static;
    class function Parse(const ASignatures: TArray<string>; const AOptions: TParseOptions = []): TJavaDefinitions; static;
  end;

implementation

uses
  System.IOUtils,
  System.SysUtils, System.StrUtils, System.Character,
  DW.TokenReader;

const
  cAccessModifierPublic = 'public';
  cAccessModifierProtected = 'protected';
  cAccessModifierPrivate = 'private';

  cModifierAbstract = 'abstract';
  cModifierDefault = 'default';
  cModifierFinal = 'final';
  cModifierNative = 'native';
  cModifierStatic = 'static';
  cModifierStrictFP = 'strictfp';
  cModifierSynchronized = 'synchronized';
  cModifierTransient = 'transient';
  cModifierVolatile = 'volatile';

  cJavaKindClass = 'class';
  cJavaKindInterface = 'interface';

  cTypeExtensionExtends = 'extends';
  cTypeExtensionImplements = 'implements';

const
  // TODO: Make this readable from config
  // TODO: Some of these may be contextual
  cReservedWords: array[0..83] of string = (
    'absolute', 'abstract', 'and', 'array', 'as', 'asm', 'assembler', {'automated',} 'begin', 'case', 'cdecl', 'class', 'const', 'constructor',
    {'contains', } 'default', 'deprecated', 'destructor', 'dispid', 'dispinterface', 'div', 'do', 'downto', 'dynamic', 'else', 'end', 'except',
    {'export', 'exports', 'external',} 'far', 'file', {'final',} 'finalization', 'finally', 'for', 'forward', 'function', 'goto', 'if',
    'implementation', 'implements', 'in', {'index', } 'inherited', 'initialization', 'inline', 'interface', 'is', 'label', 'library', {'message',}
    'mod', {'name',} 'near', 'nil', 'nodefault', 'not', 'object', 'of', 'on', 'or', 'out', 'overload', 'override', {'package', 'packed', 'pascal',}
    'private', 'procedure', {'program',} 'property', 'protected', 'public', 'published', 'raise', {'read', 'readonly', 'record', 'register',}
    'reintroduce', {'repeat', 'requires', 'resident',} 'resourcestring', 'safecall', {'sealed',} 'set', 'shl', 'shr', 'stdcall', {'stored',} 'string',
    'then', 'threadvar', 'to', 'try', 'type', 'unit', 'until', 'uses', 'var', 'virtual', 'while', 'with', {'write', 'writeonly',} 'xor'
  );

type
  TKeyModifier = (mPublic, mStatic);

  TKeyModifiers = set of TKeyModifier;

  TJavaMethodHelper = record helper for TJavaMethod
    procedure AddParam(const AParam: TJavaMethodParam);
    function GetUniqueParamName(const AParamType: string): string;
    function IndexOfParam(const AParamName: string): Integer;
    procedure Parse;
    procedure ParseParams(const ASignature: string);
  end;

{ TJavaMethodHelper }

procedure TJavaMethodHelper.Parse;
var
  LParts: TArray<string>;
  LParamsSignature: string;
  LOpenBracketIndex, LCloseBracketIndex, LAngleBracketIndex: Integer;
begin
  if ReturnType.IsEmpty then
  begin
    Name := 'init';
    DelphiName := 'init';
    IsStatic := True;
    LOpenBracketIndex := Signature.IndexOf('(');
    if LOpenBracketIndex > -1 then
      QualifiedReturnType := Signature.Substring(0, LOpenBracketIndex)
    else
      QualifiedReturnType := Signature;
    if LOpenBracketIndex > -1 then
      LParts := Signature.Substring(0, LOpenBracketIndex).Split(['.'])
    else
      LParts := Signature.Split(['.']);
    if Length(LParts) > 0 then
      ReturnType := LParts[Length(LParts) - 1]
    else
      ReturnType := Signature;
    if LOpenBracketIndex > -1 then
    begin
      LCloseBracketIndex := Signature.IndexOf(')');
      LParamsSignature := Signature.Substring(LOpenBracketIndex + 1, LCloseBracketIndex - LOpenBracketIndex - 1);
    end;
  end
  else
  begin
    QualifiedReturnType := ReturnType;
    Qualifiers.Add(QualifiedReturnType);
    LAngleBracketIndex := ReturnType.IndexOf('<');
    if LAngleBracketIndex > -1 then
      ReturnType := ReturnType.Substring(0, LAngleBracketIndex);
    LParts := ReturnType.Split(['.']);
    if Length(LParts) > 0 then
      ReturnType := LParts[Length(LParts) - 1]
    else
      ReturnType := QualifiedReturnType;
    LOpenBracketIndex := Signature.IndexOf('(');
    if LOpenBracketIndex > -1 then
    begin
      LCloseBracketIndex := Signature.IndexOf(')');
      LParamsSignature := Signature.Substring(LOpenBracketIndex + 1, LCloseBracketIndex - LOpenBracketIndex - 1);
      Name := Signature.Substring(0, LOpenBracketIndex);
      DelphiName := Name;
      if MatchText(DelphiName, cReservedWords) then
        DelphiName := '&' + DelphiName;
    end;
  end;
  ParseParams(LParamsSignature);
  if Name.IsEmpty and not ReturnType.IsEmpty then
  begin
    IsProperty := True;
    DelphiName := Signature.Trim([';']);
    if MatchText(DelphiName, cReservedWords) then
      DelphiName := '&' + DelphiName;
  end;
end;

procedure TJavaMethodHelper.ParseParams(const ASignature: string);
var
  LParamType, LParamTypeItem: string;
  LParam: TJavaMethodParam;
  LParts: TArray<string>;
  LAngleBracketIndex: Integer;
begin
  for LParamTypeItem in ASignature.Split([','], '<', '>') do
  begin
    LParamType := LParamTypeItem.Trim;
    LParam := Default(TJavaMethodParam);
    LAngleBracketIndex := LParamType.IndexOf('<');
    if LAngleBracketIndex > -1 then
      LParamType := LParamType.Substring(0, LAngleBracketIndex);
    // Turn varargs into single
    if LParamType.EndsWith('...') then
      LParamType := LParamType.Replace('...', '');
    LParam.QualifiedParamType := LParamType;
    Qualifiers.Add(LParam.QualifiedParamType);
    LParts := LParamType.Split(['.']);
    if Length(LParts) > 1 then
      LParam.ParamType := LParts[Length(LParts) - 1]
    else
      LParam.ParamType := LParamType;
    LParam.Name := GetUniqueParamName(LParam.ParamType);
    AddParam(LParam);
  end;
end;

procedure TJavaMethodHelper.AddParam(const AParam: TJavaMethodParam);
begin
  Params := Params + [AParam];
end;

function TJavaMethodHelper.GetUniqueParamName(const AParamType: string): string;
var
  LCounter: Integer;
  LBaseName: string;
begin
  LBaseName := TConverter.TrimBefore(AParamType, ['$']);
  if LBaseName.Contains('[]') then
    LBaseName := LBaseName.Replace('[]', 's');
  LCounter := 1;
  if MatchText(LBaseName, cReservedWords) or TConverter.IsDelphiPrimitive(Result) then
    Result := LBaseName + '_' + IntToStr(LCounter)
  else
    Result := LBaseName;
  while IndexOfParam(Result) > -1 do
  begin
    Result := LBaseName + '_' + IntToStr(LCounter);
    Inc(LCounter);
  end;
  Result := Result.ToLower;
end;

function TJavaMethodHelper.IndexOfParam(const AParamName: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to Length(Params) - 1 do
  begin
    if SameText(AParamName, Params[I].Name) then
    begin
      Result := I;
      Break;
    end;
  end;
end;

{ TSignatureParser }

class function TSignatureParser.IsAccessModifier(const AToken: string): Boolean;
const
  cAccessModifiers: array[0..2] of string = (cAccessModifierPublic, cAccessModifierProtected, cAccessModifierPrivate);
begin
  Result := IndexStr(AToken, cAccessModifiers) > -1;
end;

class function TSignatureParser.IsAccessModifierPublic(const AToken: string): Boolean;
begin
  Result := AToken.Equals(cAccessModifierPublic);
end;

class function TSignatureParser.IsClassModifierOK(const AToken: string): Boolean;
begin
  Result := IsAccessModifierPublic(AToken) or IsModifierAbstract(AToken);
end;

class function TSignatureParser.IsGeneralModifier(const AToken: string): Boolean;
begin
  Result := IsAccessModifier(AToken) or IsModifier(AToken);
end;

class function TSignatureParser.IsJavaKind(const AToken: string): Boolean;
begin
  Result := AToken.Equals(cJavaKindClass) or AToken.Equals(cJavaKindInterface);
end;

class function TSignatureParser.IsModifier(const AToken: string): Boolean;
const
  cModifiers: array[0..8] of string = (
    cModifierAbstract, cModifierDefault, cModifierFinal, cModifierNative, cModifierStatic, cModifierStrictFP, cModifierSynchronized,
    cModifierTransient, cModifierVolatile
  );
begin
  Result := IndexStr(AToken, cModifiers) > -1;
end;

class function TSignatureParser.IsModifierAbstract(const AToken: string): Boolean;
begin
  Result := AToken.Equals(cModifierAbstract);
end;

class function TSignatureParser.IsModifierStatic(const AToken: string): Boolean;
begin
  Result := AToken.Equals(cModifierStatic);
end;

class function TSignatureParser.IsTypeExtension(const AToken: string): Boolean;
begin
  Result := AToken.Equals(cTypeExtensionExtends) or AToken.Equals(cTypeExtensionImplements);
end;

// TODO: I've created a monster, but nobody wantsta deal with such a beast - needs refactoring and explanation as to WTF it is doing
class function TSignatureParser.Parse(const ASignatures: TArray<string>; const AOptions: TParseOptions = []): TJavaDefinitions;
var
  LReader: TTokenReader;
  LToken, LQualifier: string;
  LDef: TJavaDefinition;
  LMethod: TJavaMethod;
  LAngleBracketIndex, LCommaIndex: Integer;
  LKeyModifiers: TKeyModifiers;
begin
  Qualifiers.Clear;
  LReader := TTokenReader.Create(ASignatures);
  while not LReader.EOF do
  begin
    LToken := LReader.Next;
    // Expect: [Access modifier] [Modifiers] ([class|interface]) (qualifier) [extends] [implements (list)] ({)
    // No access modifier = private, but private abstract classes need to be included in case public classes are descended from it
    if IsClassModifierOK(LToken) then
    begin
      repeat
        LToken := LReader.Next;
      until LReader.EOF or not IsModifier(LToken);
      // class or interface
      if not LReader.EOF and IsJavaKind(LToken) then
      begin
        LDef := Default(TJavaDefinition);
        LDef.Kind := LToken;
        // Read qualifier
        LQualifier := LReader.Next;
        LAngleBracketIndex := LQualifier.IndexOf('<');
        if LAngleBracketIndex > -1 then
        begin
          if not LQualifier.EndsWith('>') then
          repeat
            LQualifier := LQualifier + ' ' + LReader.Next;
          until LReader.EOF or LQualifier.EndsWith('>');
          LQualifier := LQualifier.Substring(0, LAngleBracketIndex);
        end;
        LDef.Qualifier := LQualifier;

        // Expect: extends or implements, or {
        repeat
          LToken := LReader.Next;
          if LToken.Equals(cTypeExtensionExtends) then
          begin
            LDef.ParentQualifier := LReader.Next;
            LAngleBracketIndex := LDef.ParentQualifier.IndexOf('<');
            if LAngleBracketIndex > -1 then
              LDef.ParentQualifier := LDef.ParentQualifier.Substring(0, LAngleBracketIndex);
            LCommaIndex := LDef.ParentQualifier.IndexOf(',');
            if LCommaIndex > -1 then
              LDef.ParentQualifier := LDef.ParentQualifier.Substring(0, LCommaIndex);
            Qualifiers.Add(LDef.ParentQualifier);
          end
          else if LToken.Equals(cTypeExtensionImplements) then
          begin
            repeat
              LToken := LReader.Next;
            until LReader.EOF or  LToken.Equals('{');
          end;
        until LReader.EOF or LToken.Equals('{');

        if not LReader.EOF then
        begin
          // Member descriptors
          LToken := LReader.Next;
          if not LToken.Equals('}') then
          repeat
            LMethod := Default(TJavaMethod);
            LKeyModifiers := [];
            while IsGeneralModifier(LToken) do
            begin
              if IsAccessModifierPublic(LToken) then
                Include(LKeyModifiers, TKeyModifier.mPublic)
              else if IsModifierStatic(LToken) then
                Include(LKeyModifiers, TKeyModifier.mStatic);
              LToken := LReader.Next;
            end;
            // Key modifiers *must* include public
            if TKeyModifier.mPublic in LKeyModifiers then
            begin
              LMethod.IsStatic := TKeyModifier.mStatic in LKeyModifiers;
              // Skip, for example: <T>
              if LToken.StartsWith('<') then
              begin
                while LToken.CountChar('<') <> LToken.CountChar('>') do
                  LToken := LToken + LReader.Next;
                LToken := LReader.Next;
              end;
              // Next part should be return type, or method signature if constructor
              // If it's a return type, "(" will NOT be present, and will not end with ";"
              while (LToken.IndexOf('(') = -1) and not LToken.EndsWith(';') do
              begin
                if not LMethod.ReturnType.IsEmpty then
                   LMethod.ReturnType := LMethod.ReturnType + ' ';
                LMethod.ReturnType := LMethod.ReturnType + LToken;
                LToken := LReader.Next;
              end;
              if not LMethod.ReturnType.IsEmpty then
                LMethod.ReturnType := TConverter.RemoveGeneric(LMethod.ReturnType);
              while not LToken.EndsWith(';') do
                LToken := LToken + ' ' + LReader.Next;
              LMethod.Signature := LToken;
            end;
            if TParseOption.HasDescriptor in AOptions then
            begin
              LReader.Seek('descriptor:');
              LReader.Next;
            end;
            LMethod.Parse;
            if not LDef.IsIgnored and not LMethod.Signature.IsEmpty then
              LDef.AddMethod(LMethod);
            LToken := LReader.Next;
          until LReader.EOF or LToken.Equals('}');
          if LToken.Equals('}') then
          begin
            LDef.Resolve;
            Result := Result + [LDef];
          end;
        end;
      end;
    end
    else
      LReader.Seek('}');
  end;
end;

end.
