"""Shared forged-iron border pieces, transparent legacy DXT5."""
from pathlib import Path
from PIL import Image,ImageDraw
out=Path(__file__).parent/'borders'
out.mkdir(exist_ok=True)
im=Image.new('RGBA',(256,8));d=ImageDraw.Draw(im)
for y,color in enumerate([(13,20,26,220),(75,94,109,255),(199,212,220,255),(126,146,162,255),(39,53,65,255),(10,17,23,190)]):
 d.line((0,y+1,255,y+1),fill=color)
im.save(out/'rail_dxt5.dds',pixel_format='DXT5')
im=Image.new('RGBA',(32*4,64*4));d=ImageDraw.Draw(im)
def poly(points,color):d.polygon([(x*4,y*4) for x,y in points],fill=color)
poly([(25,2),(9,8),(5,25),(1,32),(5,39),(9,56),(25,62),(18,48),(16,16)],(17,25,33,255))
poly([(25,2),(9,8),(5,25),(1,32),(7,31),(13,12)],(174,192,205,255))
poly([(1,32),(5,39),(9,56),(25,62),(15,53),(10,36),(7,31)],(76,98,116,255))
poly([(12,23),(20,32),(12,41),(7,32)],(131,154,172,255))
poly([(12,27),(16,32),(12,37),(10,32)],(27,41,53,255))
im.resize((32,64),Image.Resampling.LANCZOS).save(out/'cap_dxt5.dds',pixel_format='DXT5')
print('Generated RPG border textures')
