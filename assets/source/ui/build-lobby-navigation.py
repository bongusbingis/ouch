from pathlib import Path
from PIL import Image, ImageDraw
import math

# White vector masks; the live UI supplies every color and animation.
ROOT = Path('assets/source/ui')
PATHS = [
    ('M 60 6 L 196 6 C 214 6 222 14 227 33 L 246 117 C 252 141 234 154 211 154 L 45 154 C 22 154 4 141 10 117 L 29 33 C 34 14 42 6 60 6 Z', True, 0),
    ('M 35 45 C 39 23 48 16 65 16 L 191 16 C 202 16 210 19 215 26', False, 5),
    ('M 19 119 C 18 136 31 145 49 145 L 207 145 C 228 145 242 136 237 118', False, 3),
]
W,H,S=256,160,4
atlas=Image.new('RGBA',(W*3*S,H*S))
svg=[]
for index,(path,fill,stroke) in enumerate(PATHS):
    tokens=path.split(); points=[]; current=(0,0); i=0
    while i < len(tokens):
        op=tokens[i];i+=1
        if op in ('M','L'):
            current=(float(tokens[i]),float(tokens[i+1]));i+=2;points.append(current)
        elif op=='C':
            a,b,c=[(float(tokens[i+k]),float(tokens[i+k+1])) for k in (0,2,4)];i+=6
            start=current
            for step in range(1,49):
                t=step/48;u=1-t
                points.append(tuple(u*u*u*start[d]+3*u*u*t*a[d]+3*u*t*t*b[d]+t*t*t*c[d] for d in (0,1)))
            current=c
        elif op=='Z': points.append(points[0])
    draw=ImageDraw.Draw(atlas)
    scaled=[((x+index*W)*S,y*S) for x,y in points]
    if fill:draw.polygon(scaled,fill='white')
    else:
        draw.line(scaled,fill='white',width=stroke*S,joint='curve')
        for x,y in (scaled[0],scaled[-1]):
            r=stroke*S/2;draw.ellipse((x-r,y-r,x+r,y+r),fill='white')
    svg.append(f'<path transform="translate({index*W} 0)" d="{path}" fill="'+('white' if fill else 'none')+f'" stroke="'+('none' if fill else 'white')+f'" stroke-width="{stroke}" stroke-linecap="round"/>')
atlas.resize((W*3,H),Image.Resampling.LANCZOS).save(ROOT/'lobby-navigation-selection.png')
(ROOT/'lobby-navigation-selection.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg" width="768" height="160" viewBox="0 0 768 160">'+''.join(svg)+'</svg>')
print('Saved vector source and three-mask atlas')
