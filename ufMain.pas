unit ufMain;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  System.Math.Vectors, Skia, FMX.Controls.Presentation, FMX.StdCtrls,
  Skia.FMX, FMX.Controls3D, FMX.Layers3D, FMX.Layouts,
  uGraph, FMX.Edit, FMX.EditBox, FMX.NumberBox,
  uPyLayout, FMX.Menus;

type
  TAction = (atSelect);

  TfrmMain = class(TForm)
    Layout1: TLayout;
    Layout3D1: TLayout3D;
    SkPaintBox: TSkPaintBox;
    btnRandomnetwork: TButton;
    Label1: TLabel;
    Label2: TLabel;
    nbNumNodes: TNumberBox;
    nbNumEdges: TNumberBox;
    btnClear: TButton;
    btnSelect: TButton;
    btnCenterGraph: TButton;
    Timer1: TTimer;
    btnLayout: TButton;
    procedure btnClearClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure btnRandomnetworkClick(Sender: TObject);
    procedure btnSelectClick(Sender: TObject);
    procedure btnCenterGraphClick(Sender: TObject);
    procedure btnLayoutClick(Sender: TObject);
    procedure mnuNewClick(Sender: TObject);
    procedure SkPaintBoxDraw(ASender: TObject; const ACanvas: ISkCanvas; const
        ADest: TRectF; const AOpacity: Single);
    procedure SkPaintBoxMouseDown(Sender: TObject; Button: TMouseButton; Shift:
        TShiftState; X, Y: Single);
    procedure SkPaintBoxMouseMove(Sender: TObject; Shift: TShiftState; X, Y:
        Single);
    procedure SkPaintBoxMouseUp(Sender: TObject; Button: TMouseButton; Shift:
        TShiftState; X, Y: Single);
    procedure Timer1Timer(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
    graph : TGraph;
    LPaint : ISkPaint;
    selected : boolean;
    currentNode : integer;
    action: TAction;
    sx, sy : single;
    srcPt, destPt : integer;

    pausingTimer : boolean;

    font : ISkFont;
    typeface : ISkTypeface;

    // Layout engine
    atlas : TForceAtlas2;

    procedure draw (ACanvas : ISkCanvas);
    procedure writeTextId (ACanvas : ISkCanvas; x, y, w, h : single; atext : string);
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.fmx}

Uses Math, StrUtils;


procedure TfrmMain.btnClearClick(Sender: TObject);
begin
  Timer1.Enabled := False;
  graph.clear;
  SkPaintBox.Redraw;
end;


procedure TfrmMain.FormCreate(Sender: TObject);
var fontSize : single;
begin
   selected := False;
   LPaint := TSkPaint.Create;
   LPaint.AntiAlias := True;
   graph := TGraph.Create;

   srcPt := -1; destPt := -1;
   pausingTimer := False;

   atlas := TForceAtlas2.Create;
   font := TSkFont.Create;
   fontSize := 12;
   typeface := TSkTypeface.MakeFromName('Arial', TSkFontStyle.Normal);
   font := TSkFont.Create(typeface, fontSize, 1);
   font.Hinting := TSkFontHinting.Full;
end;


procedure TfrmMain.btnRandomnetworkClick(Sender: TObject);
var i, j : integer;
    nNodes, nEdges: integer;
    src, dest : integer;
begin
  Timer1.Enabled := False;
  graph.clear;

  nNodes := trunc (nbNumNodes.Value);
  nEdges := trunc (nbNumEdges.Value);
  for i := 0 to nNodes - 1 do
      graph.addNode (RandomRange(50, 350), RandomRange (50, 350));

  for i := 0 to nEdges - 1 do
      begin
      src := Random(nNodes);
      dest := Random (nNodes);
      if dest <> src then
         graph.addEdge (graph.nodes[src], graph.nodes[dest]);
      end;
  graph.center(SkPaintBox.Width, SkPaintBox.Height);
  SkPaintBox.redraw;
end;


procedure TfrmMain.btnSelectClick(Sender: TObject);
begin
  Timer1.Enabled := False;
  action := atSelect;
  skpaintbox.Cursor := crDefault;
end;


procedure TfrmMain.btnCenterGraphClick(Sender: TObject);
begin
  Timer1.Enabled := False;
  graph.center(SkPaintBox.Width, SkPaintBox.Height);
  SkPaintBox.Redraw;
end;


procedure TfrmMain.btnLayoutClick(Sender: TObject);
begin
  atlas.setupCompute (graph);
  Timer1.Enabled := not Timer1.Enabled;
end;


procedure TfrmMain.mnuNewClick(Sender: TObject);
begin
  graph.clear;
end;


