unit uPyLayout;


{
 This Object Pascal code is licensed under the Common
 Development and Distribution License("CDDL")
 Dated September, 2023

 The Object Pascal version was derived from the Java
 code by Mathieu Jacomy and Python code
 derived by Bhargav Chippada.

 This is the original Java license text:

 Copyright 2008-2011 Gephi
 Authors : Mathieu Jacomy <mathieu.jacomy@gmail.com>
 Website : http://www.gephi.org

 This file [The Java Code] is part of Gephi.

 DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS HEADER.

 Copyright 2011 Gephi Consortium. All rights reserved.

 The contents of this file are subject to the terms of either the GNU
 General Public License Version 3 only ("GPL") or the Common
 Development and Distribution License("CDDL") (collectively, the
 "License"). You may not use this file except in compliance with the
 License. You can obtain a copy of the License at
 http://gephi.org/about/legal/license-notice/
 or /cddl-1.0.txt and /gpl-3.0.txt. See the License for the
 specific language governing permissions and limitations under the
 License.  When distributing the software, include this License Header
 Notice in each file and include the License files at
 /cddl-1.0.txt and /gpl-3.0.txt. If applicable, add the following below the
 License Header, with the fields enclosed by brackets [] replaced by
 your own identifying information:

 Herbert M Sauro elects to include this software in this distribution
 under the CDDL license.

 If you wish your version of this file to be governed by only the CDDL
 or only the GPL Version 3, indicate your decision by adding
 "[Contributor] elects to include this software in this distribution
 under the [CDDL or GPL Version 3] license." If you do not indicate a
 single choice of license, a recipient has the option to distribute
 your version of this file under either the CDDL, the GPL Version 3 or
 to extend the choice of license to its licensees as provided above.
 However, if you add GPL Version 3 code and therefore, elected the GPL
 Version 3 license, then the option applies only if the new code is
 made subject to such option by the copyright holder.

 Contributor(s):

 Herbert M Sauro

 The Object Pascal version was derived from the original Java version
 and the Python version created by:

 Java: Mathieu Jacomy <mathieu.jacomy@gmail.com>

 Python: Bhargav Chippada bhargavchippada19@gmail.com.
 https://github.com/bhargavchippada/forceatlas2

 Portions Copyrighted 2011 Gephi Consortium.

 The above text may not be changed.
 }


interface

Uses Classes, SysUtils, System.Generics.Collections, uPyUtils, uGraph;

type
  TIntRows = array of integer;
  TPyGraph = class (TObject)
      matrix : array of TIntRows;

      function getnRows : integer;
      function getnCols : integer;
      constructor Create (nRows, nCols : integer);
  end;

  TDoubleRows = array of double;

  TForceAtlas2 = class (TObject)
      // Behavior alternatives
      outboundAttractionDistribution : boolean;  // Dissuade hubs
      outboundAttCompensation : double;
      linLogMode : boolean;  // NOT IMPLEMENTED
      adjustSizes : boolean;  // Prevent overlap (NOT IMPLEMENTED)
      edgeWeightInfluence : double;

      // Performance
      jitterTolerance : double;  // Tolerance
      barnesHutOptimize : boolean;
      barnesHutTheta : double;
      multiThreaded : boolean;  // NOT IMPLEMENTED

      // Tuning
      scalingRatio : double;
      strongGravityMode : boolean;
      gravity : double;

      pause : boolean;

      speed : double;
      speedEfficiency : double;

      // Log
      verbose : boolean;

      constructor Create;
      function    getNumNonZeros (x : TIntRows) : integer;
      procedure   initialize (network : TGraph);

      procedure   setupCompute (network : TGraph);
      procedure   doOneIteration (network : TGraph);
  end;


implementation

constructor TPyGraph.Create (nRows, nCols : integer);
var i :  integer;
begin
  setLength (matrix, nRows);
  for i := 0 to nRows - 1 do
      setLength (matrix[i], nCols);
end;


function TPyGraph.getnRows : integer;
begin
  result := length (matrix);
end;

function TPyGraph.getnCols : integer;
begin
  result := length (matrix[0]);
end;


// --------------------------------------------------------------------------

constructor TForceAtlas2.Create;
begin
   speed := 1;
   speedEfficiency := 1;

   // Behavior alternatives
   outboundAttractionDistribution := False;  // Dissuade hubs
   linLogMode := False;  // NOT IMPLEMENTED
   adjustSizes := False;  // Prevent overlap (NOT IMPLEMENTED)
   edgeWeightInfluence := 1.0;

   // Performance
   jitterTolerance := 10.0;  // Tolerance
   barnesHutOptimize := False;
   barnesHutTheta := 1.2;
   multiThreaded := False;  // NOT IMPLEMENTED

   // Tuning
   scalingRatio := 200;
   strongGravityMode := False;
   gravity := 0;

   pause := False;

   // Log
   verbose := True;
