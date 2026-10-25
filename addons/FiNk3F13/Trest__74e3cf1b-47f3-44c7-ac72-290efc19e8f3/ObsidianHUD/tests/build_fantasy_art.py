"""Original geometric HUD artwork. No pixels from the supplied references are used."""
from pathlib import Path
from PIL import Image, ImageDraw
import io
import struct
import math

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "art"
ART.mkdir(exist_ok=True)
S = 3

def canvas(size):
    return Image.new("RGBA", (size[0] * S, size[1] * S))

def poly(draw, points, fill):
    draw.polygon([(round(x*S), round(y*S)) for x,y in points], fill=fill)

def line(draw, points, fill, width=1):
    draw.line([(round(x*S), round(y*S)) for x,y in points], fill=fill, width=max(1,round(width*S)), joint="curve")

def finish(im, size):
    return im.resize(size, Image.Resampling.LANCZOS)

def save_dds(im, name):
    # Standard legacy DXT3 header, matching the proven WorldMarker atlas format.
    out=io.BytesIO()
    im.save(out,format="DDS",pixel_format="DXT3")
    payload=out.getvalue()[128:]
    w,h=im.size
    assert len(payload)==((w+3)//4)*((h+3)//4)*16
    header=b'DDS '+struct.pack('<7I',124,0x81007,h,w,len(payload),0,0)+bytes(44)
    header+=struct.pack('<II4s5I',32,4,b'DXT3',0,0,0,0,0)+struct.pack('<5I',0x1000,0,0,0,0)
    (ART/name).write_bytes(header+payload)

def bar_frame():
    im=canvas((512,64)); d=ImageDraw.Draw(im)
    outer=[(6,11),(485,11),(507,29),(483,54),(6,54)]
    inner=[(12,19),(482,19),(495,30),(479,46),(12,46)]
    poly(d,outer,(13,14,18,255))
    line(d,outer+[outer[0]],(38,35,40,255),3)
    line(d,[(9,12),(484,12),(504,29)],(185,178,181,255),2)
    line(d,[(12,16),(482,16),(500,29)],(91,86,96,255),3)
    line(d,[(7,52),(483,52),(504,31)],(66,58,65,255),3)
    line(d,[(12,47),(479,47),(496,31)],(189,170,157,255),1)
    poly(d,inner,(0,0,0,0))
    line(d,[(12,19),(482,19),(495,30)],(226,208,192,255),1)
    line(d,[(12,46),(479,46),(495,30)],(34,28,34,255),1)
    # Keep the upper edge smooth, without a raised decorative shoulder.
    poly(d,[(494,26),(498,30),(494,34),(490,30)],(42,32,38,255))
    return finish(im,(512,64))

def bar_fill():
    im=canvas((512,64)); d=ImageDraw.Draw(im)
    shape=[(12,20),(482,20),(494,30),(479,45),(12,45)]
    poly(d,shape,(255,255,255,255))
    # Shading belongs to the texture so the coloured fill reads as enamel.
    mask=im.getchannel('A')
    for y in range(64*S):
        value=round(255-(max(0,y/S-23)/24)*115)
        d.line([(0,y),(512*S,y)],fill=(value,value,value,255))
    im.putalpha(mask)
    return finish(im,(512,64))

def curved_bottom(source, frame=False):
    # Shared UI geometry: badge (-7,18), size 100; bottom bar (36,81),
    # reference size 394x35. The badge's outer circle is (64,64), r=55
    # in its 128px image. Keep this left cap at a fixed UI width at runtime.
    im=source.resize((512*S,64*S),Image.Resampling.LANCZOS)
    d=ImageDraw.Draw(im)
    def edge(y):
        dy=81+y*35/64-68
        radius=55*100/128
        return (43+math.sqrt(max(0,radius*radius-dy*dy))-36)*512/394
    for yy in range(64*S):
        y=yy/S
        boundary=edge(y)+(5 if not frame else 0)
        d.line([(0,yy),(round(boundary*S),yy)],fill=(0,0,0,0))
    if frame:
        points=[(edge(11+i/8),11+i/8) for i in range(43*8+1)]
        line(d,points,(40,33,40,255),4)
        line(d,[(x+1,y) for x,y in points],(183,166,159,255),1.5)
        line(d,[(x+4,y) for x,y in points if 19<=y<=46],(65,51,62,255),1)
    return finish(im,(512,64))

def badge(round_badge=False):
    im=canvas((128,128)); d=ImageDraw.Draw(im)
    if round_badge:
        for box,color in [((9,9,119,119),(18,19,24,255)),((13,13,115,115),(159,154,167,255)),
            ((17,17,111,111),(48,46,58,255)),((22,22,106,106),(103,91,105,255)),((25,25,103,103),(22,25,36,255))]:
            d.ellipse(tuple(round(x*S) for x in box),fill=color)
        # Follow the ring with a true circular arc; connected straight segments
        # left a visible kink in the upper-left metallic highlight.
        d.arc(tuple(round(v*S) for v in (13,13,115,115)),210,296,
              fill=(217,208,202,255),width=2*S)
    else:
        poly(d,[(64,4),(123,64),(64,124),(5,64)],(13,14,20,255))
        poly(d,[(64,9),(118,64),(64,119),(10,64)],(162,155,168,255))
        poly(d,[(64,15),(112,64),(64,113),(16,64)],(48,45,57,255))
        poly(d,[(64,22),(105,64),(64,106),(23,64)],(117,101,112,255))
        poly(d,[(64,26),(101,64),(64,102),(27,64)],(23,26,38,255))
        line(d,[(13,64),(64,12),(115,64)],(232,220,211,255),2)
        line(d,[(27,64),(64,101),(101,64)],(172,149,139,255),1)
        for pts in [[(64,1),(68,9),(64,13),(60,9)],[(122,60),(127,64),(122,68),(118,64)],
                    [(60,119),(64,127),(68,119),(64,114)],[(1,64),(9,60),(13,64),(9,68)]]:
            poly(d,pts,(132,122,138,255))
    # Keep the circular portrait background clean behind the class silhouette.
    if not round_badge:
        line(d,[(46,67),(64,41),(82,67),(64,89),(46,67)],(87,91,112,255),2)
        line(d,[(64,47),(64,81)],(167,156,168,255),1)
    return finish(im,(128,128))

def slot_frame():
    im=canvas((64,64)); d=ImageDraw.Draw(im)
    outer=[(8,3),(56,3),(61,8),(61,56),(56,61),(8,61),(3,56),(3,8)]
    inner=[(9,9),(55,9),(55,55),(9,55)]
    poly(d,outer,(32,31,41,255)); line(d,outer+[outer[0]],(100,94,108,255),2)
    line(d,[(6,54),(6,9),(10,6),(54,6),(58,10)],(195,180,173,255),1)
    poly(d,inner,(0,0,0,0))
    line(d,[(9,55),(55,55),(55,9)],(72,59,71,255),2)
    return finish(im,(64,64))

if __name__=='__main__':
    images={'fantasy_frame.dds':bar_frame(),'fantasy_fill.dds':bar_fill(),
        'fantasy_diamond.dds':badge(),'fantasy_round.dds':badge(True),'fantasy_slot.dds':slot_frame(),
        'fantasy_curve_frame.dds':curved_bottom(bar_frame(),True),
        'fantasy_curve_fill.dds':curved_bottom(bar_fill())}
    for name,im in images.items(): save_dds(im,name)
    print('Original fantasy artwork:',sum((ART/name).stat().st_size for name in images),'bytes')
