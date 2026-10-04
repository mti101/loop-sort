import sys; sys.path.insert(0, '.')
from common import *
import os
OUT = sys.argv[1]; os.makedirs(OUT, exist_ok=True)
COLS = ['#FF4D6A', '#3E9BFF', '#2FD27A', '#FFC928', '#A66CFF', '#FF8A3D', '#FF7CC8', '#2E3A57']
NAMES = ['red','blue','green','yellow','violet','orange','pink','hidden']
for nm, hx in zip(NAMES, COLS):
    sc = reset(); world((0.75,0.8,1.0), 0.9)
    base = hexc(hx)
    body = mat('b', base, rough=0.28, coat=0.5)
    # slab: thick rounded tile + inner raised face
    rbox('slab', (1.0, 0.34, 1.0), 0.16, m=body, seg=8)
    face = hexc(hx)
    fm = mat('f', tuple(min(1, c*1.18+0.04) for c in face), rough=0.22, coat=0.7)
    rbox('face', (0.80, 0.06, 0.80), 0.06, loc=(0, -0.19, 0), m=fm, seg=6)
    light('AREA', (-2, -3, 3), 450, size=3, target=(0,0,0))
    light('AREA', (3, -2, -1.5), 120, size=3, color=(0.8,0.9,1), target=(0,0,0))
    camera((0, -4.2, 1.15), (0, 0, -0.02), ortho=1.55)
    render(f'{OUT}/tile_{nm}.png', 256, 256)
