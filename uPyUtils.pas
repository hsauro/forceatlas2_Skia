unit uPyUtils;

interface

Uses Classes, System.Generics.Collections, uGraph;

// This file allows separating the most CPU intensive routines from the
// main code.  This allows them to be optimized with Cython.  If you
// don't have Cython, this will run normally.  However, if you use
// Cython, you'll get speed boosts from 10-100x automatically.
//
// THE ONLY CATCH IS THAT IF YOU MODIFY THIS FILE, YOU MUST ALSO MODIFY
// fa2util.pxd TO REFLECT ANY CHANGES IN FUNCTION DEFINITIONS!
//
// Copyright (C) 2017 Bhargav Chippada <bhargavchippada19@gmail.com>
//
// Available under the GPLv3


  procedure apply_gravity(nodes : TNodes; gravity, scalingRatio : double; useStrongGravity : boolean);
  procedure apply_repulsion(nodes : TNodes; coefficient : double);
  procedure apply_attraction(nodes : TNodes; edges : TEdges; distributedAttraction : boolean; coefficient, edgeWeightInfluence : double);
  function adjustSpeedAndApplyForces(nodes : TNodes; speed, speedEfficiency, jitterTolerance : double; adjustSizes : boolean) : double;


implementation

Uses Math;


// Here are some functions from ForceFactory.java
// =============================================

// Repulsion function.  `n1` and `n2` should be nodes.  This will
// adjust the dx and dy values of `n1`  `n2`
procedure linRepulsion(n1, n2 : TNode; coefficient : double);
var xDist, yDist : double; factor, distance : double;
begin
    xDist := n1.x - n2.x;
    yDist := n1.y - n2.y;
    distance := xDist * xDist + yDist * yDist;  // Distance squared

    if distance > 0 then
       begin
       factor := coefficient * n1.mass * n2.mass / distance;
       n1.dx := n1.dx + xDist * factor;
       n1.dy := n1.dy + yDist * factor;
       n2.dx := n2.dx - xDist * factor;
       n2.dy := n2.dy - yDist * factor;
       end;
end;


// Gravity repulsion function.  For some reason, gravity was included
// within the linRepulsion function in the original gephi java code,
// which doesn't make any sense (considering a. gravity is unrelated to
// nodes repelling each other, and b. gravity is actually an
// attraction)
procedure linGravity(n : TNode; g : double);
var xDist, yDist, distance, factor : double;
begin
    xDist := n.x;
    yDist := n.y;
    distance := sqrt(xDist * xDist + yDist * yDist);

    if distance > 0 then
       begin
       factor := n.mass * g / distance;
       n.dx := n.dx - xDist * factor;
       n.dy := n.dy - yDist * factor;
       end;
end;


// Strong gravity force function. `n` should be a node, and `g`
// should be a constant by which to apply the force.
procedure strongGravity(n : TNode; g, coefficient : double);
var xDist, yDist, distance, factor : double;
begin
    xDist := n.x;
    yDist := n.y;

    if (xDist <> 0) and (yDist <> 0) then
        begin
        factor := coefficient * n.mass * g;
        n.dx := n.dx - xDist * factor;
        n.dy := n.dy - yDist * factor;
        end;
end;


// Attraction function.  `n1` and `n2` should be nodes.  This will
// adjust the dx and dy values of `n1` and `n2`.  It does
// not return anything.
procedure linAttraction(n1, n2 : TNode; weight : double; distributedAttraction : boolean; coefficient : double);
var xDist, yDist, distance, factor : double;
begin
    xDist := n1.x - n2.x;
    yDist := n1.y - n2.y;
    if not distributedAttraction then
        factor := -coefficient * weight
    else
        factor := -coefficient * weight / n1.mass;

    n1.dx := n1.dx + xDist * factor;
    n1.dy := n1.dy + yDist * factor;
    n2.dx := n2.dx - xDist * factor;
    n2.dy := n2.dy - yDist * factor;
end;


// The following functions iterate through the nodes or edges and apply
// the forces directly to the node objects.  These iterations are here
// instead of the main file because Python is slow with loops.
procedure apply_repulsion(nodes : TNodes; coefficient : double);
var i, j : integer; node1, node2 : TNode;
begin
  i := 0;
  for node1 in nodes do
      begin
      j := i;
      for node2 in nodes do
          begin
          if j = 0 then
             break;
          linRepulsion(node1, node2, coefficient);
          j := j - 1;
          end;
      i := i + 1;
      end;
end;


procedure apply_gravity(nodes : TNodes; gravity, scalingRatio : double; useStrongGravity : boolean);
var n : TNode;
begin
    if not useStrongGravity then
        for n in nodes do
            linGravity(n, gravity)
    else
        for n in nodes do
            strongGravity(n, gravity, scalingRatio)
