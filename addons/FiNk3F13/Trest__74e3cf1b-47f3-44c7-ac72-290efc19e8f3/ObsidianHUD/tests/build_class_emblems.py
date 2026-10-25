"""Package generated transparent class art as a compact legacy DDS atlas.

Usage: python build_class_emblems.py path/to/class-icon-generation.json
The manifest preserves the imagegen prompts and source paths. Masters and
the labelled overview stay outside the installed addon to keep it small.
"""
from pathlib import Path
from PIL import Image, ImageOps, ImageDraw, ImageFont
import io, json, shutil, struct, sys
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
manifest=Path(sys.argv[1])
data=json.loads(manifest.read_text(encoding='utf-8'))
masters=manifest.parent/'class-icon-originals'
masters.mkdir(exist_ok=True)
TILE=256
atlas=Image.new('RGBA',(1024,512))
fit_report=[]
# Tune the visible portrait mass, rather than letting thin outer ornament tips
# determine every class's size. The circular aperture matches the badge face.
CLASS_ZOOM={
    'dragonknight':1.08,'sorcerer':1.10,'nightblade':1.18,
    'templar':1.06,'warden':1.10,'necromancer':1.08,'arcanist':1.27,
}
mask_y,mask_x=np.mgrid[:TILE,:TILE]
distance=np.sqrt((mask_x-128)**2+(mask_y-128)**2)
aperture=np.clip(100-distance,0,1)
badge=Image.open(ROOT/'art/fantasy_round.dds').convert('RGBA').resize((180,180),Image.Resampling.LANCZOS)
preview=Image.new('RGBA',(1000,660),(15,17,23,255))
draw=ImageDraw.Draw(preview)
font=ImageFont.truetype('C:/Windows/Fonts/segoeuib.ttf',21)
small=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',14)
draw.text((30,18),'OBSIDIAN HUD  /  KLASSENSYMBOLE',font=font,fill=(230,218,201))
for i,entry in enumerate(data['entries']):
    source=Path(entry['source'])
    target=masters/(entry['key']+'.png')
    if not target.exists(): shutil.copy2(source,target)
    im=Image.open(target).convert('RGBA')
    assert im.getchannel('A').getextrema()==(0,255),entry['key']+' needs real alpha'
    alpha=np.asarray(im.getchannel('A'))
    yy,xx=np.nonzero(alpha>16)
    cx=(float(xx.min())+float(xx.max()))/2
    cy=(float(yy.min())+float(yy.max()))/2
    radius=float(np.sqrt((xx-cx)**2+(yy-cy)**2).max())
    zoom=CLASS_ZOOM[entry['key']]
    scale=99*zoom/radius
    # Remove almost invisible source fringe before resampling. DXT3 can round
    # alpha 9 up to 17, making that fringe visible beyond the measured contour.
    im.putalpha(im.getchannel('A').point(lambda value: value if value>16 else 0))
    fitted=im.resize((round(im.width*scale),round(im.height*scale)),Image.Resampling.LANCZOS)
    tile=Image.new('RGBA',(TILE,TILE))
    tile.alpha_composite(fitted,(round(TILE/2-cx*scale),round(TILE/2-cy*scale)))
    # Decorative extremities end at the round portrait aperture, never on top
    # of the metal ring. Preserve the source alpha inside that aperture.
    alpha=np.asarray(tile.getchannel('A')).astype(float)
    tile.putalpha(Image.fromarray(np.rint(alpha*aperture).astype('uint8')))
    atlas.alpha_composite(tile,((i%4)*TILE,(i//4)*TILE))
    fit_report.append(dict(key=entry['key'],center=[cx,cy],radius=radius,scale=scale,zoom=zoom))
    x=20+(i%4)*245; y=65+(i//4)*295
    draw.rounded_rectangle((x,y,x+230,y+275),radius=14,fill=(24,27,35),outline=(65,61,64),width=1)
    preview.alpha_composite(badge,(x+25,y+12))
    icon=tile.resize((139,139),Image.Resampling.LANCZOS)
    preview.alpha_composite(icon,(x+46,y+33))
    draw.text((x+115,y+213),entry['name'],anchor='mt',font=font,fill=(231,222,208))
    draw.text((x+115,y+245),'Im Kreis zentriert / 256 px',anchor='mt',font=small,fill=(148,153,168))
draw.text((20+3*245+115,65+295+110),'Im HUD automatisch',anchor='mt',font=small,fill=(188,191,201))
draw.text((20+3*245+115,65+295+137),'passend zur Klasse',anchor='mt',font=small,fill=(188,191,201))
encoded=io.BytesIO(); atlas.save(encoded,format='DDS',pixel_format='DXT3')
payload=encoded.getvalue()[128:]
assert len(payload)==1024*512
header=[124,0x81007,512,1024,len(payload),0,1]+[0]*11
header += [32,4,int.from_bytes(b'DXT3','little'),0,0,0,0,0]
header += [0x1000,0,0,0,0]
target=ROOT/'art/class_emblems.dds'
target.write_bytes(b'DDS '+struct.pack('<31I',*header)+payload)
preview.convert('RGB').save(manifest.parent/'class-emblems-fit-overview.jpg',quality=94)
(manifest.parent/'class-icon-fit.json').write_text(json.dumps(fit_report,indent=2),encoding='utf-8')
print('Class atlas:',target.stat().st_size,'bytes; overview:',manifest.parent/'class-emblems-fit-overview.jpg')