procedure TfrmMain.SkPaintBoxDraw(ASender: TObject; const ACanvas: ISkCanvas;
    const ADest: TRectF; const AOpacity: Single);
begin
   ACanvas.Save;
   try
     LPaint.Style :=  TSkPaintStyle.Fill;
     LPaint.Color := TAlphaColors.White;
     ACanvas.DrawRect (ADest, LPaint);

     draw (ACanvas);

   finally
     ACanvas.Restore;
   end;
end;


procedure TfrmMain.writeTextId (ACanvas : ISkCanvas; x, y, w, h : single; atext : string);
var LBlob: ISkTextBlob;
    LPaint : ISkPaint;
    ABounds : TRectF;
    tx, ty : single;
begin
  LPaint := TSkPaint.Create;
  LPaint.Color := TAlphaColors.Black;
  LPaint.Style := TSkPaintStyle.Fill;
  LPaint.AntiAlias := True;

  font.MeasureText(atext, ABounds, LPaint);

  tx := (x) + (w/2 - ABounds.Width/2);
  ty := (y) + (h/2 + ABounds.Height/2);

  LBlob := TSkTextBlob.MakeFromText(atext, font);
  ACanvas.DrawTextBlob(LBlob, tx, ty, LPaint);
end;


procedure TfrmMain.draw (ACanvas : ISkCanvas);
var srcx, srcy, destx, desty : single;
    cx, cy : single;
    tx, ty : single;
    i : integer;
    astr : string;
begin
   if graph = nil then
     exit;

  LPaint.Color := TAlphaColors.Blue;
  LPaint.StrokeWidth := 1;
  for i := 0 to graph.edges.count - 1 do
      begin
      srcx := graph.edges[i].src.x + graph.edges[i].src.w / 2;
      srcy := graph.edges[i].src.y + graph.edges[i].src.h / 2;

      destx := graph.edges[i].dest.x + graph.edges[i].src.w / 2;
      desty := graph.edges[i].dest.y + graph.edges[i].src.h / 2;

      ACanvas.DrawLine(srcx, srcy, destx, desty, LPaint);
      end;

 for i := 0 to graph.nodes.Count - 1 do
      begin
      cx := graph.nodes[i].x + graph.nodes[i].w / 2;
      cy := graph.nodes[i].y + graph.nodes[i].h / 2;

      // Draw node fill
      LPaint.Color := TAlphaColors.Lightblue;
      LPaint.Style := TSkPaintStyle.Fill;
      ACanvas.DrawCircle (cx, cy, graph.nodes[i].h / 2, LPaint);

      // Draw node border
      LPaint.Style := TSkPaintStyle.Stroke;
      LPaint.Color := TAlphaColors.blue;
      LPaint.StrokeWidth := 1.5;
      ACanvas.DrawCircle (cx, cy, graph.nodes[i].h / 2, LPaint);

      // Draw text in node
      LPaint.Color := TAlphaColors.black;
      astr := inttostr (i);
      writeTextId(ACanvas, graph.nodes[i].x, graph.nodes[i].y, graph.nodes[i].w, graph.nodes[i].h, astr);
      end;
end;


procedure TfrmMain.SkPaintBoxMouseDown(Sender: TObject; Button: TMouseButton;
    Shift: TShiftState; X, Y: Single);
var i, index : integer;
begin
  sx := x; sy := y;

  if timer1.Enabled then
     begin
     pausingTimer := True;
     timer1.Enabled  := False;
     end;

  case action of

   atSelect:
      begin
     selected := False;
     if graph.ptInNode (x, y, index) then
        begin
        currentNode := index;
        selected := True;
        exit;
        end;
      end;
   end;
  SkPaintBox.Redraw;
end;


procedure TfrmMain.SkPaintBoxMouseMove(Sender: TObject; Shift: TShiftState; X,  Y: Single);
var dx, dy : single;
    index: integer;
begin
  dx := x - sx;
  dy := y - sy;
  case action of
     atSelect :
        begin
        if selected then
           graph.moveNode(currentNode, dx, dy);
        end;
  end;
  sx := x; sy := y;
  SkPaintBox.Redraw;
end;


procedure TfrmMain.SkPaintBoxMouseUp(Sender: TObject; Button: TMouseButton;
    Shift: TShiftState; X, Y: Single);
begin
  selected := False;
  if pausingTimer then
     begin
     pausingTimer := False;
     Timer1.Enabled := True;
     end;
end;


// Wehn layout is active this is called to compute the next positions for the nodes
procedure TfrmMain.Timer1Timer(Sender: TObject);
begin
  atlas.doOneIteration (graph);
  SkPaintBox.Redraw;
end;


end.