end;


procedure apply_attraction(nodes : TNodes; edges : TEdges; distributedAttraction : boolean; coefficient, edgeWeightInfluence : double);
var edge : TEdge;
begin
  // Optimization, since usually edgeWeightInfluence is 0 or 1, and pow is slow
  if edgeWeightInfluence = 0 then
        begin
        for edge in edges do
            linAttraction(edge.src, edge.dest, 1, distributedAttraction, coefficient)
        end
    else if edgeWeightInfluence = 1 then
            begin
            for edge in edges do
                linAttraction(edge.src, edge.dest, edge.weight, distributedAttraction, coefficient)
            end
    else
        for edge in edges do
            linAttraction(edge.src, edge.dest, math.power(edge.weight, edgeWeightInfluence),
                          distributedAttraction, coefficient)

end;


// Adjust speed and apply forces step
function adjustSpeedAndApplyForces(nodes : TNodes; speed, speedEfficiency, jitterTolerance : double; adjustSizes : boolean) : double;
var totalSwinging, totalEffectiveTraction : double;
    estimatedOptimalJitterTolerance, jt : double;
    n : TNode;
    minJT, maxJT : double;
    swinging, factor : double;
    targetSpeed, minSpeedEfficiency : double;
    maxRise : double;
    df : double;
begin
    // Auto adjust speed.
    totalSwinging := 0.0;  // How much irregular movement
    totalEffectiveTraction := 1.0;  // How much useful movement
    for n in nodes do
        begin
        swinging := sqrt((n.old_dx - n.dx) * (n.old_dx - n.dx) + (n.old_dy - n.dy) * (n.old_dy - n.dy));
        totalSwinging := totalSwinging + n.mass * swinging;
        totalEffectiveTraction := totalEffectiveTraction + 0.5 * n.mass * sqrt(
            (n.old_dx + n.dx) * (n.old_dx + n.dx) + (n.old_dy + n.dy) * (n.old_dy + n.dy));
        end;

    // We want that swingingMovement < tolerance * convergenceMovement
    // Optimize jitter tolerance.  The 'right' jitter tolerance for
    // this network. Bigger networks need more tolerance. Denser
    // networks need less tolerance. Totally empiric.
    estimatedOptimalJitterTolerance := 0.05 * sqrt(nodes.count);
    minJT := sqrt(estimatedOptimalJitterTolerance);
    maxJT := 10;
    jt := jitterTolerance * max(minJT, min(maxJT, estimatedOptimalJitterTolerance * totalEffectiveTraction
                                  /(nodes.count * nodes.count)));

    minSpeedEfficiency := 0.05;

    // Protective against erratic behavior
    if (totalSwinging / totalEffectiveTraction) > 2.0 then
        begin
        if speedEfficiency > minSpeedEfficiency then
            speedEfficiency := speedEfficiency*0.5;
        jt := max(jt, jitterTolerance);
        end;

    targetSpeed := jt * speedEfficiency * totalEffectiveTraction / totalSwinging;

    if totalSwinging > jt * totalEffectiveTraction then
       begin
       if speedEfficiency > minSpeedEfficiency then
          speedEfficiency := speedEfficiency * 0.7
       end
    else if speed < 1000 then
        speedEfficiency := speedEfficiency * 1.3;

    // But the speed shoudn't rise too much too quickly, since it would
    // make the convergence drop dramatically.
    maxRise := 0.5;
    speed := speed + min(targetSpeed - speed, maxRise * speed);

    // Apply forces.
    if adjustSizes then
        begin
        for n in nodes do
          begin
          swinging := n.mass * sqrt((n.old_dx - n.dx) * (n.old_dx - n.dx) + (n.old_dy - n.dy) * (n.old_dy - n.dy));
          factor := 0.1 * speed / (1.0 + sqrt(speed * swinging));

          df := sqrt(Math.power(n.dx, 2) + Math.power(n.dy, 2));
          factor := Math.min(factor * df, 10.0) / df;

          n.x := n.x + (n.dx * factor);
          n.y := n.y + (n.dy * factor);
          end;
        end
      else
        begin
        for n in nodes do
          begin
          swinging := n.mass * sqrt((n.old_dx - n.dx) * (n.old_dx - n.dx) + (n.old_dy - n.dy) * (n.old_dy - n.dy));
          factor := speed / (1.0 + sqrt(speed * swinging));

          n.x := n.x + (n.dx * factor);
          n.y := n.y + (n.dy * factor);
          end;
        end;
end;

end.
