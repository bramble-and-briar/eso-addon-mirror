"""Three claw wounds, with separate dormant, charged and ready DXT5 layers."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageChops

OUT = Path(__file__).parent / "werewolf"
OUT.mkdir(exist_ok=True)
SIZE = (512, 256)
S = 3
mask = Image.new("L", (SIZE[0]*S, SIZE[1]*S))
d = ImageDraw.Draw(mask)
# Different lengths and slightly torn edges keep the marks from reading as bars.
for x, top, bottom in [(176,32,225),(268,13,239),(353,36,219)]:
    points = [(x+47,top),(x+23,top+47),(x+21,top+66),(x+7,top+85),
              (x-7,top+125),(x-33,bottom-14),(x-53,bottom),
              (x-26,bottom-48),(x-23,bottom-69),(x-10,top+92),
              (x+1,top+61),(x+25,top+27)]
    d.polygon([(a*S,b*S) for a,b in points], fill=255)
mask = mask.resize(SIZE, Image.Resampling.LANCZOS)

def layer(color, alpha):
    image = Image.new("RGBA", SIZE, color)
    image.putalpha(alpha)
    return image

def save(image, name):
    image.save(OUT / ("claws_"+name+"_dxt5.dds"), pixel_format="DXT5")

# The scars remain legible when empty. No badge, border, or rectangular housing.
outer = mask.filter(ImageFilter.MaxFilter(9))
base = layer((9,12,16), outer.filter(ImageFilter.GaussianBlur(2)))
edge = ImageChops.subtract(outer, mask)
base.alpha_composite(layer((105,111,118),edge.point(lambda a:int(a*.65))))
base.alpha_composite(layer((34,8,12),mask))
save(base,"base")

fill = layer((160,160,160),mask)
# Fine white cores tint with the charge color in-game.
core = mask.filter(ImageFilter.MinFilter(9))
fill.alpha_composite(layer((250,250,250),core))
save(fill,"fill")
glow = mask.filter(ImageFilter.GaussianBlur(13)).point(lambda a:min(255,int(a*1.8)))
save(layer((255,255,255),glow),"glow")
print("Generated three claw-wound DDS textures")