end;


function nonzeroT (G : TPyGraph) : TPyGraph;
var i, j : integer;
    nNonZeros, count : integer;
begin
   nNonZeros := 0;
  // First count the number of non-zeros
  for i := 0 to G.getnRows() - 1 do
      begin
      for j := 0 to G.getnCols() - 1 do
          begin
          if G.matrix[i][j] <> 0 then
             inc (nNonZeros);
          end;
      end;
  result := TPyGraph.Create (nNonZeros, 2);
  count := 0;
  for i := 0 to G.getnRows() - 1 do
      begin
      for j := 0 to G.getnCols() - 1 do
          begin
          if G.matrix[i][j] <> 0 then
             begin
             result.matrix[count][0] := i;
             result.matrix[count][1] := j;
             inc (count);
             end;
          end;
      end;
end;


function TForceAtlas2.getNumNonZeros (x : TIntRows) : integer;
var i : integer;
begin
  result := 0;
  // First count the number of non-zeros
  for i := 0 to length (x) - 1 do
      begin
      if x[i] <> 0 then
         result := result + 1
      end;
end;


procedure TForceAtlas2.initialize (network : TGraph);  // a graph in 2D numpy ndarray format (or) scipy sparse matrix format
var n : TNode;
    edge : TEdge;
    i, j : integer;
    es : TPyGraph;
    n1, n2 : TNode;
    G : TPyGraph;
    adj1, adj2 : integer;
begin
  G := TPyGraph.Create (network.nodes.Count, network.nodes.Count);
  for i := 0 to network.edges.Count - 1  do
      begin
      n1 := network.edges[i].src;
      n2 := network.edges[i].dest;
      for j := 0 to network.nodes.Count - 1 do
          if n1 = network.nodes[j] then
             begin
             adj1 := j;
             break;
             end;
      for j := 0 to network.nodes.Count - 1 do
          if n2 = network.nodes[j] then
             begin
             adj2 := j;
             break;
             end;
      G.matrix[adj1][adj2] := 1;
      G.matrix[adj2][adj1] := 1;
      end;


  // Put nodes into a data structure we can understand
  i := 0;
  for n in network.nodes do
      begin
      n.old_dx := 0;
      n.old_dy := 0;
      n.dx := 0;
      n.dy := 0;
      n.mass := 1 + getNumNonZeros (G.matrix[i]);
      inc (i);
      end;
end;


// Given an adjacency matrix, this function computes the node positions
// according to the ForceAtlas2 layout algorithm.  It takes the same
// arguments that one would give to the ForceAtlas2 algorithm in Gephi.
// Not all of them are implemented.  See below for a description of
// each parameter and whether or not it has been implemented.
//
// This function will return a list of X-Y coordinate tuples, ordered
// in the same way as the rows/columns in the input matrix.
//
// The only reason you would want to run this directly is if you don't
// use networkx.  In this case, you'll likely need to convert the
// output to a more usable format.  If you do use networkx, use the
// "forceatlas2_networkx_layout" function below.
//
// Currently, only undirected graphs are supported so the adjacency matrix
// should be symmetric.


procedure TForceAtlas2.setupCompute (network : TGraph);
var sum : double;
begin
  speed := 1.0;
  speedEfficiency := 1.0;
  initialize (network);
  outboundAttCompensation := 1.0;

  if outboundAttractionDistribution then
     begin
     sum := 0;
     for var i : integer := 0 to network.nodes.Count - 1 do
         sum := sum + network.nodes[i].mass;
     outboundAttCompensation := sum/network.nodes.Count; //numpy.mean([n.mass for n in nodes])
     end;
end;


procedure TForceAtlas2.doOneIteration (network : TGraph);
begin
  for var i : integer := 0 to network.nodes.Count - 1 do
         begin
         network.nodes[i].old_dx := network.nodes[i].dx;
         network.nodes[i].old_dy := network.nodes[i].dy;
         network.nodes[i].dx := 0;
         network.nodes[i].dy := 0;
         end;

     // Charge repulsion forces
     apply_repulsion(network.nodes, scalingRatio);

     // Gravitational forces
     apply_gravity(network.nodes, gravity, scalingRatio, strongGravityMode);

     // If other forms of attraction were implemented they would be selected here.
     apply_attraction(network.nodes, network.edges, outboundAttractionDistribution, outboundAttCompensation,
                                         edgeWeightInfluence);

     // Adjust speeds and apply forces
     adjustSpeedAndApplyForces(network.nodes, speed, speedEfficiency, jitterTolerance, adjustSizes);
end;



end.
