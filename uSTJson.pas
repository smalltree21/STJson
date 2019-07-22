unit uSTJson;

interface

// History
//    - 2019.07.19
//      - Start - Goal of this project is JSON parser

uses
  SysUtils, Classes;

type
  TSTJsonParser = class;

  TSTJsonNodeType = (ntNone, ntObject, ntObjectField, ntArray, ntArrayField, ntSingleValue);
  TSTJsonValueType = (vtNone, vtString, vtNumber, vtID, vtObject, vtArray, vtNull);

  TSTJsonNodeInfo = record
    sName : AnsiString;
    sValue : AnsiString;
    iPos : Integer;
    iValueType : TSTJsonValueType;
    iNodeType : TSTJsonNodeType;
  end;
  PSTJsonNodeInfo = ^TSTJsonNodeInfo;

  TSTJsonNodeList = class(TList)
  private
    function GetNodes(Idx: Integer): PSTJsonNodeInfo;
    function GetNodeByName(Name: AnsiString): PSTJsonNodeInfo;

  protected
    moOwner : TSTJsonParser;

    procedure Notify(Ptr: Pointer; Action: TListNotification); override;

  public
    property Nodes[Idx : Integer] : PSTJsonNodeInfo read GetNodes;
    property NodeByName[Name : AnsiString] : PSTJsonNodeInfo read GetNodeByName; default;

    constructor Create(AOwner : TSTJsonParser);

    function NewOne : PSTJsonNodeInfo;
    function FindByName(Name : AnsiString) : Integer;

    function AddList(Node : TSTJsonNodeList; List : TSTJsonNodeList) : Integer;

  end;

  PSTJsonTreeNodeInfo = ^TSTJsonTreeNodeInfo;
  TSTJsonTreeNodeInfo = record
    pNode : PSTJsonNodeInfo;
    pParent : PSTJsonTreeNodeInfo;
    iChildCount : Integer;
    pChilds : PPointerArray;
  end;

  TSTJsonTree = class(TList)
  private

  protected
    moOwner : TSTJsonParser;

    function GetNodes(Idx: Integer): PSTJsonTreeNodeInfo;

    procedure Notify(Ptr: Pointer; Action: TListNotification); override;

  public
    property Nodes[Idx : Integer] : PSTJsonTreeNodeInfo read GetNodes;

    constructor Create(AOwner : TSTJsonParser);

    function NewNode(Parent : PSTJsonTreeNodeInfo) : PSTJsonTreeNodeInfo;
    function AddTree(Note : PSTJsonTreeNodeInfo; Tree : TSTJsonTree) : Integer;

  end;

  TSTJsonParser = class
  private

  protected
    mpaNodeStack : array[0..255] of PSTJsonTreeNodeInfo;
    miNodeStackCount : Integer;

    moNodeList : TSTJsonNodeList;
    moJsonTree : TSTJsonTree;
    mpTreeNode : PSTJsonTreeNodeInfo;
    mpJsonStr : PAnsiString;
    miJsonStrLen : Integer;

    function StackNode(NewNode : PSTJsonTreeNodeInfo) : Integer;
    function UnstackNode : PSTJsonTreeNodeInfo;
    function ParentNodeType : TSTJsonNodeType;

    function SkipWS(var P : Integer) : Integer;
    function ExtractID(P : Integer; var S : AnsiString) : Integer;
    function ExtractNumber(P : Integer; var S : AnsiString) : Integer;
    function ExtractQuoteString(P : Integer; var S : AnsiString) : Integer;
    function ExtractTokenString(P : Integer; var S : AnsiString) : Integer;
    function ExtractTokenStringTP(P : Integer; var S : AnsiString; var TP : TSTJsonValueType) : Integer;
    function ParseSingleField(var P : Integer) : Integer;
    function ParseBraceBlock(var P : Integer) : Integer;
    function ParseBracketBlock(var P : Integer) : Integer;
    
  public
    property NodeList : TSTJsonNodeList read moNodeList;
    property JsonTree : TSTJsonTree read moJsonTree;

    constructor Create;
    destructor Destroy; override;

    function Parse(JsonStr : AnsiString) : Integer;
    function ParseP(PJsonStr : PAnsiString) : Integer;

  end;

implementation

{ TSTJsonNodeList }

function TSTJsonNodeList.AddList(Node, List: TSTJsonNodeList): Integer;
begin

end;

constructor TSTJsonNodeList.Create(AOwner: TSTJsonParser);
begin
  inherited Create;
  moOwner := AOwner;
end;

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

{ TSTJsonTree }

function TSTJsonTree.AddTree(Note : PSTJsonTreeNodeInfo; Tree: TSTJsonTree): Integer;
begin

end;

