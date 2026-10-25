from pathlib import Path
from PIL import Image
import math

ROOT=Path(__file__).resolve().parents[1]
for name,size in [('fantasy_frame.dds',(512,64)),('fantasy_fill.dds',(512,64)),
    ('fantasy_diamond.dds',(128,128)),('fantasy_round.dds',(128,128)),('fantasy_slot.dds',(64,64)),
    ('fantasy_curve_frame.dds',(512,64)),('fantasy_curve_fill.dds',(512,64))]:
    path=ROOT/'art'/name
    assert path.read_bytes()[84:88]==b'DXT3'
    im=Image.open(path).convert('RGBA')
    assert im.size==size
    assert im.getpixel((0,0))[3]==0, name+' corners must be transparent'
frame=Image.open(ROOT/'art/fantasy_frame.dds').convert('RGBA')
assert frame.getpixel((250,30))[3]==0,'frame centre must not cover resource fill'
assert frame.getpixel((250,12))[3]>0,'top metal edge must exist'
fill=Image.open(ROOT/'art/fantasy_fill.dds').convert('RGBA')
assert fill.getpixel((250,30))[3]==255,'resource interior must be opaque'
assert fill.getpixel((505,30))[3]==0,'slanted tip has a transparent outside margin'
slot=Image.open(ROOT/'art/fantasy_slot.dds').convert('RGBA')
assert slot.getpixel((32,32))[3]==0,'native skill icons remain visible through the frame'
curve=Image.open(ROOT/'art/fantasy_curve_fill.dds').convert('RGBA')
assert curve.getpixel((20,25))[3]==0,'curved left cutout must be transparent'
assert curve.getpixel((80,25))[3]==255,'curved fill must remain solid beyond the cutout'
curved_frame=Image.open(ROOT/'art/fantasy_curve_frame.dds').convert('RGBA')
assert curved_frame.getpixel((20,25))[3]==0,'frame must share the concave cutout'
for y in (20,32,44):
    first=next(x for x in range(96) if curved_frame.getpixel((x,y))[3]>100)
    dy=81+y*35/64-68
    expected=(43+math.sqrt((55*100/128)**2-dy**2)-36)*512/394
    assert abs(first-expected)<=5,'curve must follow the badge circle, allowing for the metal stroke'
print('Fantasy DDS assets: format, dimensions, transparent centres/corners and resource silhouette passed')
