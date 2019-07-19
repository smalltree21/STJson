unit uSTJson;

interface

// History
//    - 2019.07.19
//      - Start - Goal of this project is JSON parser

uses
  SysUtils, Classes;

type
  Int32 = Integer;
  Int32Array = array[0..$FFFE] of Integer;
  PInt32Array = ^Int32Array;

  TSTJsonNodeType = (ntString, ntNumber);

  TSTJsonNodeInfo = record
    sName : AnsiString;
    sValue : AnsiString;
    iType : TSTJsonNodeType;
  end;
  PSTJsonNodeInfo = ^TSTJsonNodeInfo;

  TSTJsonNodeList = class(TList)
  private
    function GetNodes(Idx: Integer): PSTJsonNodeInfo;
    function GetNodeByName(Name: AnsiString): PSTJsonNodeInfo;

  protected
    procedure Notify(Ptr: Pointer; Action: TListNotification); override;

  public
    property Nodes[Idx : Integer] : PSTJsonNodeInfo read GetNodes;
    property NodeByName[Name : AnsiString] : PSTJsonNodeInfo read GetNodeByName; default;

    function NewOne : PSTJsonNodeInfo;
    function FindByName(Name : AnsiString) : Integer;

  end;

  TSTJsonParser = class
  private

  protected
    moNodeList : TSTJsonNodeList;
    mpJsonStr : PAnsiString;
    miJsonStrLen : Integer;

    function SkipWS(var P : Integer) : Integer;
    function ExtractID(P : Integer; var S : AnsiString) : Integer;
    function ExtractNumber(P : Integer; var S : AnsiString) : Integer;
    function ExtractQuoteString(P : Integer; var S : AnsiString) : Integer;
    function ExtractTokenString(P : Integer; var S : AnsiString) : Integer;
    function ParseSingleField(var P : Integer) : Integer;
    function ParseBraceBlock(var P : Integer) : Integer;

  public
    property NodeList : TSTJsonNodeList read moNodeList;

    constructor Create;
    destructor Destroy; override;

    function Parse(JsonStr : AnsiString) : Integer;
    function ParseP(PJsonStr : PAnsiString) : Integer;

  end;

implementation


{ TSTJsonNodeList }

function TSTJsonNodeList.FindByName(Name: AnsiString): Integer;
var
  i : Integer;
begin
  Result := -1;
  for i := 0 to Count-1 do
    if AnsiCompareText(Name, GetNodes(i).sName) = 0 then
    begin
      Result := i;
      EXIT;
    end;
end;

function TSTJsonNodeList.GetNodeByName(Name: AnsiString): PSTJsonNodeInfo;
var
  Idx : Integer;
begin
  Result := nil;
  Idx := FindByName(Name);
  if Idx < 0 then
    EXIT;

  Result := GetNodes(Idx);
end;

function TSTJsonNodeList.GetNodes(Idx: Integer): PSTJsonNodeInfo;
begin
  Result := List[Idx];
end;

