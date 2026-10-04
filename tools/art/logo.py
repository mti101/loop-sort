import sys; sys.path.insert(0, '.')
from common import *
import os
OUT = sys.argv[1]
FONT = os.path.abspath('../../assets/fonts/LilitaOne-Regular.ttf')

def text(body, size, loc, m, extrude=0.18, bevel=0.035, offset=0.0, rot=(math.radians(90), 0, 0)):
    c = bpy.data.curves.new('t', 'FONT'); c.body = body; c.size = size
    c.font = bpy.data.fonts.load(FONT)
    c.extrude = extrude; c.bevel_depth = bevel; c.bevel_resolution = 4; c.offset = offset
    c.align_x = 'CENTER'; c.align_y = 'CENTER'
    o = bpy.data.objects.new('t', c); bpy.context.collection.objects.link(o)
    o.location = loc; o.rotation_euler = rot
    o.data.materials.append(m)
    return o

sc = reset(); world((0.5, 0.6, 0.9), 0.6)
sc.eevee.use_raytracing = False
yellow = mat('y', hexc('#FFC21A'), rough=0.2, coat=0.8)
navy = mat('n', hexc('#1B2766'), rough=0.5, coat=0.0)
pink = mat('p', hexc('#F13FD0'), rough=0.2, coat=0.8)
orange = mat('o', hexc('#FF8A1F'), rough=0.2, coat=0.8)
# outline layers (behind, bigger)
text('LOOP', 1.9, (0, 0.12, 0.85), navy, extrude=0.3, offset=0.075, bevel=0.0)
text('LOOP', 1.9, (0, 0, 0.85), yellow, extrude=0.25, bevel=0.05)
text('SORT', 1.45, (0.08, 0.12, -0.75), navy, extrude=0.3, offset=0.07, bevel=0.0)
text('SORT', 1.45, (0.08, 0, -0.75), pink, extrude=0.25, bevel=0.05)
# cubes
for (x, z, col, s_) in [(-2.9, 0.95, '#3FD04A', 0.42), (2.9, 1.15, '#E8333F', 0.38), (2.45, -1.55, '#2F80FF', 0.3), (-2.4, -1.2, '#B65CFF', 0.3)]:
    rbox('c', (s_, s_, s_), s_*0.18, loc=(x, -0.2, z), m=mat('c', hexc(col), rough=0.2, coat=0.8), rot=(0.4, 0.5, 0.3))
light('AREA', (-3, -6, 5), 900, size=6, target=(0,0,0))
light('AREA', (5, -4, -2), 300, size=6, color=(0.7,0.8,1), target=(0,0,0))
camera((0, -9.5, 0.3), (0, 0, 0), ortho=7.6)
render(OUT, 1200, 760)