constructor TSTJsonTree.Create(AOwner: TSTJsonParser);
begin
  inherited Create;
  moOwner := AOwner;
end;

function TSTJsonTree.GetNodes(Idx: Integer): PSTJsonTreeNodeInfo;
begin
  Result := List[Idx];
end;

function TSTJsonTree.NewNode(Parent: PSTJsonTreeNodeInfo): PSTJsonTreeNodeInfo;
begin
  GetMem(Result, sizeof(TSTJsonTreeNodeInfo));
  FillChar(Pointer(Result)^, sizeof(TSTJsonTreeNodeInfo), #0);
  Add(Result);

  Result.pNode := moOwner.moNodeList.NewOne;
  Result.pParent := Parent;
  Result.iChildCount := 0;
end;

procedure TSTJsonTree.Notify(Ptr: Pointer; Action: TListNotification);
begin
  inherited;
  if Action = lnDeleted then
    FreeMem(Ptr);
end;

{ TSTJsonParser }

constructor TSTJsonParser.Create;
begin
  inherited;
  moNodeList := TSTJsonNodeList.Create(Self);
  moJsonTree := TSTJsonTree.Create(Self);
end;

destructor TSTJsonParser.Destroy;
begin
  moNodeList.Destroy;
  moJsonTree.Destroy;
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

  L := P-SP;
  SetLength(S, L);
  Move(Pointer(@mpJsonStr^[SP])^, Pointer(@S[1])^, L);
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

  L := P-SP;
  SetLength(S, L);
  Move(Pointer(@mpJsonStr^[SP])^, Pointer(@S[1])^, L);
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

function TSTJsonParser.ExtractTokenStringTP(P: Integer; var S: AnsiString; var TP : TSTJsonValueType): Integer;
begin
  Result := -1;
  if SkipWS(P) < 0 then
    EXIT;

  case mpJsonStr^[P] of
    '+', '-', '0'..'9' : begin Result := ExtractNumber(P, S); TP := vtNumber; end;
    'a'..'z', 'A'..'Z' : begin Result := ExtractID(P, S); TP := vtID; end;
  end;
end;

function TSTJsonParser.ParentNodeType : TSTJsonNodeType;
begin
  Result := ntNone;
  if miNodeStackCount <= 0 then
    EXIT;

  Result := mpaNodeStack[miNodeStackCount-1].pNode.iNodeType;
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

  mpTreeNode := nil;

  P := 1;
  Result := ParseBraceBlock(P);
end;

function TSTJsonParser.ParseBraceBlock(var P: Integer): Integer;
var
  Cnt : Integer;
  TreeNode : PSTJsonTreeNodeInfo;
begin
  Result := -1;
  if SkipWS(P) < 0 then
    EXIT;

  if mpJsonStr^[P] <> '{' then
    EXIT;

  TreeNode := moJsonTree.NewNode(mpTreeNode);
  StackNode(TreeNode);
  TreeNode.pNode.sName := '';
  TreeNode.pNode.sValue := '{';
  TreeNode.pNode.iNodeType := ntObject;
  TreeNode.pNode.iValueType := vtObject;
  TreeNode.pNode.iPos := P;

  Cnt := 0;
  try
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
  finally
    UnstackNode();
  end;

  Result := Cnt;
end;

function TSTJsonParser.ParseBracketBlock(var P: Integer): Integer;
label
  TailOfWhile;
var
  Cnt : Integer;
  FieldValue : AnsiString;
  TreeNode : PSTJsonTreeNodeInfo;
  ValueType : TSTJsonValueType;
begin
  Result := -1;
  if SkipWS(P) < 0 then
    EXIT;

  if mpJsonStr^[P] <> '[' then
    EXIT;

  TreeNode := moJsonTree.NewNode(mpTreeNode);
  StackNode(TreeNode);
  TreeNode.pNode.sName := '';
  TreeNode.pNode.sValue := '[';
  TreeNode.pNode.iNodeType := ntArray;
  TreeNode.pNode.iValueType := vtArray;
  TreeNode.pNode.iPos := P;

  Cnt := 0;
  try
    Inc(P);
    while TRUE do
    begin
      if SkipWS(P) < 0 then
        EXIT;

      case mpJsonStr^[P] of
        '[' :
        begin
          if ParseBracketBlock(P) < 0 then
            EXIT;

          Inc(P);
        end;

        '{' :
        begin
          if ParseBraceBlock(P) < 0 then
            EXIT;

          Inc(P);
        end;

        '"' :
        begin
          ExtractQuoteString(P, FieldValue);

          TreeNode := moJsonTree.NewNode(mpTreeNode);
          TreeNode.pNode.sName := '';
          TreeNode.pNode.sValue := FieldValue;
          TreeNode.pNode.iNodeType := ntArrayField;
          TreeNode.pNode.iValueType := vtString;
          TreeNode.pNode.iPos := P;

          P := P+Length(FieldValue)+2;
        end;

        '+', '-', '0'..'9' :
        begin
          ExtractTokenString(P, FieldValue);

          TreeNode := moJsonTree.NewNode(mpTreeNode);
          TreeNode.pNode.sName := '';
          TreeNode.pNode.sValue := FieldValue;
          TreeNode.pNode.iNodeType := ntArrayField;
          TreeNode.pNode.iValueType := vtNumber;
          TreeNode.pNode.iPos := P;

          P := P+Length(FieldValue);
        end;

        'a'..'z', 'A'..'Z' :
        begin
          ExtractTokenString(P, FieldValue);

          TreeNode := moJsonTree.NewNode(mpTreeNode);
          TreeNode.pNode.sName := '';
          TreeNode.pNode.sValue := FieldValue;
          TreeNode.pNode.iNodeType := ntArrayField;
          TreeNode.pNode.iValueType := vtID;
          TreeNode.pNode.iPos := P;

          P := P+Length(FieldValue);
        end;
      end;

      SkipWS(P);
      if P > miJsonStrLen then
        EXIT;

      if mpJsonStr^[P] = ']' then
        break
      else if mpJsonStr^[P] <> ',' then
         EXIT;

      Inc(Cnt);
      Inc(P);
    end;

    if mpJsonStr^[P] <> ']' then
      EXIT;
  finally
    UnstackNode();
  end;

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

  mpTreeNode := nil;

  P := 1;
  Result := ParseBraceBlock(P);
end;

function TSTJsonParser.ParseSingleField(var P: Integer): Integer;
var
  SP, L : Integer;
  FieldName,
  FieldValue : AnsiString;
  NodeType : TSTJsonNodeType;
  ValueType : TSTJsonValueType;
  TreeNode : PSTJsonTreeNodeInfo;
begin
  Result := -1;
  if SkipWS(P) < 0 then
    EXIT;

  NodeType := ntNone;
  if mpTreeNode = nil then
  else if mpTreeNode.pNode.iNodeType = ntObject then
    NodeType := ntObjectField
  else if mpTreeNode.pNode.iNodeType = ntArray then
    NodeType := ntArrayField;

  TreeNode := moJsonTree.NewNode(mpTreeNode);
  TreeNode.pNode.iNodeType := NodeType;
  StackNode(TreeNode);
  try
    SP := P;
    if mpJsonStr^[P] = '"' then
    begin
      if ExtractQuoteString(P, FieldName) < 0 then
        EXIT;

      P := P + Length(FieldName)+2;
    end
    else
    begin
      if ExtractTokenStringTP(P, FieldName, ValueType) < 0 then
        EXIT;

      P := P + Length(FieldName);
    end;

    TreeNode.pNode.sName := FieldName;
    if SkipWS(P) < 0 then
      EXIT;

    if mpJsonStr^[P] <> ':' then
      EXIT;

    Inc(P);
    if SkipWS(P) < 0 then
      EXIT;

    case mpJsonStr^[P] of
      '[' :
      begin
        TreeNode.pNode.sValue := '[';
        TreeNode.pNode.iValueType := vtArray;

        if ParseBracketBlock(P) < 0 then
          EXIT;
      end;

      '{' :
      begin
        TreeNode.pNode.sValue := '{';
        TreeNode.pNode.iValueType := vtObject;

        if ParseBraceBlock(P) < 0 then
          EXIT;
      end;

      '"' :
      begin
        if ExtractQuoteString(P, FieldValue) < 0 then
          EXIT;

        P := P + Length(FieldValue)+2;
        TreeNode.pNode.sValue := FieldValue;
        TreeNode.pNode.iValueType := vtString;
      end;

      else
      begin
        if ExtractTokenStringTP(P, FieldValue, ValueType) < 0 then
          EXIT;

        P := P + Length(FieldValue);
        TreeNode.pNode.sValue := FieldValue;
        TreeNode.pNode.iValueType := ValueType;
      end;
    end;
  finally
    UnstackNode();
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

function TSTJsonParser.StackNode(NewNode: PSTJsonTreeNodeInfo): Integer;
begin
  Result := -1;
  if miNodeStackCount >= high(mpaNodeStack) then
    EXIT;

  mpaNodeStack[miNodeStackCount] := NewNode;
  Inc(miNodeStackCount);
  mpTreeNode := NewNode;
end;

function TSTJsonParser.UnstackNode: PSTJsonTreeNodeInfo;
begin
  Result := nil;
  try
    if miNodeStackCount <= 0 then
      EXIT;

    Result := mpaNodeStack[miNodeStackCount];
    Dec(miNodeStackCount);
  finally
    mpTreeNode := Result;
  end;
end;

end.


