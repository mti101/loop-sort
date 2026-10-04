import sys; sys.path.insert(0, '.')
from chars import *
from dog import puppy
OUT = sys.argv[1]

sc = reset(); sc.eevee.use_raytracing = False
world((0.62, 0.7, 0.95), 0.5)
blue = mat('mb', hexc('#3D63E0'), rough=0.3, coat=0.6)
blue2 = mat('mb2', hexc('#2B47B8'), rough=0.35, coat=0.4)
yel = mat('my', hexc('#FFC21A'), rough=0.22, coat=0.8)
steel = mat('st', hexc('#8EA0D6'), rough=0.3, metal=0.4, coat=0.3)
plat = mat('pl', hexc('#5666C9'), rough=0.5, coat=0.2)
plat2 = mat('pl2', hexc('#FFB45E'), rough=0.5, coat=0.2)

# platform (disc)
def cyl(name, r, h, loc, m, v=64):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=h, location=loc, vertices=v)
    o = bpy.context.object; o.name = name
    bv = o.modifiers.new('b', 'BEVEL'); bv.width = min(r, h) * 0.2; bv.segments = 5
    bpy.ops.object.shade_smooth(); o.data.materials.append(m); return o
cyl('floor', 5.4, 0.3, (0, -0.5, -4.5), plat2)
cyl('floor2', 4.9, 0.34, (0, -0.5, -4.43), plat)
ZM = -1.0

# machine: belly + dome
sphere('belly', 1.7, (0.1, 1.0, -1.5 + ZM), blue, scale=(1.05, 1.0, 0.95))
cyl('ringband', 1.75, 0.35, (0.1, 1.0, -0.85 + ZM), yel)
bpy.ops.mesh.primitive_torus_add(major_radius=1.45, minor_radius=0.2, location=(0.1, 1.0, 0.95 + ZM), major_segments=64, minor_segments=24)
t = bpy.context.object; bpy.ops.object.shade_smooth(); t.data.materials.append(yel)
# dome glass
glass = mat('gl', hexc('#BFE3FF'), rough=0.05, coat=1.0)
b = glass.node_tree.nodes['Principled BSDF']
b.inputs['Alpha'].default_value = 0.28
glass.surface_render_method = 'BLENDED' if hasattr(glass, 'surface_render_method') else None
dome = sphere('dome', 1.4, (0.1, 1.0, -0.2 + ZM), glass, scale=(1.0, 1.0, 1.1))
# bricks inside the dome
import random
rnd = random.Random(4)
cols = ['#E8333F', '#2F80FF', '#3FD04A', '#FFD21F', '#B65CFF', '#FF8B1F', '#FF5CB1']
for i in range(11):
    c = cols[i % 7]
    rbox('inb', (0.8, 0.5, 0.18), 0.05, loc=(0.1 + rnd.uniform(-0.8, 0.8), 1.0 + rnd.uniform(-0.6, 0.6), -0.95 + ZM + (i % 4) * 0.22 + rnd.uniform(0, 0.15)),
         m=mat('c%d' % i, hexc(c), rough=0.2, coat=0.8), rot=(rnd.uniform(-0.3, 0.3), rnd.uniform(-0.3, 0.3), rnd.uniform(0, 3)))
# indicator lights
for i, c in enumerate(['#FF8B1F', '#2F80FF', '#3FD04A', '#B65CFF', '#FFD21F', '#E8333F']):
    sphere('lamp', 0.1, (0.1 - 0.62 + i * 0.25, -0.62, -1.65 + ZM), mat('l', hexc(c), rough=0.2, coat=0.8, emit=hexc(c)), scale=(1, 0.6, 1))
# conveyor ramp in front
ramp = rbox('ramp', (1.5, 2.6, 0.22), 0.08, loc=(0.1, -1.15, -2.65 + ZM), m=blue2, rot=(math.radians(-14), 0, 0))
for sx in (-1, 1):
    rbox('rail', (0.2, 2.8, 0.45), 0.08, loc=(0.1 + sx*0.85, -1.15, -2.55 + ZM), m=yel, rot=(math.radians(-14), 0, 0))
for k in range(8):
    rbox('rib', (1.35, 0.07, 0.07), 0.02, loc=(0.1, -2.25 + k*0.31, -2.78 + ZM + k*0.075), m=blue, rot=(math.radians(-14), 0, 0))
# bricks stack on the ramp
for k, c in enumerate(['#3FD04A', '#2F80FF', '#FFD21F']):
    rbox('rb', (1.1, 0.7, 0.2), 0.06, loc=(0.1, -2.1 + k*0.0, -2.62 + ZM + 0.2*k), m=mat('r%d' % k, hexc(c), rough=0.2, coat=0.8), rot=(math.radians(-14), 0, 0.0))

# characters
M1 = Mats('#FF9A3C', '#7A3B1E', '#D9C8A6', '#B29A74', '#6B3A22')
head(M1, (-3.3, -1.6, -0.1), 'quiff', eye_shift=(2, 0))
body(M1, (-3.3, -1.55, -2.05))
# arms holding a stack of bricks
arm(M1, (-4.25, -1.6, -1.55), (-3.55, -2.7, -1.75))
arm(M1, (-2.35, -1.6, -1.55), (-3.0, -2.7, -1.75))
for k, c in enumerate(['#FF5CB1', '#FFD21F', '#2F80FF', '#3FD04A', '#FF5CB1', '#B65CFF', '#2F80FF']):
    rbox('hs', (1.25, 0.9, 0.2), 0.06, loc=(-3.28, -2.75, -2.05 + k*0.22 - 0.1), m=mat('h%d' % k, hexc(c), rough=0.2, coat=0.8), rot=(0, 0, math.radians((k%3-1)*4)))
# puppy at right
puppy((3.3, -1.8, -3.5), scale=0.8, look=1.0)

light('AREA', (-5, -8, 5), 2200, size=8, target=(0, 0, -1))
light('AREA', (8, -4, 2), 800, size=8, color=(0.8, 0.88, 1), target=(0, 0, -1))
light('AREA', (0, 6, 4), 700, size=8, color=(1, 0.92, 0.82), target=(0, 0, -1))
camera((0, -22, 7), (0, 0, -2.6), lens=62)
render(OUT, 1000, 900)