function TSTJsonNodeList.NewOne : PSTJsonNodeInfo;
begin
  GetMem(Result, sizeof(TSTJsonNodeInfo));
  FillChar(Pointer(Result)^, sizeof(TSTJsonNodeInfo), #0);
  Add(Result);
end;

procedure TSTJsonNodeList.Notify(Ptr: Pointer; Action: TListNotification);
begin
  inherited;
  if Action = lnDeleted then
    FreeMem(Ptr);
end;

{ TSTJsonParser }

constructor TSTJsonParser.Create;
begin
  inherited;
  moNodeList := TSTJsonNodeList.Create;
end;

destructor TSTJsonParser.Destroy;
begin
  moNodeList.Destroy;
  inherited;
end;

function TSTJsonParser.ExtractID(P: Integer; var S: AnsiString): Integer;
var
  SP, L : Integer;
begin
  Result := -1;
  case mpJsonStr^[P] of
    'a'..'z', 'A'..'Z' : ;
    else
      EXIT;
  end;

  SP := P;
  Inc(P);
  if P > L then
    EXIT;

  while mpJsonStr^[P] in ['a'..'z', 'A'..'Z'] do
  begin
    Inc(P);
    if P > L then
      EXIT;
  end;

  L := P-SP-1;
  SetLength(S, L);
  Move(Pointer(@mpJsonStr^[SP+1])^, Pointer(@S[1])^, L);
  Result := L;
end;

function TSTJsonParser.ExtractNumber(P: Integer; var S: AnsiString): Integer;
var
  SP, L : Integer;
begin
  Result := -1;
  case mpJsonStr^[P] of
    '+', '-', '0'..'9' : ;
    else
      EXIT;
  end;

  SP := P;
  Inc(P);
  if P > L then
    EXIT;

  while mpJsonStr^[P] in ['0'..'9'] do
  begin
    Inc(P);
    if P > L then
      EXIT;
  end;

  L := P-SP-1;
  SetLength(S, L);
  Move(Pointer(@mpJsonStr^[SP+1])^, Pointer(@S[1])^, L);
  Result := L;
end;

function TSTJsonParser.ExtractQuoteString(P: Integer; var S: AnsiString): Integer;
var
  SP, L : Integer;
begin
  Result := -1;
  if mpJsonStr^[P] <> '"' then
    EXIT;

  SP := P;

  Inc(P);
  while TRUE do
  begin
    if P > miJsonStrLen then
      EXIT;

    if mpJsonStr^[P] = '"' then
      break;

    Inc(P);
  end;

  L := P-SP-1;
  SetLength(S, L);
  Move(Pointer(@mpJsonStr^[SP+1])^, Pointer(@S[1])^, L);
  Result := L;
end;

function TSTJsonParser.ExtractTokenString(P: Integer; var S: AnsiString): Integer;
begin
  Result := -1;
  if SkipWS(P) < 0 then
    EXIT;

  case mpJsonStr^[P] of
    '+', '-', '0'..'9' : Result := ExtractNumber(P, S);
    'a'..'z', 'A'..'Z' : Result := ExtractID(P, S);
  end;
end;

function TSTJsonParser.Parse(JsonStr: AnsiString): Integer;
var
  P : Integer;
begin
  mpJsonStr := @JsonStr;
  miJsonStrLen := Length(JsonStr);
  moNodeList.Clear();

  Result := -1;
  if miJsonStrLen <= 0 then
    EXIT;

  P := 1;
  Result := ParseBraceBlock(P);
end;

function TSTJsonParser.ParseBraceBlock(var P: Integer): Integer;
var
  Cnt : Integer;
begin
  Result := -1;
  if SkipWS(P) < 0 then
    EXIT;

  if mpJsonStr^[P] <> '{' then
    EXIT;

  Cnt := 0;
  Inc(P);
  while ParseSingleField(P) >= 0 do
  begin
    SkipWS(P);
    if P > miJsonStrLen then
      EXIT;

    if mpJsonStr^[P] = '}' then
      break
    else if mpJsonStr^[P] <> ',' then
       EXIT;

    Inc(Cnt);
    Inc(P);
  end;

  if mpJsonStr^[P] <> '}' then
    EXIT;

  Result := Cnt;
end;

function TSTJsonParser.ParseP(PJsonStr: PAnsiString): Integer;
var
  P : Integer;
begin
  mpJsonStr := PJsonStr;
  miJsonStrLen := Length(PJsonStr^);
  moNodeList.Clear();

  Result := -1;
  if miJsonStrLen <= 0 then
    EXIT;

  P := 1;
  Result := ParseBraceBlock(P);
end;

function TSTJsonParser.ParseSingleField(var P: Integer): Integer;
var
  SP, L : Integer;
  FieldName,
  FieldValue : AnsiString;
  ValueType : TSTJsonNodeType;
begin
  Result := -1;
  if SkipWS(P) < 0 then
    EXIT;

  SP := P;
  if mpJsonStr^[P] = '"' then
  begin
    if ExtractQuoteString(P, FieldName) < 0 then
      EXIT;

    P := P + Length(FieldName)+2;
  end
  else
  begin
    if ExtractTokenString(P, FieldName) < 0 then
      EXIT;

    P := P + Length(FieldName);
  end;

  if SkipWS(P) < 0 then
    EXIT;

  if mpJsonStr^[P] <> ':' then
    EXIT;

  Inc(P);
  if SkipWS(P) < 0 then
    EXIT;

  if mpJsonStr^[P] = '"' then
  begin
    if ExtractQuoteString(P, FieldValue) < 0 then
      EXIT;

    P := P + Length(FieldValue)+2;
    ValueType := ntString;
  end
  else
  begin
    if ExtractTokenString(P, FieldValue) < 0 then
      EXIT;

    P := P + Length(FieldValue);
    ValueType := ntNumber;
  end;

  with moNodeList.NewOne^ do
  begin
    sName := FieldName;
    sValue := FieldValue;
    iType := ValueType;
  end;

  Result := P-SP;
end;

function TSTJsonParser.SkipWS(var P: Integer): Integer;
begin
  Result := -1;
  if P > miJsonStrLen then
    EXIT;

  while (mpJsonStr^[P] = ' ') OR (mpJsonStr^[P] = #9) OR (mpJsonStr^[P] = #10) OR (mpJsonStr^[P] = #13) do
    Inc(P);

  Result := P;
end;

end.

