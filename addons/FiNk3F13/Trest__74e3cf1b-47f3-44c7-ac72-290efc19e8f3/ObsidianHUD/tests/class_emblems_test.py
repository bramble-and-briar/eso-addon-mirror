from pathlib import Path
from PIL import Image
import struct
import numpy as np

path=Path(__file__).resolve().parents[1]/'art/class_emblems.dds'
data=path.read_bytes()
assert data[:4]==b'DDS ' and data[84:88]==b'DXT3'
assert len(data)==524416
image=Image.open(path).convert('RGBA')
assert image.size==(1024,512)
for index in range(7):
    x,y=(index%4)*256,(index//4)*256
    tile=image.crop((x,y,x+256,y+256))
    assert tile.getchannel('A').getextrema()==(0,255)
    assert tile.getchannel('A').getbbox() is not None
    assert all(tile.getpixel(p)[3]==0 for p in [(0,0),(255,0),(0,255),(255,255)]),'atlas tiles need transparent corners'
    yy,xx=np.nonzero(np.asarray(tile.getchannel('A'))>16)
    assert np.sqrt((xx-128)**2+(yy-128)**2).max()<=103,'the visible silhouette must stay within the circular safe area'
    assert np.sqrt((xx-128)**2+(yy-128)**2).max()*77/256<=30.5,'the rendered symbol must stay inside the badge face'
assert image.crop((768,256,1024,512)).getchannel('A').getbbox() is None
print('Class atlas: seven high-resolution tiles, circular fit, DXT3 and 512 KiB budget passed')
