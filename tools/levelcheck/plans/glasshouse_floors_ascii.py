# Generates the ASCII floor plans in docs/design/heists/glasshouse.md (G0). Run: python3 tools/levelcheck/plans/glasshouse_floors_ascii.py
# Data-driven ASCII plans for Glasshouse. 1 char = 0.5 m; each char is a grid POINT (x = 0.5*col).
# Rooms are rectangles (x0,z0,x1,z1) in metres, origin = NW outer corner of the building,
# +x east, +z south (Godot -Z is north). Walls are drawn on room edges.
ROOMS = {
 0: [ # id, label, rect
  ("G1","RECEIVING",(0,0,5,4.5)),("G7","ELEC",(0,0,2,2)),("G2","WORKSHOP",(5,0,10.5,4.5)),
  ("G3","WC",(10.5,0,13,4.5)),("G8","STAIR",(13,0,16,4.5)),("G9","JAN",(14.5,3,16,4.5)),("G10","LOBBY",(16,0,18,4.5)),
  ("G4","STAFF CORRIDOR",(0,4.5,18,6)),("G5","SALES FLOOR",(0,6,13,12)),("G6","SALON",(13,6,18,12))],
 1: [
  ("U1","BREAK RM",(0,0,5.5,4.5)),("U2","SECURITY",(5.5,0,10.5,4.5)),("U3","WC",(10.5,0,13,4.5)),
  ("G8","(stair)",(13,0,16,4.5)),("U8","LOBBY",(16,0,18,4.5)),("U4","CORRIDOR",(0,4.5,18,6)),
  ("U5","ADMIN",(0,6,7,12)),("U6","MANAGER",(7,6,12,12)),("U7","STOCK/ARCHIVE",(12,6,18,12))],
}
# openings: (floor, kind, x0,z0,x1,z1)  kind D door, W window
OPEN = [
 (0,"D",3.0,0,4.0,0),      # back door (service 1.1) to alley
 (0,"D",2,1.0,2,1.0),      # electrical closet door (from receiving)
 (0,"D",3.5,4.5,3.5,4.5),  # receiving door
 (0,"D",7.5,4.5,7.5,4.5),  # workshop door
 (0,"D",11.5,4.5,11.5,4.5),# WC
 (0,"D",15.5,4.5,15.5,4.5),    # janitor (under-stair)
 (0,"D",17,4.5,17,4.5),    # lobby
 (0,"D",18,1.5,18,2.0),    # fire exit to Pell St
 (0,"D",1.5,6,1.5,6),      # staff door sales floor -> corridor
 (0,"D",16.5,6,16.5,6),    # salon back door (variable)
 (0,"D",13,10,13,10),      # salon door from sales floor
 (0,"D",10.5,12,12,12),    # main entrance double 1.8
 (0,"W",0.5,12,9.5,12),    # shopfront
 (0,"O",13.5,4.5,14,4.5),(1,"O",14.5,4.5,15.5,4.5),(0,"W",14,12,17,12),(0,"W",18,7.5,18,10.5),  # salon windows
 (0,"W",8,0,8.5,0),        # workshop high window (barred)
 (1,"D",3,4.5,3,4.5),(1,"D",8,4.5,8,4.5),(1,"D",11.5,4.5,11.5,4.5),(1,"D",16.5,4.5,16.5,4.5),
 (1,"D",4,6,4,6),(1,"D",10.5,6,10.5,6),(1,"D",13,6,13,6),
 (1,"W",1.5,0,3,0),(1,"W",7,0,8.5,0),(1,"W",12,0,12,0),
 (1,"W",1,12,2.5,12),(1,"W",4.5,12,6,12),(1,"W",8.5,12,10.5,12),(1,"W",13.5,12,16.5,12),(1,"W",18,8,18,10),
]
MARK = {0:[(6.5,1,"S"),(7,1,"L"),(6.5,9,"(O)"),(9.5,11.5,"G"),(9,5,"G"),(2.5,7,"======"),(3,7.5,"K"),
           (0.5,8,"L"),(0.5,9.5,"L"),(0.5,11,"L"),(3.5,10,"L"),(9.5,8.5,"L"),(15,8.5,"L L"),
           (13.5,1.5,"^"),(13.5,2.5,"^"),(13.5,3.5,"^"),(15,1.5,"v"),(15,2.5,"v"),(1,2.5,"G1")],
        1:[(1,2.5,"K"),(6,2.5,"K"),(9,2,"#mon"),(8,9,"K"),(9,10,"L"),(9,5,"G"),(16.5,2,"H"),
           (13.5,1.5,"="),(13.5,2.5,"="),(13.5,3.5,"="),(15,1.5,"v"),(15,2.5,"v"),(15,3.5,"v"),(13,4.5,"rrr  ")]}
def grid(W,H): return [[" "]*(int(W*2)+1) for _ in range(int(H*2)+1)]
def put(g,x,z,ch):
    i,j=int(round(x*2)),int(round(z*2))
    if 0<=j<len(g) and 0<=i<len(g[0]): g[j][i]=ch
def seg(g,x0,z0,x1,z1,ch):
    n=int(round(max(abs(x1-x0),abs(z1-z0))*2))
    for k in range(n+1):
        t=k/max(n,1); put(g,x0+(x1-x0)*t,z0+(z1-z0)*t,ch)
def txt(g,x,z,s):
    i,j=int(round(x*2)),int(round(z*2))
    for k,ch in enumerate(s):
        if 0<=i+k<len(g[0]): g[j][i+k]=ch
def plan(fl):
    W,H=18,12; g=grid(W,H)
    for rid,lab,(a,b,c,d) in ROOMS[fl]:
        for (p,q,r,s) in [(a,b,c,b),(a,d,c,d),(a,b,a,d),(c,b,c,d)]:
            ext = (p==q==0 and False)
            seg(g,p,q,r,s,"+")
    # exterior thicker glyph
    for (p,q,r,s) in [(0,0,18,0),(0,12,18,12),(0,0,0,12),(18,0,18,12)]: seg(g,p,q,r,s,"#")
    # interior edges: '-' horizontal '|' vertical
    for rid,lab,(a,b,c,d) in ROOMS[fl]:
        for (p,q,r,s,ch) in [(a,b,c,b,"-"),(a,d,c,d,"-"),(a,b,a,d,"|"),(c,b,c,d,"|")]:
            n=int(round(max(abs(r-p),abs(s-q))*2))
            for k in range(1,n):
                t=k/n; x=p+(r-p)*t; z=q+(s-q)*t
                i,j=int(round(x*2)),int(round(z*2))
                if g[j][i]=="+": g[j][i]=ch
    for (f,k,a,b,c,d) in OPEN:
        if f==fl: seg(g,a,b,c,d," " if k=="O" else k)
    for rid,lab,(a,b,c,d) in ROOMS[fl]:
        w=c-a
        s=rid if (w<3.5 or rid in ('G4','U4')) else (rid+" "+lab if len(rid+" "+lab)<=int(w*2)-1 else rid)
        if rid in ("G9",): continue
        txt(g,a+0.5,b+0.5 if (d-b)>2 else b+0.5,s)
    for (x,z,s) in MARK.get(fl,[]): txt(g,x,z,s)
    out=["      "+"".join((str(int(k/2)%10) if k%2==0 else " ") for k in range(37))]
    for j,row in enumerate(g):
        out.append(("%5.1f " % (j*0.5) if j%2==0 else "      ")+"".join(row).rstrip())
    return "\n".join(out)
print(plan(0)); print(); print(plan(1))
