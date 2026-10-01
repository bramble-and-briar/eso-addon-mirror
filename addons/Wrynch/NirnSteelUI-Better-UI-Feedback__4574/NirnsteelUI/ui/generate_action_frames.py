"""NirnSteel action frames, with icon apertures sized for ESO's native controls."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).parent / "actionbar"
OUT.mkdir(exist_ok=True)
S = 4

def poly(draw, points, color):
    draw.polygon([(round(x*S), round(y*S)) for x,y in points], fill=color)

def rect(draw, box, color):
    draw.rectangle(tuple(round(x*S) for x in box), fill=color)

def save(im, name):
    im.resize((64,64), Image.Resampling.LANCZOS).save(OUT / name, pixel_format="DXT5")

# This frame renders at 54px around a native 47px icon. The 56px aperture
# scales to 47.25px, preserving the complete skill while leaving a visible bevel.
im=Image.new('RGBA',(64*S,64*S));d=ImageDraw.Draw(im)
rect(d,(0.5,0.5,63.5,63.5),(13,20,27,255))
rect(d,(1.5,1.5,62.5,62.5),(82,103,119,255))
rect(d,(1.5,1.5,62.5,3),(202,218,228,255))
rect(d,(1.5,3,3,61),(139,163,181,255))
rect(d,(61,3,62.5,61),(72,91,105,255))
rect(d,(3,61,61,62.5),(39,54,67,255))
rect(d,(4,4,60,60),(0,0,0,0))
for x,y in [(2.5,2.5),(61.5,2.5),(2.5,61.5),(61.5,61.5)]:
    poly(d,[(x-2,y),(x,y-2),(x+2,y),(x,y+2)],(186,159,109,255))
save(im,'nirnsteel_socket_v3_dxt5.dds')

# Ultimate uses a separate 64px frame around the unchanged 47px icon.
for ready in (False,True):
    im=Image.new('RGBA',(64*S,64*S));d=ImageDraw.Draw(im)
    poly(d,[(9,3),(55,3),(61,9),(61,55),(55,61),(9,61),(3,55),(3,9)],(13,20,27,255))
    poly(d,[(10,5),(54,5),(59,10),(59,54),(54,59),(10,59),(5,54),(5,10)],
         (167,109,39,255) if ready else (87,106,119,255))
    poly(d,[(10,5),(54,5),(59,10),(56,11),(53,8),(11,8),(8,11),(5,10)],
         (255,224,137,255) if ready else (199,214,224,255))
    rect(d,(8.5,8.5,55.5,55.5),(0,0,0,0))
    for x,y in [(7,7),(57,7),(7,57),(57,57)]:
        poly(d,[(x-4,y),(x,y-4),(x+4,y),(x,y+4)],(42,41,33,255))
        poly(d,[(x-2,y),(x,y-2),(x+2,y),(x,y+2)],
             (255,224,130,255) if ready else (158,170,178,255))
    # Crown jewel and lower iron point live entirely outside the skill aperture.
    for y in (3,61):
        poly(d,[(27,y),(32,y-3),(37,y),(32,y+3)],(49,63,76,255))
        poly(d,[(29,y),(32,y-2),(35,y),(32,y+2)],
             (255,242,182,255) if ready else (116,163,191,255))
    if ready:
        for x in (5.5,58):
            rect(d,(x,17,x+0.75,25),(255,199,82,255))
            rect(d,(x,39,x+0.75,47),(255,199,82,255))
    save(im,'ultimate_ready_v3_dxt5.dds' if ready else 'ultimate_iron_v3_dxt5.dds')

im=Image.new('RGBA',(64*S,64*S));d=ImageDraw.Draw(im)
rect(d,(8,8,56,56),(255,168,51,220));rect(d,(11,11,53,53),(0,0,0,0))
im=im.filter(ImageFilter.GaussianBlur(3*S))
# Keep the middle clear so ultimate readiness never veils the ability artwork.
d=ImageDraw.Draw(im);rect(d,(13,13,51,51),(0,0,0,0))
save(im,'ultimate_halo_v3_dxt5.dds')
