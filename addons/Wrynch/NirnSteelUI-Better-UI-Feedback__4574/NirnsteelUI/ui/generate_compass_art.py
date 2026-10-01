"""NirnSteel compass: native-height steel rails, forged end caps and bearing marker."""
from pathlib import Path
import math
from PIL import Image, ImageDraw, ImageChops

OUT = Path(__file__).parent / "compass"
OUT.mkdir(exist_ok=True)

# All three pieces share y=7..57 in a 64px canvas. This keeps their seams
# aligned at both native heights (39 keyboard / 24 gamepad), without moving pins.
rail = Image.new("RGBA", (512, 64))
draw = ImageDraw.Draw(rail)
for y in range(7, 58):
    edge = abs(y - 32) / 25
    draw.line((0, y, 511, y), fill=(10, 17, 23, int(110 + 55 * edge)))
for y, color in [
    (5, (0, 0, 0, 55)), (6, (5, 9, 13, 235)),
    (7, (179, 197, 208, 245)), (8, (73, 95, 112, 255)),
    (9, (24, 38, 49, 230)), (55, (27, 41, 53, 245)),
    (56, (127, 151, 167, 255)), (57, (47, 66, 81, 255)),
    (58, (2, 5, 9, 215)), (59, (0, 0, 0, 60)),
]:
    draw.line((0, y, 511, y), fill=color)
# Subtle hammered variation on the metal only; the viewport stays uncluttered.
for x in range(512):
    delta = int(9 * math.sin(x * .47) + 4 * math.sin(x * 1.9))
    draw.point((x, 7), (179 + delta, 197 + delta, 208 + delta, 245))
rail.save(OUT / "rail_v3_dxt5.dds", pixel_format="DXT5")

SCALE = 4
# Continue the rail's exact fill/alpha and horizontal edge profile through the
# ends. An opaque cap backing previously made a dark block at each join.
cap = rail.crop((0, 0, 1, 64)).resize((32 * SCALE, 64 * SCALE), Image.Resampling.NEAREST)
mask = Image.new("L", cap.size)
ImageDraw.Draw(mask).polygon(
    [(x * SCALE, y * SCALE) for x, y in [(32, 4), (13, 4), (2, 32), (13, 61), (32, 61)]],
    fill=255,
)
cap.putalpha(ImageChops.multiply(cap.getchannel("A"), mask))
draw = ImageDraw.Draw(cap)
def poly(points, color):
    draw.polygon([(x * SCALE, y * SCALE) for x, y in points], fill=color)

def bevel(points, color, width):
    draw.line([(x * SCALE, y * SCALE) for x, y in points], fill=color, width=width * SCALE)

bevel([(14, 6), (4, 32), (14, 58)], (5, 9, 13, 235), 3)
bevel([(14, 7), (5, 32)], (179, 197, 208, 245), 1)
bevel([(5, 32), (14, 57)], (127, 151, 167, 255), 1)
# Inset steel rivet, deliberately small enough to leave edge pins readable.
poly([(18, 25), (22, 32), (18, 39), (14, 32)], (5, 11, 17, 255))
poly([(18, 27), (20, 32), (18, 36), (16, 32)], (146, 172, 188, 255))
poly([(18, 29), (20, 32), (18, 36)], (62, 91, 113, 255))
cap = cap.resize((32, 64), Image.Resampling.LANCZOS)
# Keep the final columns byte-identical to the rail before DDS compression.
# Both ends use this same artwork, mirrored by the compass control.
cap.paste(rail.crop((0, 0, 1, 64)).resize((8, 64)), (24, 0))
cap.save(OUT / "cap_v4_dxt5.dds", pixel_format="DXT5")

heading = Image.new("RGBA", (32 * SCALE, 32 * SCALE))
draw = ImageDraw.Draw(heading)
poly([(16, 2), (30, 25), (16, 19), (2, 25)], (4, 9, 14, 245))
poly([(16, 5), (16, 17), (5, 22)], (199, 218, 229, 255))
poly([(16, 5), (27, 22), (16, 17)], (93, 127, 153, 255))
heading = heading.resize((32, 32), Image.Resampling.LANCZOS)
heading.save(OUT / "heading_v3_dxt5.dds", pixel_format="DXT5")
print("Generated three native-aligned compass DDS textures")
