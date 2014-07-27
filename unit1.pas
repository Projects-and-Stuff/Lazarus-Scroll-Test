// Proof-of-Concept attempt at using a Memo or RichMemo to scroll arbitrarily-sized
// data from both small and large (over 1 million) query datasets

unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, SynEdit, RichMemo, Forms, Controls, Graphics,
  Dialogs, StdCtrls, ExtCtrls, VirtualDBScrollMemo, windows, types, sqlite3conn,
  sqldb, db;

type

  { TForm1 }

  TForm1 = class(TForm)
    btnSetMax: TButton;
    btnQuery: TButton;
    chkInitial: TCheckBox;
    DataSource1: TDataSource;
    Label2: TLabel;
    lblCurrentChunk: TLabel;
    txtNumber: TEdit;
    SQLite3Connection1: TSQLite3Connection;
    SQLQuery1: TSQLQuery;
    SQLTransaction1: TSQLTransaction;
    txtSetMax: TEdit;
    Label1: TLabel;
    lblScrollPos: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    lblScrollMax: TLabel;
    lblMemoLineViaScrollBar: TLabel;
    Label7: TLabel;
    lblCaretPosLine: TLabel;
    RichMemo1: TRichMemo;
    ScrollBar1: TScrollBar;
    VirtualDBScrollMemo1: TVirtualDBScrollMemo;
    procedure btnQueryClick(Sender: TObject);
    procedure btnSetMaxClick(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure RichMemo1Change(Sender: TObject);
    procedure RichMemo1KeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure ScrollBar1Scroll(Sender: TObject; ScrollCode: TScrollCode;
      var ScrollPos: Integer);
    procedure MoveToLine(LineNo : Integer);
    function GetVisibleLineCount(Memo: TRichMemo): Integer;
  private
    { private declarations }
    FSearching: Boolean;               // Are we currently conducting a search?
    FRecCount : Integer;               // Total number of records in our query
    FChunksCount : Integer;      // Count of the number of chunks resulting from the current query
    FChunkLineCounts : Array of Integer;
    FCurrentChunk : Integer;              // Tracks which chunk is currently at the center of display
    FPageSize : Integer;                 // How many lines are visible
    function performQuery(queryCenterChunk : Integer; resetQuery : Boolean): Boolean;

  public
    { public declarations }
  const
    FChunkSize : Integer = 10;            // Number of records per chunk
  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

{ TForm1 }

procedure TForm1.ScrollBar1Scroll(Sender: TObject; ScrollCode: TScrollCode;
  var ScrollPos: Integer);
var
  smallStep : Integer;
  stepsPerLine : Integer;
  linesCurrentChunkSet : Integer;

  FTempCurrentChunk : Integer;
  scrollingDone : Boolean;
begin

  scrollingDone := False;

  // linesCurrentChunkSet := FChunkLineCounts[FCurrentChunk-1] + FChunkLineCounts[FCurrentChunk] + FChunkLineCounts[FCurrentChunk+1];

  // smallstep is how many positions we move on the scrollbar for each arrow press on the scrollbar
  // smallStep := (ScrollBar1.Max div RichMemo1.Lines.Count);
  // affected by the current chunk nymber and number of lines
  smallStep := (ScrollBar1.Max div FChunksCount) div RichMemo1.Lines.Count;

  // if we have 600 records we have 10 chunks and 600,000 positions on scrollbar1
  // if we're in chunk 3 for instance (visible chunks 2-4):
  // scrollbar positions are 6,000 through 18,000
  // correlate with lines 0 through linesCurrentChunkSet


  // stepsPerLine is how many positions on the scrollbar moves the caret one line hown in the richmemo
  stepsPerLine := (ScrollBar1.Max) div (FChunksCount * RichMemo1.Lines.Count);


  case ScrollCode of
    scLineUp : ScrollPos := ScrollPos - (smallStep - 1);
    scLineDown : ScrollPos := ScrollPos + smallStep - 1;
    scPageUp : ScrollPos := ScrollPos - (smallStep * FPageSize);
    scPageDown : ScrollPos := ScrollPos + (smallStep * FPageSize);
    scEndScroll : scrollingDone := True;
    scBottom : scrollingDone := True;
    scTop : scrollingDone := True;
  end;


  // Calculate the current chunk based upon current scrollbar position
  FTempCurrentChunk := (((Scrollbar1.Position div 1000) div FChunkSize) + 1);

  if scrollingDone then
  begin
    // We only update the richmemo contents if we've moved to a new chunk
    if (FTempCurrentChunk > FCurrentChunk) and (FTempCurrentChunk < FChunksCount - 1) then
    begin
      ///ShowMessage('FTempCurrentChunk ' + IntToStr(FTempCurrentChunk) + ' > FCurrentChunk ' + IntToStr(FCurrentChunk));

      FCurrentChunk := FTempCurrentChunk;
      performQuery(FCurrentChunk, False);

      // Move the caret to the start of new middle chunk
      // By taking the count of the chunk above it
      MoveToLine(FChunkLineCounts[FCurrentChunk-1]);


    end
    else if (FTempCurrentChunk < FCurrentChunk) and (FTempCurrentChunk < FChunksCount - 1) then
    begin
      ///ShowMessage('FTempCurrentChunk ' + IntToStr(FTempCurrentChunk) + ' < FCurrentChunk ' + IntToStr(FCurrentChunk));

      FCurrentChunk := FTempCurrentChunk;
      performQuery(FCurrentChunk, False);

      // Move the caret to the end of new middle chunk
      // By taking the line counts of the current chunk and the one above it
      MoveToLine(FChunkLineCounts[FCurrentChunk-1] + FChunkLineCounts[FCurrentChunk]);


    end
    else
    begin
      // Move the caret
      //MoveToLine(ScrollBar1.Position div ((ScrollBar1.Max div FChunksCount) div RichMemo1.Lines.Count));
    end;
  end;

  // Move the caret
  //MoveToLine(ScrollBar1.Position div ((ScrollBar1.Max div FChunksCount) div RichMemo1.Lines.Count));

  // if we have 600 records we have 10 chunks and 600,000 positions on scrollbar1
  // if we're in chunk 3 for instance (visible chunks 2-4):
  // scrollbar positions are 6,000 through 18,000
  // correlate with lines 0 through linesCurrentChunkSet

  // if we're at position 9200, we're about half-way through chunk 3



  lblCurrentChunk.Caption := IntToStr(FCurrentChunk);
  lblScrollPos.Caption := IntToStr(ScrollPos);

  // The following two lines should result in the same number
  lblMemoLineViaScrollBar.Caption := IntToStr(ScrollBar1.Position div RichMemo1.Lines.Count);
  lblCaretPosLine.Caption := IntToStr(RichMemo1.CaretPos.y);
end;

procedure TForm1.MoveToLine(LineNo: Integer);
begin
  RichMemo1.CaretPos := Point(0, LineNo);
  RichMemo1.SetFocus;
end;

procedure TForm1.FormShow(Sender: TObject);
begin
  lblScrollMax.Caption := IntToStr(ScrollBar1.Max);

  // Approximates how many lines are in the visible memo area
  FPageSize := GetVisibleLineCount(RichMemo1);
end;

procedure TForm1.RichMemo1Change(Sender: TObject);
begin
  FSearching := False;
end;

procedure TForm1.RichMemo1KeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
var
  linePercentage : Integer;
begin
  lblCaretPosLine.Caption:=IntToStr(RichMemo1.CaretPos.y);

  // Need to update this. Currently it's based upon a constant line count
  //ScrollBar1.Position := RichMemo1.CaretPos.y * RichMemo1.Lines.Count;


  // This is percentage of the way through the Richmemo we're currently:
  linePercentage := ((RichMemo1.CaretPos.y * 100) div RichMemo1.Lines.Count);

  {
  We can then use that to calculate where the scrollbar should be

  half-way through chunk 2
  (line_percentage + (FCurrentChunk*100) - 100) * (FChunkSize * 10) = position 90000

  30% through chunk 3
  (line_percentage + (FCurrentChunk*100) - 100) * (FChunkSize * 10) = position 138,000

  50% through chunk 3
  (line_percentage + (FCurrentChunk*100) - 100) * (FChunkSize * 10) = position 150,000

  half-way through chunk 4
  (line_percentage + (FCurrentChunk*100) - 100) * (FChunkSize * 10) = position 210,000
  }

  ScrollBar1.Position := (linePercentage + (FCurrentChunk * 100) - 100) * FChunkSize * 10;
  //ShowMessage(IntToStr((linePercentage + (FCurrentChunk * 100) - 100) * FChunkSize * 10));

  lblMemoLineViaScrollBar.Caption := IntToStr(ScrollBar1.Position div RichMemo1.Lines.Count);
  lblScrollPos.Caption := IntToStr(ScrollBar1.Position);
end;

procedure TForm1.FormResize(Sender: TObject);
begin
  // Approximates how many lines are in the visible memo area
  FPageSize := GetVisibleLineCount(RichMemo1);
end;

function TForm1.performQuery(queryCenterChunk : Integer; resetQuery : Boolean): Boolean;
var
  i, currLines : Integer;
  queryCurrentChunk : Integer;
begin

  SQLite3Connection1.Close;
  SQLite3Connection1.DatabaseName := './DB/DBTest.db3';


  SQLite3Connection1.Open;
  SQLTransaction1.Active := True;

  RichMemo1.Lines.BeginUpdate;
  //RichMemo1.Visible := False;
  RichMemo1.Lines.Clear;
  //ScrollBar1.Visible := False;

  if resetQuery = True then
  begin
    with SQLQuery1 do
    begin
      Close;
      SQL.Text := 'Select * FROM Entries';
      Prepare;

      Open;

      // Need to call Last in order to get accurate total record count
      Last;
      FRecCount := RecordCount;

      ScrollBar1.Max := FRecCount * 1000;
      lblScrollMax.Caption := IntToStr(ScrollBar1.Max);
      //SetLength(FLineCounts, FRecCount);

      // Count the number of chunks
      if FRecCount mod FChunkSize = 0 then
      begin
        FChunksCount := FRecCount div FChunkSize;
        SetLength(FChunkLineCounts, FRecCount div FChunkSize);
      end
      else
      begin
        FChunksCount := (FRecCount div FChunkSize) + 1;
        SetLength(FChunkLineCounts, (FRecCount div FChunkSize) + 1);
      end;

      First;
      //UniDirectional := True;

      // Pull the first 3 chunks
      for i := 1 to 3 do
      begin
        queryCurrentChunk := i;
        currLines := RichMemo1.Lines.Count;

        if (((queryCurrentChunk - 1) * FChunkSize) + 1) < FRecCount then // Make sure we're not outside the range of records in this query
        begin
          RecNo := ((queryCurrentChunk - 1) * FChunkSize) + 1;   // If set 1, then we're at RecNo 1


          while (RecNo < (((queryCurrentChunk) * FChunkSize) + 1)) AND (RecNo < FRecCount) do
          begin

            RichMemo1.Lines.Append('Entry ID: ' + FieldByName('id').AsString + ' - Name: ' + FieldByName('Name').AsString);
            RichMemo1.Lines.Append('Entry: ' + FieldByName('Entry').AsString);
            RichMemo1.Lines.Append('');
            //ShowMessage(IntToStr(RecNo));
            //FLineCounts[RecNo-1] := RichMemo1.Lines.Count - currLines;

            Next;
          end;
          performQuery := True;
        end
        else
        begin
          ShowMessage('Beyond query range');
          performQuery := False;
        end;

        FChunkLineCounts[i] := RichMemo1.Lines.Count - currLines;
      end;

    end;

    // Display the line counts for the current 3 chunks
    //ShowMessage(IntToStr(FChunkLineCounts[1]) + ' ' + IntToStr(FChunkLineCounts[2]) + ' ' + IntToStr(FChunkLineCounts[3]));


  end
  else
  begin // The query has already been set. Now we're just scrolling


    with SQLQuery1 do
    begin
      Close;
      SQL.Text := 'Select * FROM Entries';
      Prepare;

      Open;

      // We skip the whole 'Last' part here because we already counted the records on the initial query

      // Pull the first 3 chunks
      for i := (queryCenterChunk - 1) to (queryCenterChunk + 1) do
      begin
        queryCurrentChunk := i;
        currLines := RichMemo1.Lines.Count;

        if (((queryCurrentChunk - 1) * FChunkSize) + 1) < FRecCount then // Make sure we're not outside the range of records in this query
        begin
          RecNo := ((queryCurrentChunk - 1) * FChunkSize) + 1;   // If set 1, then we're at RecNo 1


          while (RecNo < (((queryCurrentChunk) * FChunkSize) + 1)) AND (RecNo < FRecCount) do
          begin

            RichMemo1.Lines.Append('Entry ID: ' + FieldByName('id').AsString + #9#9 + ' Name: ' + FieldByName('Name').AsString);
            RichMemo1.Lines.Append('Entry: ' + FieldByName('Entry').AsString);
            RichMemo1.Lines.Append('');
            //ShowMessage(IntToStr(RecNo));
            //FLineCounts[RecNo-1] := RichMemo1.Lines.Count - currLines;

            Next;
          end;
          performQuery := True;
        end
        else
        begin
          ShowMessage('Beyond query range');
          performQuery := False;
        end;

        FChunkLineCounts[i] := RichMemo1.Lines.Count - currLines;
      end;

    end;

    // Display the line counts for the current 3 chunks
    // ShowMessage(IntToStr(FChunkLineCounts[queryCenterChunk-1]) + ' ' + IntToStr(FChunkLineCounts[queryCenterChunk]) + ' ' + IntToStr(FChunkLineCounts[queryCenterChunk+1]));


  end;



  //RichMemo1.Visible := True;
  RichMemo1.Lines.EndUpdate;
  //ScrollBar1.Visible := True;


  SQLTransaction1.Commit;
  SQLTransaction1.StartTransaction;
  SQLTransaction1.Active := False;
  SQLite3Connection1.Connected := False;
  SQLite3Connection1.Close;


  RichMemo1.Repaint;
  RichMemo1.SetFocus;
  //MoveToLine(1);


end;

procedure TForm1.btnQueryClick(Sender: TObject);
var
  dontCare : Integer;
begin
  if chkInitial.Checked then
  begin
    performQuery(StrToInt(txtNumber.Text), True);
  end
  else
  begin
    performQuery(StrToInt(txtNumber.Text), False);
  end;

  ScrollBar1Scroll(nil, scTop, dontCare);

  chkInitial.Checked := False;


end;

function TForm1.GetVisibleLineCount(Memo: TRichMemo): Integer;
var
  OldFont : HFont;
  Hand : THandle;
  TM : TTextMetric;
  tempint : integer;
begin
  Hand := GetDC(Memo.Handle);
  try
    OldFont := SelectObject(Hand, Memo.Font.Handle);
    try
      GetTextMetrics(Hand, TM);
      tempint:=Memo.Height div TM.tmHeight;
    finally
      SelectObject(Hand, OldFont);
    end;
  finally
    ReleaseDC(Memo.Handle, Hand);
  end;
  Result := tempint;
end;


end.

