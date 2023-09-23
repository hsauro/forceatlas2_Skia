unit uGraph;

interface

Uses Classes, SysUtils, Generics.Collections, System.Types;


const
   DEFAULT_WIDTH = 32;
   DEFAULT_HEIGHT = 32;

type
  TNode = class
     name : string;
     id : integer;
     x, y : double;
     w, h : double;
     dx, dy : double;
     mass : double;
     old_dx : double;
     old_dy : double;

     function isInNode (px, py : single) : boolean;
     constructor Create;
     destructor Destroy; override;
  end;

  TNodes = class (TObjectList<TNode>)
  end;


  TEdge = class
     name : string;
     src, dest : TNode;
     weight : double;

     constructor Create;
     destructor Destroy; override;
  end;

  TEdges = TObjectList<TEdge>;

  TGraph = class
    nodes : TNodes;
    edges : TEdges;

    procedure clear;
    function  addNode (x, y : single) : integer; overload;
    procedure addEdge (v, u : TNode);
    procedure moveNode (index : integer; dx, dy : single);
    function  findNode (name : string) : TNode;
    procedure center (w, h : single);
    function  ptInNode (px, py : single; var index : integer) : boolean;

    constructor Create;
  end;

implementation

constructor TGraph.Create;
begin
  nodes := TNodes.Create;
  edges := TEdges.Create;
end;


procedure TGraph.clear;
begin
  edges.Clear;
  nodes.Clear;
end;

// -------------------------------------------------------------------------


constructor TEdge.Create;
begin
  weight := 1;
end;


destructor TEdge.Destroy;
begin
  inherited;
end;


// --------------------------------------------------------------



constructor TNode.Create;
begin
  mass := 1.0;
  old_dx := 0.0;
  old_dy := 0.0;
  dx := 0.0;
  dy := 0.0;
  x := 0.0;
  y := 0.0;
end;


destructor TNode.Destroy;
begin
  inherited;
end;


function TNode.isInNode (px, py : single) : boolean;
begin
  if TPoint.PointInCircle(Point(trunc (px), trunc (py)), Point (trunc (x + w/2), trunc (y + h/2)), DEFAULT_WIDTH) then
     exit (True)
  else
     exit (False);
end;


function TGraph.addNode (x, y : single) : integer;
var index : integer;
begin
  index :=  nodes.Add (TNode.Create);
  nodes[index].id := index;
  nodes[index].x := x;
  nodes[index].y := y;
  nodes[index].w := DEFAULT_WIDTH;
  nodes[index].h := DEFAULT_HEIGHT;
  nodes[index].name := 'N' + inttostr (index);
  result := index;
end;


procedure TGraph.addEdge (v, u : TNode);
var edge : TEdge;
    index : integer;
begin
  if (v = nil) or (u = nil) then
     raise Exception.Create('Node cannot be nil in addEdge');

  edge := TEdge.Create;
  edge.src := v;
  edge.dest := u;
  index := edges.Add (edge);
  edge.name := 'E' + inttostr (index);
end;


procedure TGraph.center (w, h : single);
var i : integer;
    sumx, sumy, cx, cy, dx, dy : double;
begin
  // Find the centroid of the graph
  sumx := 0; sumy := 0;
  for i := 0 to nodes.Count - 1 do
      begin
      sumx := sumx + nodes[i].x;
      sumy := sumy + nodes[i].y;
      end;
  cx := sumx/nodes.Count;
  cy := sumy/nodes.Count;

  // Fnd how much we havw to translate each node so that
  // the centroid is in the middle of the screen.
  dx := cx - w/2;
  dy := cy - h/2;

  for i := 0 to nodes.Count - 1 do
      begin
      nodes[i].x := nodes[i].x - dx;
      nodes[i].y := nodes[i].y - dy;
      end;
end;


procedure TGraph.moveNode (index : integer; dx, dy : single);
begin
  nodes[index].x := nodes[index].x + dx;
  nodes[index].y := nodes[index].y + dy;
end;


function TGraph.findNode (name : string) : TNode;
var i : integer;
begin
  for i := 0 to nodes.Count - 1 do
      if nodes[i].name = name then
         exit (nodes[i]);
  exit (nil);
end;


function TGraph.ptInNode (px, py : single; var index : integer) : boolean;
var i : integer;
begin
  for i := 0 to nodes.Count - 1 do
      if nodes[i].isInNode(px, py) then
         begin
         index := i;
         exit (True);
         end;
  exit (False);
end;




end.

