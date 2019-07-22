unit uTestSTJson01;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, uSTJson, ExtCtrls;

type
  TForm1 = class(TForm)
    Button1: TButton;
    Memo1: TMemo;
    procedure Button1Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

procedure TForm1.Button1Click(Sender: TObject);
const
(*  JD : AnsiString = '{' +
    ' "EventType":"STT", ' +
    ' "Event":"interim", ' +
    ' "rec_id":"000000001", ' +
    ' "minutes_id":"SITEID_ROOMID_YYYYMMDDHH24miSS", ' +
    ' "mic_ser":"001", ' +
    ' "sntnc_no":"00000001", ' +
    ' "Start":"YYYYMMDDHH24miSS", ' +
    ' "End":"YYYYMMDDHH24miSS", ' +
    ' "Text":"우리나라 대한민국" ' +
    '}'; *)

  JD : AnsiString =
'{ ' +
'    "employee": ' +
'   [ { ' +
'    " id " : 1, ' +
'    "name" : "Jay", ' +
'    "age" : 27 ' +
'  }, ' +
'  { ' +
'     " id " : 2, ' +
'     "name" : "MJ", ' +
'     "age" : 25 ' +
'  } ' +
'  ] ' +
'} ';

var
  i : Integer;
  JP : TSTJsonParser;
begin
  JP := TSTJsonParser.Create;
  JP.ParseP(@JD);

  for i := 0 to JP.NodeList.Count-1 do
    Memo1.Lines.Add(JP.NodeList.Nodes[i].sName);

  JP.Destroy;
end;

end.
