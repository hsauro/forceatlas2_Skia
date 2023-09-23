unit uLayout;

interface

Uses Classes, Graphics, Dialogs, Generics.Collections, uNetwork;

type
  TCallBack = procedure of object;

  procedure doOneInteration (network : TNetwork; width, height : integer; k, t : double; callBack : TCallBack);
  procedure fruchterman_reingold(network : TNetwork; width, height : integer; iterations : integer; callBack : TCallBack);


implementation

Uses sysutils, math, ufMain;

const
  enumber = 2.71828182;

var N : double = 1000;
    k : double = 5;
    P : double = 0.05;



// -------------------------------------------------------------


// attractive force
function f_attractive (d, k : double) : double;
begin
    result := d*d/k;
end;

// repulsive force
function f_repulsive (d, k : double) : double;
begin
    result := k*k/d;
end;


procedure doOneInteration (network : TNetwork; width, height : integer; k, t : double; callBack : TCallBack);
var d, dt, dx, dy, ddx, ddy, distance, x, y : double;
    f, a1, a2 : double;
    i, v, u, m : integer;
    factor : double;
    mass, gravity : double;
begin
   if Assigned (callBack) then
      callBack;
   sleep (7);

         // calculate repulsive forces
         for v := 0 to network.nodes.Count - 1 do
             begin
             network.nodes[v].dx := 0;
             network.nodes[v].dy := 0;
             for u := 0 to network.nodes.Count - 1 do
                 begin
                 if network.nodes[v] <> network.nodes[u] then
                    begin
                    dx := network.nodes[v].x - network.nodes[u].x;
                    dy := network.nodes[v].y - network.nodes[u].y;
                    distance := sqrt(dx*dx+dy*dy);
                    if distance <> 0 then
                         begin
                         d := f_repulsive (distance, k)/distance;
                         network.nodes[v].dx := network.nodes[v].dx + dx*d;
                         network.nodes[v].dy := network.nodes[v].dy + dy*d;
                         end;
                    end;
                end
             end;


         // calculate gravity forces
         mass := 1; gravity := 90.0;
         for v := 0 to network.nodes.Count - 1 do
             begin
             distance := sqrt(network.nodes[v].x * network.nodes[v].x + network.nodes[v].y * network.nodes[v].y);

            if distance > 0 then
               begin
               factor := mass * gravity / distance;
               network.nodes[v].dx := network.nodes[v].dx - network.nodes[v].x * factor;
               network.nodes[v].dy := network.nodes[v].dy - network.nodes[v].y * factor;
               end;
             end;

          // calculate attractive forces
         for m := 0 to network.edges.count - 1 do
             begin
             dx := network.edges[m].src.x - network.edges[m].dest.x;
             dy := network.edges[m].src.y - network.edges[m].dest.y;
             distance := sqrt(dx*dx+dy*dy);
             if distance <> 0 then
                begin
                //adjustk = k;
								//adjustk = (k * Math.Log((v.Degree + u.Degree + 2), Math.E) + (Math.Max(v.W, v.H) + Math.Max(u.W, u.H))/4);
                d := f_attractive (distance,k)/distance;
                ddx := dx*d;
                ddy := dy*d;
                network.edges[m].src.dx := network.edges[m].src.dx - ddx;
                network.edges[m].src.dy := network.edges[m].src.dy - ddy;

                network.edges[m].dest.dx := network.edges[m].dest.dx + ddx;
                network.edges[m].dest.dy := network.edges[m].dest.dy + ddy;
                end;
            end;

				 // Adjust Coordinates
         for v := 0 to network.nodes.Count - 1 do
				     begin
             if not network.nodes[v].locked then
                begin
                dx := network.nodes[v].dx;
                dy := network.nodes[v].dy;
                distance := sqrt(dx*dx+dy*dy);

                if (distance <> 0) then
                    begin
                    if t < abs (dx) then
                       f := t
                    else f := dx;
                    a1 := ((dx/distance) * f);
                    network.nodes[v].x := network.nodes[v].x + a1; // divide by d is okay
                    if t < abs (dy) then
                       f := t
                    else f := dy;

                    a2 := ((dy/distance) * f);
                    network.nodes[v].y := network.nodes[v].y + a2;//math.Min (dy, t));
                    end;
                end;
				     end;
end;

// Translated from Annastasia Deckjard's C# code of autolayout in SBW

procedure fruchterman_reingold(network : TNetwork; width, height : integer; iterations : integer; callBack : TCallBack);
var W, L, area : double;
    k, dt, t, x, y : double;
    i : integer;
    dx, dy, ddx, ddy, distance, d: double;
    v, u, m : integer;
    tempinit, alpha, f, sum: double;
    finished : boolean;
    iter : integer;
    maxIter : integer;
    threshold, err : double;
begin
  finished := False;
  iter := 0;
  maxIter := iterations;
  W := width;
  L := height;
  area := W*L;
  //k := sqrt(area/length (network.nodes));
  k := 60;


  tempinit := 100 * ln(network.edges.count + 2);
  alpha := ln(tempinit) - ln(0.25);

  t := tempinit * Math.Power(enumber, -alpha * 0.5);
  dt := 5*t / (iterations + 1);
  threshold := 4;
  while not finished do
         begin

         doOneInteration (network, width, height, k, t, callBack);

         inc (iter);
         if iter > maxIter then
            finished := True;
         frmMain.lblIteration.caption := 'Iteration: ' + inttostr (iter);
         frmMain.lblIteration.refresh;

         // cooling
         sum := 0;
         for v  := 0 to network.nodes.Count - 1 do
             sum := sum + (network.nodes[v].dx*network.nodes[v].dx) + (network.nodes[v].dy*network.nodes[v].dy);
         err := sqrt (sum) / network.nodes.Count;
         if t < 0 then
            finished := True;

         if err < 10 then
            t := t*0.9
         else
            t := t*0.95;

         frmMain.lblError.caption := 'temperature = ' + floattostr (trunc(t*1000)/1000) + '  Error: ' + floattostr (trunc (err*1000)/1000);
         if err < threshold then
            finished := True;

         end;
end;


end.


//
          // limit the maximum displacement to the temperature t
         // and then prevent from being displace outside frame
//         for v := 0 to length(network.nodes) - 1 do
//             begin
//             dx := network.nodes[v].dx;
//             dy := network.nodes[v].dy;
//             disp := sqrt(dx*dx+dy*dy);
//             if disp <> 0 then
//                begin
//                //network.nodes[v].x := network.nodes[v].x*math.min (disp, t);
//                //network.nodes[v].x := network.nodes[v].y*math.min (disp, t);
//                //network.nodes[v].x := math.min(W/2, math.max(-W/2,network.nodes[v].x));
//                //network.nodes[v].y := math.min(L/2, math.max(-L/2,network.nodes[v].y));
//
//                d := math.min(disp,t)/disp;
//                x := network.nodes[v].x + dx*d;
//                y := network.nodes[v].y + dy*d;
//                x := math.min(W,math.max(0,x)) - W/2;
//                y := math.min(L, max(0,y)) - L/2;
//                network.nodes[v].x := math.min(sqrt(W*W/4-y*y),math.max(-sqrt(W*W/4-y*y),x)) + W/2;
//                network.nodes[v].y := math.min(sqrt(L*L/4-x*x),math.max(-sqrt(L*L/4-x*x),y)) + L/2;
//                end;
//             end;

