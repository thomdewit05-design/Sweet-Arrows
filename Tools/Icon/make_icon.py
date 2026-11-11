"""Draws the Sweet Arrows app icon: a smiling lemon star candy riding a big white arrow over a bright
candy sky, with a few sweets and sparkles around it (the game's own shapes, no text).

Run: python3 Tools/Icon/make_icon.py
Writes the 1024 px app icon, the launch-screen icon and the website icon.
"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
S = 1024
SS = 3  # supersampling
W = S * SS
INK = (74, 44, 42)
COL = {
    "lemon": (255, 210, 63), "mint": (61, 220, 151), "blue": (91, 108, 255),
    "orange": (255, 159, 28), "grape": (162, 89, 255), "pink": (255, 92, 138),
}


def lerp(a,b,t): return tuple(int(a[i]+(b[i]-a[i])*t) for i in range(3))
def lighten(c,a): return lerp(c,(255,255,255),a)
def darken(c,a): return lerp(c,(0,0,0),a)

def sky(top,bot,rays=True,cx=0.5,cy=0.5):
    img=Image.new("RGB",(W,W)); d=ImageDraw.Draw(img)
    for y in range(W):
        d.line([(0,y),(W,y)],fill=lerp(top,bot,y/W))
    if rays:
        m=Image.new("L",(W,W),0); md=ImageDraw.Draw(m); X,Y=W*cx,W*cy
        for i in range(18):
            a0=2*math.pi*i/18; a1=a0+math.pi/18
            md.polygon([(X,Y),(X+math.cos(a0)*W*1.5,Y+math.sin(a0)*W*1.5),(X+math.cos(a1)*W*1.5,Y+math.sin(a1)*W*1.5)],fill=34)
        img.paste((255,255,255),mask=m.filter(ImageFilter.GaussianBlur(W*0.006)))
    return img

def star_pts(cx,cy,ro,ri,n=5,rot=0):
    return [(cx+math.cos(rot+math.pi*i/n-math.pi/2)*(ro if i%2==0 else ri), cy+math.sin(rot+math.pi*i/n-math.pi/2)*(ro if i%2==0 else ri)) for i in range(2*n)]

def shape_poly(kind,cx,cy,r):
    if kind=='circle': return [(cx+math.cos(t)*r,cy+math.sin(t)*r) for t in [i/120*2*math.pi for i in range(120)]]
    if kind=='star':
        pts=star_pts(cx,cy,r*1.1,r*0.55)
        return round_poly(pts, r*0.12)
    if kind=='diamond': return round_poly([(cx,cy-r*1.08),(cx+r*0.95,cy),(cx,cy+r*1.08),(cx-r*0.95,cy)], r*0.18)
    if kind=='square': return round_poly([(cx-r*0.88,cy-r*0.88),(cx+r*0.88,cy-r*0.88),(cx+r*0.88,cy+r*0.88),(cx-r*0.88,cy+r*0.88)], r*0.35)
    if kind=='drop':
        pts=[]
        for i in range(120):
            t=i/120*2*math.pi
            x=math.sin(t)*r*0.9
            y=-math.cos(t)*r
            if math.cos(t)>0:  # top half narrows to a point
                k=math.cos(t)
                x*= (1-k)**0.9 if k>0 else 1
                y*=1.15
            pts.append((cx+x,cy+y+r*0.1))
        return pts
def round_poly(pts, rad, steps=8):
    out=[]; n=len(pts)
    for i in range(n):
        p0=pts[i-1]; p1=pts[i]; p2=pts[(i+1)%n]
        v1=(p0[0]-p1[0],p0[1]-p1[1]); v2=(p2[0]-p1[0],p2[1]-p1[1])
        l1=math.hypot(*v1); l2=math.hypot(*v2); rr=min(rad,l1/2.2,l2/2.2)
        a=(p1[0]+v1[0]/l1*rr,p1[1]+v1[1]/l1*rr); b=(p1[0]+v2[0]/l2*rr,p1[1]+v2[1]/l2*rr)
        for s in range(steps+1):
            t=s/steps
            out.append(((1-t)**2*a[0]+2*(1-t)*t*p1[0]+t*t*b[0], (1-t)**2*a[1]+2*(1-t)*t*p1[1]+t*t*b[1]))
    return out

def shadow(img, poly, off, blur, alpha=90):
    m=Image.new("L",(W,W),0); ImageDraw.Draw(m).polygon([(x,y+off) for x,y in poly],fill=alpha)
    img.paste(darken((120,60,90),0.2),mask=m.filter(ImageFilter.GaussianBlur(blur)))

def candy(img, kind, color, cx, cy, r, direction=None, face=False, shade=True, rim=True):
    poly=shape_poly(kind,cx,cy,r)
    if shade: shadow(img, poly, r*0.12, r*0.12)
    d=ImageDraw.Draw(img)
    if rim:
        d.polygon(shape_poly(kind,cx,cy,r*1.1),fill=(255,255,255))
    # gradient body
    body=Image.new("RGB",(W,W)); bd=ImageDraw.Draw(body)
    top=lighten(color,0.25); bot=darken(color,0.12)
    y0=int(cy-r*1.2); y1=int(cy+r*1.2)
    for y in range(max(y0,0),min(y1,W)):
        bd.line([(int(cx-r*1.3),y),(int(cx+r*1.3),y)],fill=lerp(top,bot,(y-y0)/(y1-y0)))
    m=Image.new("L",(W,W),0); ImageDraw.Draw(m).polygon(poly,fill=255)
    img.paste(body,mask=m)
    d=ImageDraw.Draw(img)
    # gloss
    d.ellipse([cx-r*0.62,cy-r*0.66,cx-r*0.08,cy-r*0.34],fill=lighten(color,0.6))
    d.ellipse([cx-r*0.52,cy-r*0.6,cx-r*0.3,cy-r*0.46],fill=(255,255,255))
    if direction is not None:
        arrow(d,cx,cy+r*0.04,r*1.05,direction)
    if face:
        draw_face(d,cx,cy+r*0.15,r*0.5)

def arrow(d,cx,cy,s,ang):
    # arrow pointing up then rotated by ang (radians, 0 = up, clockwise positive)
    pts=[(0,-0.42),(0.3,-0.06),(0.11,-0.06),(0.11,0.38),(-0.11,0.38),(-0.11,-0.06),(-0.3,-0.06)]
    rot=lambda x,y:(cx+(x*math.cos(ang)-y*math.sin(ang))*s, cy+(x*math.sin(ang)+y*math.cos(ang))*s)
    P=round_poly([rot(x,y) for x,y in pts], s*0.05, 4)
    d.polygon([(x+s*0.03,y+s*0.05) for x,y in P],fill=(*darken(INK,0),))
    d.polygon(P,fill=(255,255,255))

def long_arrow(d,a,b,w):
    ang=math.atan2(b[1]-a[1],b[0]-a[0])
    L=math.hypot(b[0]-a[0],b[1]-a[1])
    def rot(x,y): return (a[0]+x*math.cos(ang)-y*math.sin(ang), a[1]+x*math.sin(ang)+y*math.cos(ang))
    head=w*4.2
    shaft=[(0,-w),(L-head*0.8,-w),(L-head*0.8,w),(0,w)]
    tip=[(L-head,-w*2.9),(L,0),(L-head,w*2.9)]
    for poly in (shaft,tip):
        P=round_poly([rot(x,y) for x,y in poly], w*0.4, 4)
        d.polygon([(x+w*0.35,y+w*0.55) for x,y in P],fill=INK)
    for poly in (shaft,tip):
        d.polygon(round_poly([rot(x,y) for x,y in poly], w*0.4, 4),fill=(255,255,255))

def draw_face(d,cx,cy,s):
    for ex in (cx-s*0.45,cx+s*0.45):
        d.ellipse([ex-s*0.24,cy-s*0.62,ex+s*0.24,cy-s*0.06],fill=(255,255,255))
        d.ellipse([ex-s*0.15,cy-s*0.48,ex+s*0.17,cy-s*0.1],fill=(50,30,36))
        d.ellipse([ex-s*0.1,cy-s*0.43,ex,cy-s*0.32],fill=(255,255,255))
    d.chord([cx-s*0.26,cy-s*0.02,cx+s*0.26,cy+s*0.36],0,180,fill=(110,30,50))
    for chx in (cx-s*0.82,cx+s*0.82):
        d.ellipse([chx-s*0.16,cy-s*0.04,chx+s*0.16,cy+s*0.1],fill=(255,150,175))

def speedlines(d, x0, y0, dx, dy, n=3, length=0.2, gap=0.06, width=0.022):
    # lines trailing behind a point moving in (dx,dy)
    nx,ny=-dy,dx
    for i in range(n):
        o=(i-(n-1)/2)*W*gap
        L=W*length*(0.75 if i%2 else 1)
        sx=x0+nx*o; sy=y0+ny*o
        ex=sx-dx*L; ey=sy-dy*L
        d.line([(sx,sy),(ex,ey)],fill=(255,255,255),width=int(W*width))
        for (px,py) in [(sx,sy),(ex,ey)]:
            d.ellipse([px-W*width/2,py-W*width/2,px+W*width/2,py+W*width/2],fill=(255,255,255))

def pop(d,cx,cy,r,color):
    # burst: little rays + stars
    for i in range(10):
        a=2*math.pi*i/10+0.2
        x1,y1=cx+math.cos(a)*r*0.7,cy+math.sin(a)*r*0.7
        x2,y2=cx+math.cos(a)*r*1.1,cy+math.sin(a)*r*1.1
        d.line([(x1,y1),(x2,y2)],fill=(255,255,255),width=int(r*0.09))
    for (a,k,sz) in [(0.6,1.25,0.16),(2.4,1.3,0.12),(4.2,1.22,0.14)]:
        d.polygon(star_pts(cx+math.cos(a)*r*k,cy+math.sin(a)*r*k,r*sz,r*sz*0.45,4),fill=lighten(color,0.4))

def sparkles(d, pts):
    for (x,y,s) in pts:
        d.polygon(star_pts(x*W,y*W,s*W,s*W*0.32,4),fill=(255,255,255))

def D():
    """Star candy with a face on a big arrow."""
    img=sky((61,200,170),(160,120,255),cx=0.5,cy=0.55)
    d=ImageDraw.Draw(img)
    # big arrow pointing right behind, slightly upward
    long_arrow(d,(W*0.16,W*0.8),(W*0.86,W*0.2),W*0.05)
    candy(img,'star',COL['lemon'],W*0.47,W*0.53,W*0.25,face=True)
    d=ImageDraw.Draw(img)
    for (k,c,x,y,rr) in [('circle',COL['pink'],0.18,0.2,0.07),('diamond',COL['blue'],0.85,0.6,0.06),('drop',COL['orange'],0.5,0.87,0.06),('circle',COL['mint'],0.82,0.85,0.065)]:
        candy(img,k,c,W*x,W*y,W*rr)
    d=ImageDraw.Draw(img)
    sparkles(d,[(0.5,0.12,0.03),(0.12,0.5,0.025),(0.2,0.92,0.022)])
    return img


img = D().resize((S, S), Image.LANCZOS)
icon_path = os.path.join(ROOT, "SweetArrows", "Resources", "Assets.xcassets", "AppIcon.appiconset", "AppIcon.png")
img.save(icon_path)
launch_dir = os.path.join(ROOT, "SweetArrows", "Resources", "Assets.xcassets", "LaunchIcon.imageset")
rounded = Image.new("L", (S, S), 0)
ImageDraw.Draw(rounded).rounded_rectangle([0, 0, S, S], radius=int(S * 0.22), fill=255)
launch = img.convert("RGBA")
launch.putalpha(rounded)
launch.resize((360, 360), Image.LANCZOS).save(os.path.join(launch_dir, "LaunchIcon@3x.png"))
launch.resize((240, 240), Image.LANCZOS).save(os.path.join(launch_dir, "LaunchIcon@2x.png"))
launch.resize((256, 256), Image.LANCZOS).save(os.path.join(ROOT, "docs", "site", "icon.png"))
print("icon written:", os.path.abspath(icon_path))
