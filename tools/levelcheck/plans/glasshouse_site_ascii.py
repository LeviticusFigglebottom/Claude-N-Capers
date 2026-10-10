# Generates the ASCII site plan in docs/design/heists/glasshouse.md (G0).
X0,X1,Z0,Z1=-14,32,-8,32
W=X1-X0+1; H=Z1-Z0+1
g=[[" "]*W for _ in range(H)]
def put(x,z,ch):
    i,j=x-X0,z-Z0
    if 0<=i<W and 0<=j<H: g[j][i]=ch
def fill(x0,z0,x1,z1,ch):
    for z in range(z0,z1+1):
        for x in range(x0,x1+1): put(x,z,ch)
def txt(x,z,s):
    for k,ch in enumerate(s): put(x+k,z,ch)
def box(x0,z0,x1,z1,ch="#"):
    for x in range(x0,x1+1): put(x,z0,ch); put(x,z1,ch)
    for z in range(z0,z1+1): put(x0,z,ch); put(x1,z,ch)
# far side of alley: Kessel Row backs
fill(-14,-8,21,-7,"%"); txt(-12,-8," KESSEL ROW BACKS (fenced yards, dressing) ")
# alley -6..0
txt(-13,-4,"gate"); put(-14,-4,"X"); put(-14,-3,"X"); put(-14,-5,"X")
txt(-11,-5,"P4 POLICE (alley W)")
fill(-9,-3,-5,-2,"v"); txt(-9,-4,"E1 van")
# building
box(0,0,18,12); txt(2,6,"VOSSBERG JEWELERS"); txt(4,7,"(2 storeys)")
fill(-14,0,-1,12,"%"); txt(-12,5," CASTELLAN "); txt(-12,6," TAILORING ")
# dumpsters & fire escape ladder & back door
txt(6,-1,"[BH][BH]"); put(2,-1,"F"); txt(3,-1,"d"); txt(10,-2,"hvac")
# sidewalks / streets
for x in range(-14,33): put(x,13,"_") ; put(x,16,"_"); put(x,30,"_")
for z in range(-6,31): put(19,z,":") if z<13 or z>16 else None
for z in range(-6,31): put(21,z,"|") if (z<13 or z>16) else None
for z in range(-6,31): put(29,z,"|") if (z<13 or z>16) else None
txt(-12,14,"SIDEWALK  P P P P (casing spawns)"); txt(-12,22,"HARLOW AVENUE  (4 lanes)")
txt(-12,24,"P1 POLICE (Harlow W) <-"); txt(16,24,"-> P2 POLICE (Harlow E)")
txt(22,2,"PELL"); txt(22,3,"STREET"); txt(22,7,"E2 van")
fill(23,8,26,9,"v")
txt(22,-6,"P3 POLICE"); txt(22,-5,"(Pell N)")
txt(18,12,"*"); txt(17,13,"NEON")
fill(30,-6,32,12,"%"); txt(30,-7,"GAR")
fill(-14,31,32,34,"%"); txt(-12,32," HOTEL / CAFE FACADES (dressing; P3 sniper perch roof) ")
txt(1,-3,"SERVICE ALLEY (6 m) one-way W->E")
r=[" "]*W
for x in range(X0,X1+1,2):
    pass
for x in (-10,0,10,20,30):
    lab=str(x)
    for k,ch in enumerate(lab): r[x-X0+k]=ch
print("   x  "+"".join(r))
for j,row in enumerate(g):
    z=Z0+j
    print(("%4d  " % z if z%2==0 else "      ")+"".join(row).rstrip())
